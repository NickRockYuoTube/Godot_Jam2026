extends Area3D
class_name TriggerSwitch

enum Action { ENABLE, DISABLE, TOGGLE }

@export var targets: Array[Area3D] = []     # какие триггеры включать/выключать
@export var action: Action = Action.ENABLE
@export var delay := 0.0                    # пауза после касания, сек
@export var one_shot := true

var _used := false

func _ready() -> void:
	collision_layer = 0   # переключатель сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if targets.is_empty():
		push_warning("TriggerSwitch '%s': не выбраны целевые триггеры" % name)

func _on_body_entered(body: Node3D) -> void:
	if not (body is Wheelchair):
		return
	if one_shot and _used:
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	for target in targets:
		if not is_instance_valid(target):
			continue
		# Отложенно, чтобы не менять физику внутри её собственного сигнала
		match action:
			Action.ENABLE:
				target.set_deferred("monitoring", true)
			Action.DISABLE:
				target.set_deferred("monitoring", false)
			Action.TOGGLE:
				target.set_deferred("monitoring", not target.monitoring)
