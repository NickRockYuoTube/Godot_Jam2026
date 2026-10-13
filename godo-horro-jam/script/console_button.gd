extends Area3D
class_name ConsoleButton

enum Command { FORWARD, BACK, TURN_LEFT, TURN_RIGHT }

signal pressed_changed(command: Command, is_pressed: bool)

@export var command: Command = Command.FORWARD
@export var mesh: MeshInstance3D
@export var glow_color := Color(1.0, 0.25, 0.1)

var is_hovered := false
var is_pressed := false
var _mat: StandardMaterial3D

func _ready() -> void:
	if mesh == null:
		return
	# Копия материала, чтобы подсвечивалась только эта стрелка
	var base := mesh.get_active_material(0)
	_mat = base.duplicate() as StandardMaterial3D if base else null
	if _mat == null:
		_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission = glow_color
	mesh.set_surface_override_material(0, _mat)
	_update_visual()

func set_hovered(value: bool) -> void:
	is_hovered = value
	_update_visual()

func set_pressed(value: bool) -> void:
	if is_pressed == value:
		return
	is_pressed = value
	_update_visual()
	pressed_changed.emit(command, is_pressed)

func _update_visual() -> void:
	if _mat == null:
		return
	if is_pressed:
		_mat.emission_energy_multiplier = 3.0
	elif is_hovered:
		_mat.emission_energy_multiplier = 1.0
	else:
		_mat.emission_energy_multiplier = 0.0
