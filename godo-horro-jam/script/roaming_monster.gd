extends Node3D
class_name RoamingMonster

enum State { ROAM, HUNT, STRIKE, RETREAT }

@export var spots_root: Node3D               # узел с Marker3D-точками (MonsterSpots)
@export var agent: NavigationAgent3D
@export var vanish_sound: AudioStreamPlayer3D
@export var attack_sound: AudioStreamPlayer3D
@export var step_sound: AudioStreamPlayer3D
@export var anim_player: AnimationPlayer
@export var idle_animation := ""             # когда стоит (необязательно)
@export var walk_animation := ""             # когда идёт
@export var attack_animation := ""           # когда бьёт
@export var start_dormant := true            # true = спит, пока его не включит MonsterTrigger

@export_group("Движение")
@export var speed := 1.3                     # м/с в обычном режиме (коляска едет 1.6)
@export var idle_time := 3.0                 # пауза в точке, сек
@export var chase_speed := 2.0               # скорость, когда идёт на игрока
@export var retreat_speed := 2.5             # скорость отступления
@export var retreat_by_teleport := false     # true = после удара исчезает и появляется на дальней точке

@export_group("Шаги")
@export var step_is_loop := false            # true = звук это зацикленная дорожка шагов; false = один шаг
@export var step_length := 0.9               # метров между шагами (для одиночного шага)
@export var step_pitch_random := 0.08        # разброс высоты тона, чтобы шаги не были одинаковыми

@export_group("Свет")
@export var lit_time := 0.5                  # сколько секунд держать луч, чтобы исчез
@export var respawn_delay := 4.0             # через сколько секунд появится снова
@export var far_spots_pool := 3              # респавн в одной из N самых дальних точек
@export var body_center_height := 1.0        # высота центра тела (по ней проверяется свет)
@export var debug_light := false             # включи на время проверки

@export_group("Атака")
@export var attack_enabled := true
@export var attack_interval_min := 25.0      # через сколько секунд после появления идёт на игрока
@export var attack_interval_max := 45.0
@export var strike_distance := 1.4           # с какого расстояния начинает удар
@export var hit_distance := 1.9              # игрок получает урон, если в момент удара ближе этого
@export var strike_windup := 0.45            # замах перед ударом, сек
@export var strike_recover := 0.6            # пауза после удара, сек
@export var hunt_timeout := 15.0             # если не дошёл за это время, бросает погоню
@export var damage := 1

var _state: State = State.ROAM
var _spots: Array[Marker3D] = []
var _own_rids: Array[RID] = []
var _flashlight: SpotLight3D
var _player: Node3D
var _sensor: Area3D
var _enabled := false      # монстр включён (триггером или сразу)
var _active := false       # монстр сейчас на уровне (не в паузе после исчезновения)
var _lit_timer := 0.0
var _idle_left := 0.0
var _attack_timer := 0.0
var _state_time := 0.0
var _repath_timer := 0.0
var _step_distance := 0.0
var _did_hit := false
var _debug_t := 0.0

func _ready() -> void:
	# Автопоиск, если поля не заполнены в Inspector
	if spots_root == null:
		spots_root = get_tree().root.find_child("MonsterSpots", true, false) as Node3D
	if agent == null:
		agent = find_child("NavigationAgent3D", true, false) as NavigationAgent3D
	if vanish_sound == null:
		vanish_sound = find_child("VanishSound", true, false) as AudioStreamPlayer3D
	if attack_sound == null:
		attack_sound = find_child("AttackSound", true, false) as AudioStreamPlayer3D
	if step_sound == null:
		step_sound = find_child("StepSound", true, false) as AudioStreamPlayer3D
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	if spots_root == null or agent == null:
		push_warning("RoamingMonster: нужны узел MonsterSpots и NavigationAgent3D")
		visible = false
		return

	for child in spots_root.get_children():
		if child is Marker3D:
			_spots.append(child as Marker3D)
	if _spots.size() < 2:
		push_warning("RoamingMonster: нужно минимум 2 точки Marker3D в MonsterSpots")
		visible = false
		return

	# Зацикливаем стоячую и ходячую анимации
	for anim_name in [idle_animation, walk_animation]:
		if anim_player and anim_name != "" and anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	# Собственные физические тела монстра, их луч света должен игнорировать
	for body in find_children("*", "CollisionObject3D", true, false):
		_own_rids.append((body as CollisionObject3D).get_rid())

	_create_door_sensor()
	add_to_group("roaming_monsters")

	if start_dormant:
		visible = false   # спит до триггера
		return

	await get_tree().physics_frame   # ждём, пока навигация синхронизируется
	_spawn(_far_spot())

# Включает монстра (вызывает MonsterTrigger). spot = где появиться, пусто = самая дальняя точка
func activate(spot: Marker3D = null) -> void:
	if _spots.size() < 2 or _active:
		return
	_spawn(spot if spot != null else _far_spot())

# Выключает монстра (прячет и останавливает)
func deactivate() -> void:
	_enabled = false
	_active = false
	visible = false
	_set_walking(false)
	if _sensor:
		_sensor.set_deferred("monitorable", false)

func _physics_process(delta: float) -> void:
	if not _active:
		return

	# --- Свет фонаря: прерывает любое состояние ---
	if _is_lit():
		_lit_timer += delta
		if _lit_timer >= lit_time:
			_vanish()
			return
	else:
		_lit_timer = 0.0

	_state_time += delta
	match _state:
		State.ROAM:
			_process_roam(delta)
		State.HUNT:
			_process_hunt(delta)
		State.STRIKE:
			_process_strike(delta)
		State.RETREAT:
			_process_retreat(delta)

# ---------------- Состояния ----------------

func _process_roam(delta: float) -> void:
	# Пора идти за игроком?
	if attack_enabled and not PlayerHealth.is_dead:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_start_hunt()
			return

	if _idle_left > 0.0:
		_idle_left -= delta
		if _idle_left <= 0.0:
			_pick_next_target()
		return

	if agent.is_navigation_finished():
		_idle_left = idle_time
		_set_walking(false)
		return
	_move_along_path(speed, delta)

func _start_hunt() -> void:
	_set_state(State.HUNT)
	_repath_timer = 0.0

func _process_hunt(delta: float) -> void:
	var player := _get_player()
	if player == null or PlayerHealth.is_dead or _state_time > hunt_timeout:
		_start_retreat()
		return

	if _flat_distance_to(player) <= strike_distance:
		_start_strike()
		return

	# Обновляем цель раз в 0.3 с, потому что игрок едет
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.3
		var map := get_world_3d().navigation_map
		agent.target_position = NavigationServer3D.map_get_closest_point(map, player.global_position)

	# Дошёл до ближайшей точки сетки, а игрока не достать (он вне навигации)
	if agent.is_navigation_finished() and _state_time > 1.0:
		_start_retreat()
		return
	_move_along_path(chase_speed, delta)

func _start_strike() -> void:
	_set_state(State.STRIKE)
	_did_hit = false
	_set_walking(false)
	if attack_sound:
		attack_sound.play()
	if anim_player and attack_animation != "" and anim_player.has_animation(attack_animation):
		anim_player.play(attack_animation)

func _process_strike(delta: float) -> void:
	var player := _get_player()
	if player:
		var to_player := player.global_position - global_position
		_face(Vector3(to_player.x, 0.0, to_player.z), delta)   # поворачиваемся к игроку

	# Сам удар после замаха
	if not _did_hit and _state_time >= strike_windup:
		_did_hit = true
		if player and _flat_distance_to(player) <= hit_distance:
			PlayerHealth.take_damage(damage)

	if _state_time >= strike_windup + strike_recover:
		_start_retreat()

func _start_retreat() -> void:
	if retreat_by_teleport:
		_vanish()   # исчезает и появляется на дальней точке
		return
	_set_state(State.RETREAT)
	agent.target_position = _far_spot().global_position

func _process_retreat(delta: float) -> void:
	if agent.is_navigation_finished() and _state_time > 0.5:
		_enter_roam()
		return
	_move_along_path(retreat_speed, delta)

func _enter_roam() -> void:
	_set_state(State.ROAM)
	_idle_left = idle_time
	_attack_timer = randf_range(attack_interval_min, attack_interval_max)
	_set_walking(false)

func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0

# ---------------- Появление и исчезновение ----------------

func _spawn(spot: Marker3D) -> void:
	global_position = spot.global_position
	visible = true
	_enabled = true
	_active = true
	_lit_timer = 0.0
	_idle_left = 0.0
	_step_distance = 0.0
	_set_state(State.ROAM)
	_attack_timer = randf_range(attack_interval_min, attack_interval_max)
	if _sensor:
		_sensor.set_deferred("monitorable", true)
	_set_walking(false)
	_pick_next_target()

func _vanish() -> void:
	_active = false
	visible = false
	_set_walking(false)
	if _sensor:
		_sensor.set_deferred("monitorable", false)   # скрытый монстр не открывает двери
	if vanish_sound:
		vanish_sound.play()
	await get_tree().create_timer(respawn_delay).timeout
	if not _enabled or _active:
		return   # его за это время выключили или уже включили заново
	_spawn(_far_spot())

# ---------------- Движение ----------------

func _pick_next_target() -> void:
	var candidates: Array[Marker3D] = []
	for spot in _spots:
		if spot.global_position.distance_to(global_position) > 2.0:
			candidates.append(spot)
	if candidates.is_empty():
		_idle_left = idle_time
		return
	var target: Marker3D = candidates.pick_random()
	agent.target_position = target.global_position

func _move_along_path(spd: float, delta: float) -> void:
	if agent.is_navigation_finished():
		return
	var before := global_position
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	global_position = global_position.move_toward(next, spd * delta)
	_face(Vector3(to_next.x, 0.0, to_next.z), delta)
	_set_walking(true)
	_update_steps(before.distance_to(global_position), spd)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.05:
		# Модель смотрит в -Z
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)

func _flat_distance_to(node: Node3D) -> float:
	var d := node.global_position - global_position
	return Vector2(d.x, d.z).length()

# Одна из самых дальних от игрока точек
func _far_spot() -> Marker3D:
	var player := _get_player()
	if player == null:
		return _spots.pick_random()
	var pos := player.global_position
	var sorted: Array = _spots.duplicate()
	sorted.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return a.global_position.distance_squared_to(pos) > b.global_position.distance_squared_to(pos)
	)
	var pool := mini(far_spots_pool, sorted.size())
	return sorted[randi() % pool]

# ---------------- Шаги ----------------

func _update_steps(moved: float, spd: float) -> void:
	if step_sound == null:
		return
	if step_is_loop:
		# Зацикленная дорожка: темп зависит от скорости (в погоне шаги чаще)
		step_sound.pitch_scale = clampf(spd / speed, 0.8, 1.8)
		if not step_sound.playing:
			step_sound.play()
		return
	# Одиночный шаг: играем каждые step_length метров, темп сам зависит от скорости
	_step_distance += moved
	if _step_distance >= step_length:
		_step_distance = 0.0
		step_sound.pitch_scale = 1.0 + randf_range(-step_pitch_random, step_pitch_random)
		step_sound.play()

# ---------------- Свет ----------------

func _dbg(msg: String) -> void:
	if not debug_light:
		return
	_debug_t -= get_physics_process_delta_time()
	if _debug_t <= 0.0:
		_debug_t = 1.0
		print("Свет: ", msg)

# Монстр в конусе света фонаря и между ними нет стены
func _is_lit() -> bool:
	if not PowerSystem.flashlight_on:
		_dbg("фонарь выключен")
		return false
	if _flashlight == null or not is_instance_valid(_flashlight):
		_flashlight = get_tree().get_first_node_in_group("flashlight_spot") as SpotLight3D
		if _flashlight == null:
			_dbg("НЕ НАЙДЕН SpotLight3D в группе flashlight_spot")
			return false

	var origin := _flashlight.global_position
	var target := global_position + Vector3.UP * body_center_height   # центр тела, не ноги
	var to_target := target - origin

	if to_target.length() > _flashlight.spot_range:
		_dbg("слишком далеко: %.1f м, дальность фонаря %.1f" % [to_target.length(), _flashlight.spot_range])
		return false
	var forward := -_flashlight.global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_target))
	if angle > _flashlight.spot_angle:
		_dbg("вне конуса: угол %.0f°, конус %.0f°" % [angle, _flashlight.spot_angle])
		return false

	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	var excluded: Array[RID] = []
	excluded.append_array(_own_rids)
	var p := _get_player() as CollisionObject3D
	if p:
		excluded.append(p.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_dbg("препятствие: " + str(hit["collider"]))
		return false
	_dbg("МОНСТР В СВЕТЕ")
	return true

# ---------------- Прочее ----------------

func _get_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player

func _set_walking(walking: bool) -> void:
	if step_sound and step_is_loop and not walking:
		step_sound.stop()
	if anim_player == null:
		return
	var wanted := walk_animation if walking else idle_animation
	if wanted == "" or not anim_player.has_animation(wanted):
		if not walking and anim_player.is_playing():
			anim_player.pause()   # нет idle-анимации: замираем в текущей позе
		return
	if anim_player.current_animation != wanted or not anim_player.is_playing():
		anim_player.play(wanted)

# Датчик монстра: по нему DoorTrigger понимает, что рядом монстр
func _create_door_sensor() -> void:
	_sensor = Area3D.new()
	_sensor.name = "DoorSensor"
	_sensor.collision_layer = 1 << 3   # слой 4
	_sensor.collision_mask = 0
	_sensor.monitoring = false
	_sensor.monitorable = false        # включается, когда монстр появляется
	_sensor.add_to_group("monster_sensor")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position = Vector3(0, 1.0, 0)   # на уровне тела, а не ног
	_sensor.add_child(shape)
	add_child(_sensor)
