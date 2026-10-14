extends Node3D
class_name FlashlightPanel

@export var button: ConsoleButton
@export var spot: SpotLight3D
@export var lamp_green: OmniLight3D
@export var lamp_orange: OmniLight3D
@export var lamp_red: OmniLight3D
@export var warning_sound: AudioStreamPlayer3D

func _ready() -> void:
	if button == null:
		button = find_child("BtnFlashlight", true, false) as ConsoleButton
	if spot == null:
		spot = find_child("SpotLight3D", true, false) as SpotLight3D
	if lamp_green == null:
		lamp_green = find_child("LampGreen", true, false) as OmniLight3D
	if lamp_orange == null:
		lamp_orange = find_child("LampOrange", true, false) as OmniLight3D
	if lamp_red == null:
		lamp_red = find_child("LampRed", true, false) as OmniLight3D
	if warning_sound == null:
		warning_sound = find_child("WarningSound", true, false) as AudioStreamPlayer3D

	button.pressed_changed.connect(_on_button_pressed_changed)
	PowerSystem.flashlight_changed.connect(_on_flashlight_changed)
	PowerSystem.level_changed.connect(_on_level_changed)
	_on_flashlight_changed(PowerSystem.flashlight_on)
	_on_level_changed(PowerSystem.level)

func _on_button_pressed_changed(_command: ConsoleButton.Command, is_pressed: bool) -> void:
	if is_pressed:
		PowerSystem.toggle_flashlight()

func _on_flashlight_changed(is_on: bool) -> void:
	spot.visible = is_on
	if is_on and PowerSystem.level == PowerSystem.Level.EMPTY:
		_warn()

func _on_level_changed(level: int) -> void:
	lamp_green.visible = level == PowerSystem.Level.FULL
	lamp_orange.visible = level == PowerSystem.Level.HALF
	lamp_red.visible = level == PowerSystem.Level.EMPTY
	if level == PowerSystem.Level.EMPTY and PowerSystem.flashlight_on:
		_warn()

func _warn() -> void:
	if warning_sound and not warning_sound.playing:
		warning_sound.play()
