extends Area3D
class_name MonsterTrigger

enum Action { ACTIVATE, DEACTIVATE }

@export var monster: RoamingMonster          # если пусто, берётся первый монстр на уровне
@export var action: Action = Action.ACTIVATE
@export var spawn_at: Marker3D               # где появиться (пусто = самая дальняя от игрока точка)
@export var delay := 0.0                     # пауза после касания, сек
@export var one_shot := true

var _used := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not (body is Wheelchair):
		return
	if one_shot and _used:
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	var target := monster
	if target == null:
		target = get_tree().get_first_node_in_group("roaming_monsters") as RoamingMonster
	if target == null:
		push_warning("MonsterTrigger '%s': монстр не найден" % name)
		return

	if action == Action.ACTIVATE:
		target.activate(spawn_at)
	else:
		target.deactivate()   # например, безопасная зона
