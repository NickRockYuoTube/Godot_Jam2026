extends CharacterBody3D
class_name RoamingMonster

enum State { ROAM, HUNT, STRIKE, RETREAT, FALLBACK }

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

@export var root_motion_bone := ""   # кость, которая «уводит» модель (пусто = самая первая кость скелета)

@export_group("Движение")
@export var speed := 1.3                     # м/с в обычном режиме (коляска едет 1.6)
@export var idle_time := 3.0                 # пауза в точке, сек
@export var chase_speed := 2.0               # скорость, когда идёт на игрока
@export var retreat_speed := 2.5             # скорость отступления
@export var retreat_by_teleport := false     # true = после удара исчезает и появляется на дальней точке
@export var turn_speed_deg := 270.0          # скорость поворота, градусов в секунду
@export var min_move_factor := 0.3           # во сколько раз замедляется, пока не повернулся лицом к цели

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
@export var hunt_timeout := 15.0             # если не дошёл за это время, отходит и пробует снова
@export var retry_delay_min := 2.0           # через сколько секунд после отхода пробует снова
@export var retry_delay_max := 4.0
@export var max_hunt_retries := 3            # сколько раз подряд пробует, прежде чем бросить погоню
@export var damage := 1

@export_group("Слух")
@export var door_hear_range := 25.0          # на каком расстоянии монстр слышит, как игрок открыл дверь
@export var door_spot_max_distance := 12.0   # точка патруля должна быть не дальше этого от двери
@export var door_alert_cooldown := 8.0       # пауза между реакциями на двери, сек
@export var alert_starts_hunt := true        # дойдя до двери, сразу идёт за игроком, если тот рядом
@export var alert_hunt_distance := 10.0      # «рядом» = ближе этого расстояния до игрока


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
var _stuck_time := 0.0
var _stuck_count := 0
var _hunt_fails := 0       # сколько раз подряд не смог добраться до игрока
var _retry_left := 0.0
var _waiting_retry := false
var _player_ignored := false
var _investigating := false        # идёт проверять дверь, которую открыл игрок
var _last_alert_time := -100.0
var _doors_connected := false


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
	_lock_root_motion()

	# Физическое тело монстра
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # без гравитации: ходит по высоте навигации
	collision_layer = 1 << 4    # слой 5: собственный слой монстра, луч света и коляска его не «видят»
	collision_mask = 1          # упирается в стены и всё остальное на слое 1

	# Собственные физические тела монстра: луч света их игнорирует, и сам монстр о них не спотыкается
	for body in find_children("*", "CollisionObject3D", true, false):
		_own_rids.append((body as CollisionObject3D).get_rid())
		if body is PhysicsBody3D:
			add_collision_exception_with(body as PhysicsBody3D)
	_own_rids.append(get_rid())   # луч света не должен упираться в собственную капсулу

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
		State.FALLBACK:
			_process_fallback(delta)

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
		_stuck_count = 0
		# Дошёл до точки у двери, которую открыл игрок
		if _investigating:
			_investigating = false
			var player := _get_player()
			if alert_starts_hunt and attack_enabled and player and not PlayerHealth.is_dead \
					and _flat_distance_to(player) <= alert_hunt_distance:
				_start_hunt()
				return
		_idle_left = idle_time
		_set_walking(false)
		return
	_move_along_path(speed, delta)

func _start_hunt() -> void:
	_set_state(State.HUNT)
	_repath_timer = 0.0

func _process_hunt(delta: float) -> void:
	var player := _get_player()
	if player == null or PlayerHealth.is_dead:
		_start_retreat()
		return
	if _state_time > hunt_timeout:
		_start_fallback()   # слишком долго не может добраться
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
		_start_fallback()
		return
	_move_along_path(chase_speed, delta)

# Не может добраться до игрока: отходит к ближайшей точке и пробует снова
func _start_fallback() -> void:
	_hunt_fails += 1
	if _hunt_fails > max_hunt_retries:
		_enter_roam()   # хватит, возвращается к обычному блужданию
		return
	_set_state(State.FALLBACK)
	_waiting_retry = false
	agent.target_position = _nearest_spot().global_position

func _process_fallback(delta: float) -> void:
	if _waiting_retry:
		_retry_left -= delta
		if _retry_left <= 0.0:
			_start_hunt()   # пробует снова добраться до игрока
		return

	if agent.is_navigation_finished() and _state_time > 0.5:
		_waiting_retry = true
		_retry_left = randf_range(retry_delay_min, retry_delay_max)
		_set_walking(false)
		return
	_move_along_path(speed, delta)

func _start_strike() -> void:
	_hunt_fails = 0   # добрался до игрока
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
	_hunt_fails = 0
	_set_state(State.ROAM)
	_idle_left = idle_time
	_attack_timer = randf_range(attack_interval_min, attack_interval_max)
	_set_walking(false)

func _set_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	_investigating = false

# ---------------- Появление и исчезновение ----------------

func _spawn(spot: Marker3D) -> void:
	_connect_doors()
	_ignore_player()
	global_position = spot.global_position
	velocity = Vector3.ZERO
	visible = true
	_enabled = true
	_active = true
	_lit_timer = 0.0
	_idle_left = 0.0
	_step_distance = 0.0
	_stuck_count = 0
	_hunt_fails = 0
	_set_state(State.ROAM)
	_attack_timer = randf_range(attack_interval_min, attack_interval_max)
	if _sensor:
		_sensor.set_deferred("monitorable", true)
	_set_walking(false)
	_pick_next_target()

func _vanish(with_sound: bool = true) -> void:
	_active = false
	visible = false
	_set_walking(false)
	if _sensor:
		_sensor.set_deferred("monitorable", false)   # скрытый монстр не открывает двери
	if with_sound and vanish_sound:
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
		velocity = Vector3.ZERO
		return
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	var flat_dir := Vector3(to_next.x, 0.0, to_next.z)

	# Куда смотреть: туда, куда реально движемся (в том числе вдоль стены),
	# а если почти стоим, то на цель
	var real := get_real_velocity()
	var look_dir := Vector3(real.x, 0.0, real.z)
	if look_dir.length() < 0.3:
		look_dir = flat_dir
	_face(look_dir, delta)

	# Не бежим боком: чем сильнее монстр отвёрнут от цели, тем медленнее идёт, пока не повернётся
	var alignment := 1.0
	if flat_dir.length() > 0.01:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		alignment = forward.normalized().dot(flat_dir.normalized())
	var factor := lerpf(min_move_factor, 1.0, smoothstep(0.2, 0.9, alignment))

	# На последнем отрезке замедляемся, чтобы не перелететь точку
	velocity = to_next.normalized() * minf(spd * factor, to_next.length() / maxf(delta, 0.001))
	var commanded := velocity.length()
	move_and_slide()
	_set_walking(true)
	_update_steps(get_real_velocity().length() * delta, spd)
	_check_stuck(commanded, delta)

# Если монстр упёрся и почти не движется дольше 1.5 с, это застревание
func _check_stuck(commanded: float, delta: float) -> void:
	if get_real_velocity().length() < commanded * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.5:
		_stuck_time = 0.0
		_on_stuck()

func _on_stuck() -> void:
	_stuck_count += 1
	if _stuck_count >= 3:
		# Застрял по-настоящему: тихо исчезает и появляется в другом месте, без звука
		_stuck_count = 0
		_vanish(false)
		return
	match _state:
		State.HUNT:
			_start_fallback()   # не добраться до игрока: отходит и пробует снова
		State.ROAM:
			_pick_next_target()   # выбираем другую цель
		_:
			_enter_roam()

# Коляску монстр обходит физически, чтобы не было толкотни в момент удара
func _ignore_player() -> void:
	if _player_ignored:
		return
	var player := _get_player() as PhysicsBody3D
	if player:
		add_collision_exception_with(player)
		_player_ignored = true

# Плавно поворачивает монстра лицом в сторону dir (по горизонтали) с постоянной скоростью
func _face(dir: Vector3, delta: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	var target_y := atan2(-flat.x, -flat.z)   # модель смотрит в -Z
	var diff := angle_difference(rotation.y, target_y)
	var step := deg_to_rad(turn_speed_deg) * delta
	rotation.y += clampf(diff, -step, step)

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

# Ближайшая к монстру точка (не ближе 1.5 м, чтобы действительно отойти).
# Сначала ищем среди тех, что не ближе к игроку, чем он сам; если таких нет, любую
func _nearest_spot() -> Marker3D:
	var player := _get_player()
	var my_dist := INF
	if player:
		my_dist = _flat_distance_to(player)

	var best: Marker3D = null
	var best_d := INF
	for away_only in [true, false]:
		for spot in _spots:
			var d := spot.global_position.distance_to(global_position)
			if d < 1.5 or d >= best_d:
				continue
			if away_only and player:
				var offset := spot.global_position - player.global_position
				if Vector2(offset.x, offset.z).length() < my_dist:
					continue
			best = spot
			best_d = d
		if best != null:
			break
	return best if best != null else _spots.pick_random()


# Подписываемся на сигнал всех дверей уровня
func _connect_doors() -> void:
	if _doors_connected:
		return
	_doors_connected = true
	for node in get_tree().get_nodes_in_group("doors"):
		var door := node as Door
		if door and not door.opened_by_player.is_connected(_on_door_opened_by_player):
			door.opened_by_player.connect(_on_door_opened_by_player)

# Игрок открыл дверь: монстр меняет цель патруля на ближайшую к ней точку
func _on_door_opened_by_player(door: Door) -> void:
	if not _active or _state != State.ROAM or PlayerHealth.is_dead:
		return   # занят: уже идёт за игроком, отступает или скрыт
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_alert_time < door_alert_cooldown:
		return
	if global_position.distance_to(door.global_position) > door_hear_range:
		return   # слишком далеко, не слышит

	var spot := _spot_near(door.global_position)
	if spot == null or spot.global_position.distance_to(door.global_position) > door_spot_max_distance:
		return   # у этой двери нет подходящей точки патруля

	print("Монстр услышал дверь: ", door.name)   # для проверки, потом можно удалить
	_last_alert_time = now
	_investigating = true
	_idle_left = 0.0
	agent.target_position = spot.global_position

# Ближайшая к позиции точка патруля
func _spot_near(pos: Vector3) -> Marker3D:
	var best: Marker3D = null
	var best_d := INF
	for spot in _spots:
		var d := spot.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = spot
	return best


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

	# Jolt не поддерживает неравномерный масштаб у сфер, поэтому гасим масштаб родителя
	# (до add_child, иначе форма уже построится с кривым масштабом)
	var parent_scale := global_transform.basis.get_scale()
	if absf(parent_scale.x) > 0.0001 and absf(parent_scale.y) > 0.0001 and absf(parent_scale.z) > 0.0001:
		_sensor.scale = Vector3.ONE / parent_scale

	add_child(_sensor)

# Делает анимации «на месте»: корневая кость больше не двигает модель
func _lock_root_motion() -> void:
	if anim_player == null:
		return
	var root := anim_player.get_node_or_null(anim_player.root_node)
	if root == null:
		return
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() == 0:
		return
	var bone_name := root_motion_bone if root_motion_bone != "" else skeleton.get_bone_name(0)
	anim_player.root_motion_track = NodePath("%s:%s" % [root.get_path_to(skeleton), bone_name])
