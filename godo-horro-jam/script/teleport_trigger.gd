extends Area3D
class_name TeleportTrigger

@export var destination: Marker3D          # куда телепортировать игрока
@export var look_target: Marker3D          # ← НОВОЕ: куда принудительно смотрит камера (надписи на стене)
@export var look_turn_time := 1.0          # ← НОВОЕ: за сколько секунд камера поворачивается к цели
@export var lock_look := true              # ← НОВОЕ: на время эффекта игрок не может вертеть камерой
@export var sound: Node                    # AudioStreamPlayer (или 3D): гул на время тряски
@export var shake_time := 5.0              # сколько секунд трясётся камера
@export var shake_strength := 0.04         # сила тряски в конце (радианы, 0.04 ≈ 2.3°)
@export var fade_out_time := 1.0           # затемнение в конце тряски, сек (0 = резкий обрыв)
@export var fade_in_time := 1.5            # проявление после телепорта, сек
@export var lock_controls := true          # блокировать управление на время эффекта
@export var one_shot := true

var _used := false
var _running := false
var _camera: Camera3D
var _cam_base_rot := Vector3.ZERO
var _look_rot := Vector3.ZERO              # ← НОВОЕ: поворот камеры, при котором она смотрит на цель
var _has_look := false                     # ← НОВОЕ
var _fade_layer: CanvasLayer
var _fade: ColorRect

func _ready() -> void:
	collision_layer = 0   # триггер сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if destination == null:
		push_warning("TeleportTrigger '%s': не назначена точка назначения" % name)

func _on_body_entered(body: Node3D) -> void:
	var chair := body as Wheelchair
	if chair == null or destination == null or _running:
		return
	if one_shot and _used:
		return
	_used = true
	_run(chair)

func _run(chair: Wheelchair) -> void:
	_running = true
	if lock_controls:
		chair.set_controls_locked(true)

	_camera = get_viewport().get_camera_3d()
	if _camera:
		_cam_base_rot = _camera.rotation
		_prepare_look(chair)   # ← НОВОЕ
	_create_fade_overlay()

	# Гул стартует вместе с тряской
	var p = sound
	if p and is_instance_valid(p):
		p.play()

	# Тряска: сила растёт к концу, в последние fade_out_time секунд экран гаснет
	var duration := maxf(shake_time, 0.01)
	var tween := create_tween()
	tween.tween_method(_shake_step, 0.0, duration, duration)
	await tween.finished

	# Хлоп: звук обрывается, игрок в другом месте
	if p and is_instance_valid(p):
		p.stop()
	chair.global_position = destination.global_position
	chair.global_rotation = Vector3(0.0, destination.global_rotation.y, 0.0)
	chair.velocity = Vector3.ZERO
	_restore_camera()
	if lock_look:
		_set_look_enabled(chair, true)   # ← НОВОЕ: возвращаем игроку управление камерой

	# Проявление
	var fade_tween := create_tween()
	fade_tween.tween_property(_fade, "color:a", 0.0, fade_in_time)
	await fade_tween.finished

	_fade_layer.queue_free()
	if lock_controls:
		chair.set_controls_locked(false)
	_running = false

# ← НОВОЕ: готовим поворот камеры к цели и отключаем управление взглядом
func _prepare_look(chair: Wheelchair) -> void:
	_has_look = false
	if look_target != null:
		# Считаем, как должна повернуться камера, чтобы смотреть на цель
		_camera.look_at(look_target.global_position, Vector3.UP)
		_look_rot = _camera.rotation
		_camera.rotation = _cam_base_rot
		_has_look = true
	if lock_look:
		_set_look_enabled(chair, false)

# ← НОВОЕ: поворот камеры по времени: от исходного к направлению на цель
func _base_rotation(t: float) -> Vector3:
	if not _has_look:
		return _cam_base_rot
	var k := smoothstep(0.0, 1.0, clampf(t / maxf(look_turn_time, 0.01), 0.0, 1.0))
	var q := Quaternion.from_euler(_cam_base_rot).slerp(Quaternion.from_euler(_look_rot), k)
	return q.get_euler()

# ← НОВОЕ: включает и выключает мышь-голову и лучи взаимодействия на время эффекта
func _set_look_enabled(chair: Node, enabled: bool) -> void:
	var head := _find_head_look(chair)
	if head:
		head.set_process(enabled)
		head.set_process_unhandled_input(enabled)
	# Лучи на камере выключаем, чтобы взгляд не включил фонарь, пока камера разворачивается
	if _camera and is_instance_valid(_camera):
		for child in _camera.get_children():
			if child is RayCast3D:
				(child as RayCast3D).enabled = enabled

func _find_head_look(node: Node) -> Node:
	for child in node.get_children():
		if child is HeadLook:
			return child
		var found := _find_head_look(child)
		if found:
			return found
	return null

# t = сколько секунд прошло с начала тряски
func _shake_step(t: float) -> void:
	var progress := t / maxf(shake_time, 0.01)
	var s := shake_strength * progress * progress   # тряска нарастает к концу

	if _camera:
		var base := _base_rotation(t)   # ← НОВОЕ: тряска накладывается на поворот к цели
		var time := Time.get_ticks_msec() / 1000.0
		_camera.rotation = base + Vector3(
			sin(time * 37.0) * s,
			sin(time * 43.0 + 1.0) * s,
			sin(time * 29.0 + 2.0) * s * 1.5)
		_camera.h_offset = sin(time * 51.0) * s * 2.0
		_camera.v_offset = sin(time * 47.0 + 0.5) * s * 2.0

	# Затемнение в последние fade_out_time секунд
	var fade_start := shake_time - fade_out_time
	var alpha := clampf((t - fade_start) / maxf(fade_out_time, 0.001), 0.0, 1.0)
	_fade.color = Color(0.0, 0.0, 0.0, alpha)

func _restore_camera() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.rotation = _cam_base_rot
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0

func _create_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 90          # поверх интерфейса
	add_child(_fade_layer)

	_fade = ColorRect.new()
	_fade_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
