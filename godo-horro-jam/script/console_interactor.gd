extends RayCast3D
class_name ConsoleInteractor

var _hovered: ConsoleButton = null
var _pressed: ConsoleButton = null

func _ready() -> void:
	enabled = true
	collide_with_areas = true
	collide_with_bodies = false
	collision_mask = 1 << 1   # только слой 2 (кнопки консоли)

func _physics_process(_delta: float) -> void:
	# Что сейчас под прицелом
	var hit := get_collider() as ConsoleButton

	if hit != _hovered:
		if _hovered:
			_hovered.set_hovered(false)
		_hovered = hit
		if _hovered:
			_hovered.set_hovered(true)

	# Кнопка нажата, пока зажат interact И прицел на ней
	var target: ConsoleButton = null
	if Input.is_action_pressed("interact") and _hovered != null:
		target = _hovered

	if target != _pressed:
		if _pressed:
			_pressed.set_pressed(false)
		_pressed = target
		if _pressed:
			_pressed.set_pressed(true)
