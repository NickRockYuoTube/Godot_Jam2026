extends AudioStreamPlayer3D
class_name LoopSound

@export_enum("Movement", "Flashlight") var trigger := 0
@export var fade_time := 0.4
@export var volume_on_db := 0.0

const VOLUME_OFF_DB := -60.0
var _tween: Tween

func _ready() -> void:
	volume_db = VOLUME_OFF_DB
	match trigger:
		0:
			PowerSystem.moving_changed.connect(set_active)
			if PowerSystem.is_moving:
				set_active(true)
		1:
			PowerSystem.flashlight_changed.connect(set_active)
			if PowerSystem.flashlight_on:
				set_active(true)

func set_active(active: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if active:
		if not playing:
			play()
		_tween.tween_property(self, "volume_db", volume_on_db, fade_time)
	else:
		_tween.tween_property(self, "volume_db", VOLUME_OFF_DB, fade_time)
		_tween.tween_callback(stop)
