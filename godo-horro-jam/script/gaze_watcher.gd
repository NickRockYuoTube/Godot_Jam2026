extends RayCast3D
class_name GazeWatcher

@export var max_distance := 4   # дальность взгляда, 3-4 м

var _current: GazeTarget = null

func _ready() -> void:
	enabled = true
	target_position = Vector3(0, 0, -max_distance)
	collide_with_areas = true
	collide_with_bodies = true
	# Слой 1 (стены, чтобы нельзя было «увидеть» сквозь стену) + слой 3 (цели взгляда)
	collision_mask = (1 << 0) | (1 << 2)

	# Луч не должен упираться в саму коляску
	var chair := _find_chair()
	if chair:
		add_exception(chair)

func _find_chair() -> Wheelchair:
	var node := get_parent()
	while node:
		if node is Wheelchair:
			return node
		node = node.get_parent()
	return null

func _physics_process(_delta: float) -> void:
	# Если первым луч встретил стену, hit будет null
	var hit := get_collider() as GazeTarget

	if hit != _current:
		if is_instance_valid(_current):
			_current.set_looked_at(false)
		_current = hit
		if _current:
			_current.set_looked_at(true)
