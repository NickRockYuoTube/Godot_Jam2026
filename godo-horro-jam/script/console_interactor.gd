extends RayCast3D
class_name ConsoleInteractor

var _hovered: ConsoleButton = null
var _pressed: ConsoleButton = null
var _hover_time := 0.0

func _ready() -> void:
	enabled = true
	collide_with_areas = true
	collide_with_bodies = false
	collision_mask = 1 << 1   # только слой 2 (кнопки консоли)

func _physics_process(delta: float) -> void:
	# Что сейчас под прицелом
	var hit := get_collider() as ConsoleButton

	if hit != _hovered:
		if _hovered:
			_hovered.set_hovered(false)
		_hovered = hit
		_hover_time = 0.0
		if _hovered:
			_hovered.set_hovered(true)
	elif _hovered:
		_hover_time += delta

	# Кнопка активна, пока на неё смотрят дольше dwell_time
	var target: ConsoleButton = null
	if _hovered and _hover_time >= _hovered.dwell_time:
		target = _hovered

	if target != _pressed:
		if _pressed:
			_pressed.set_pressed(false)
		_pressed = target
		if _pressed:
			_pressed.set_pressed(true)
