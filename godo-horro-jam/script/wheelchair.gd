extends CharacterBody3D
class_name Wheelchair

signal movement_changed(is_moving: bool)  # пригодится для динамо и звуков

@export var forward_speed := 1.6          # м/с вперёд
@export var back_speed := 0.8             # назад кресло едет медленнее
@export var turn_speed_deg := 25.0        # градусов/сек
@export var acceleration := 5.0           # плавность разгона
@export var terminal_path: NodePath = ^"Terminal"

var _cmd_forward := 0.0
var _cmd_turn := 0.0
var _current_turn := 0.0
var _was_moving := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	var terminal := get_node(terminal_path) as Terminal
	terminal.command_changed.connect(_on_command_changed)

func _on_command_changed(forward: float, turn: float) -> void:
	_cmd_forward = forward
	_cmd_turn = turn

func _physics_process(delta: float) -> void:
	# --- Поворот вокруг своей оси (кресло едет «на месте») ---
	_current_turn = lerp(_current_turn, _cmd_turn, acceleration * delta)
	rotate_y(deg_to_rad(turn_speed_deg) * _current_turn * delta)

	# --- Движение вперёд/назад вдоль взгляда кресла ---
	var speed := forward_speed if _cmd_forward > 0.0 else back_speed
	var forward_dir := -global_transform.basis.z   # в Godot «вперёд» = -Z
	var target := forward_dir * _cmd_forward * speed

	velocity.x = lerp(velocity.x, target.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target.z, acceleration * delta)

	# Гравитация
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Сообщаем остальным системам, едем ли мы (динамо, звук колёс и т.д.)
	var moving := _cmd_forward != 0.0 or _cmd_turn != 0.0
	if moving != _was_moving:
		_was_moving = moving
		movement_changed.emit(moving)
