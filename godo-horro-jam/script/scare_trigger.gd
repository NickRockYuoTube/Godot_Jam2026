extends Area3D
class_name ScareTrigger

signal triggered

@export var one_shot := true     # сработать только один раз
@export var delay := 0.0         # пауза между касанием и сценой, сек

var _used := false
var _scares: Array[ScareEvent] = []

func _ready() -> void:
	collision_layer = 0   # сам триггер ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	# Все ScareEvent среди детей запускаются вместе
	for child in get_children():
		if child is ScareEvent:
			_scares.append(child)

func _on_body_entered(body: Node3D) -> void:
	if not (body is Wheelchair):
		return
	if one_shot and _used:
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	triggered.emit()
	for scare in _scares:
		scare.play()
