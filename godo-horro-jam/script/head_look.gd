extends Node3D
class_name HeadLook

@export var max_yaw_deg := 40.0           # лимит поворота головы влево/вправо
@export var max_pitch_up_deg := 15.0      # вверх голова почти не поднимается
@export var max_pitch_down_deg := 30.0    # вниз можно посмотреть на терминал
@export var sensitivity := 0.0018
@export var smoothing := 12.0             # «тяжёлая» голова, больше = резче

var _target_yaw := 0.0
var _target_pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= event.relative.x * sensitivity
		_target_pitch -= event.relative.y * sensitivity
		# Жёсткое ограничение: гг парализован и не может крутить головой
		_target_yaw = clamp(_target_yaw, -deg_to_rad(max_yaw_deg), deg_to_rad(max_yaw_deg))
		_target_pitch = clamp(_target_pitch, -deg_to_rad(max_pitch_down_deg), deg_to_rad(max_pitch_up_deg))

	if event.is_action_pressed("ui_cancel"):  # Esc отпускает мышь
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var w := 1.0 - exp(-smoothing * delta)
	rotation.y = lerp(rotation.y, _target_yaw, w)
	rotation.x = lerp(rotation.x, _target_pitch, w)
