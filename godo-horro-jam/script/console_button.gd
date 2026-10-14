extends Area3D
class_name ConsoleButton

enum Command { FORWARD, BACK, TURN_LEFT, TURN_RIGHT, FLASHLIGHT }

signal pressed_changed(command: Command, is_pressed: bool)

@export var command: Command = Command.FORWARD
@export var mesh: MeshInstance3D
@export var lamp: OmniLight3D
@export var click_sound: AudioStreamPlayer3D
@export var glow_color := Color(1.0, 0.25, 0.1)
@export var lamp_energy_on := 1.5

var is_hovered := false
var is_pressed := false
var _mat: StandardMaterial3D

func _ready() -> void:
	if mesh:
		var base := mesh.get_active_material(0)
		_mat = base.duplicate() as StandardMaterial3D if base else null
		if _mat == null:
			_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		_mat.emission = glow_color
		mesh.set_surface_override_material(0, _mat)

	# Если не назначено вручную, ищем среди детей
	for child in get_children():
		if lamp == null and child is OmniLight3D:
			lamp = child
		if click_sound == null and child is AudioStreamPlayer3D:
			click_sound = child

	if lamp:
		lamp.light_color = glow_color
		lamp.light_energy = lamp_energy_on
		lamp.visible = false

	_update_visual()

func set_hovered(value: bool) -> void:
	is_hovered = value
	_update_visual()

func set_pressed(value: bool) -> void:
	if is_pressed == value:
		return
	is_pressed = value
	if is_pressed and click_sound:
		click_sound.play()   # щелчок при нажатии
	_update_visual()
	pressed_changed.emit(command, is_pressed)

func _update_visual() -> void:
	if _mat:
		if is_pressed:
			_mat.emission_energy_multiplier = 3.0
		elif is_hovered:
			_mat.emission_energy_multiplier = 1.0
		else:
			_mat.emission_energy_multiplier = 0.0
	if lamp:
		lamp.visible = is_pressed
