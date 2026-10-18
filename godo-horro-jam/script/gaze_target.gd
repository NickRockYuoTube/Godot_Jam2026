extends Area3D
class_name GazeTarget

signal gaze_started
signal gaze_ended
signal gaze_completed       # на цель смотрели достаточно долго

@export var look_time := 0.3        # сколько секунд нужно смотреть, 0 = мгновенно
@export var one_shot := true        # сработать только один раз

const GAZE_LAYER := 1 << 2          # слой 3

var is_looked_at := false
var _timer := 0.0
var _fired_this_gaze := false
var _consumed := false

func _ready() -> void:
	collision_layer = GAZE_LAYER
	collision_mask = 0

func set_enabled(value: bool) -> void:
	# Выключенная цель луч не видит
	collision_layer = GAZE_LAYER if value else 0
	if not value:
		is_looked_at = false

func set_looked_at(value: bool) -> void:
	if value == is_looked_at:
		return
	is_looked_at = value
	_timer = 0.0
	_fired_this_gaze = false
	if value:
		gaze_started.emit()
	else:
		gaze_ended.emit()

func _process(delta: float) -> void:
	if not is_looked_at or _fired_this_gaze or _consumed:
		return
	_timer += delta
	if _timer >= look_time:
		_fired_this_gaze = true
		if one_shot:
			_consumed = true
		gaze_completed.emit()
