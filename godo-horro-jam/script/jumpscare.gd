extends SubViewportContainer

signal finished

@export var animation_name := ""      # анимация скримера (пусто = первая найденная)
@export var min_duration := 1.5       # минимальная длительность скримера, сек
@export var duration := 0.0           # фиксированная длительность (0 = по длине анимации)
@export var sound: AudioStreamPlayer  # крик (если пусто, ищется внутри сцены)
@export var play_on_ready := false    # для проверки сцены по F6

@export_group("Положение монстра перед камерой")
@export var auto_place := true        # ставить монстра перед камерой автоматически
@export var distance := 1.5           # расстояние от камеры, м
@export var vertical_offset := -2.3   # смещение по высоте (минус = ниже камеры)
@export var yaw_offset_deg := 83.0     # доворот модели вокруг Y (у этой модели лицо смотрит по +X)

var _playing := false
var _viewport: SubViewport
var _camera: Camera3D
var _model: Node3D

func _ready() -> void:
	# Растягиваем на весь экран
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = find_child("SubViewport", true, false) as SubViewport
	if _viewport == null:
		push_warning("Jumpscare: внутри нет узла SubViewport")
		return

	# Свой 3D-мир: без этого модель оказывается внутри самого уровня, а не поверх экрана
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true

	_camera = _viewport.find_child("Camera3D", true, false) as Camera3D
	if _camera:
		_camera.current = true

	# Модель: первый 3D-узел во вьюпорте, кроме камеры и света
	for child in _viewport.get_children():
		if child is Node3D and not (child is Camera3D) and not (child is Light3D):
			_model = child as Node3D
			break

	# Звук ищем сами, если поле Sound не заполнено
	if sound == null:
		var players := find_children("*", "AudioStreamPlayer", true, false)
		if players.size() > 0:
			sound = players[0] as AudioStreamPlayer

	visible = play_on_ready
	if play_on_ready:
		play()

func play() -> void:
	if _playing:
		return
	_playing = true
	_place_model()
	visible = true

	var length := min_duration
	var anim := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		var chosen := animation_name
		if chosen == "" or not anim.has_animation(chosen):
			chosen = ""
			for candidate in anim.get_animation_list():
				if candidate != "RESET":
					chosen = candidate
					break
		if chosen != "":
			anim.play(chosen)
			length = maxf(anim.get_animation(chosen).length, min_duration)

	if sound:
		sound.play()
	if duration > 0.0:
		length = duration

	await get_tree().create_timer(length).timeout
	finished.emit()

# Ставит монстра прямо перед камерой, лицом к ней
func _place_model() -> void:
	if not auto_place or _model == null or _camera == null:
		return
	var forward := -_camera.global_transform.basis.z
	_model.global_position = _camera.global_position + forward * distance + Vector3(0.0, vertical_offset, 0.0)
	# Поворачиваем лицом к камере (по горизонтали)
	var target := Vector3(_camera.global_position.x, _model.global_position.y, _camera.global_position.z)
	if not target.is_equal_approx(_model.global_position):
		_model.look_at(target, Vector3.UP)
	_model.rotate_y(deg_to_rad(yaw_offset_deg))
