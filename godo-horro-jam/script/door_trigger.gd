extends Area3D
class_name DoorTrigger

enum Action { OPEN, CLOSE }

@export var door: Door                       # какая дверь
@export var action: Action = Action.OPEN     # что делает: открыть или закрыть
@export var delay := 0.0                     # пауза после касания, сек
@export var auto_close_time := 0.0           # закрыть через N сек (0 = не закрывать)
@export var one_shot := false                # сработать только один раз
@export var react_to_monster := true         # ← НОВОЕ: срабатывать и от монстра

var _used := false
var _close_token := 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (1 << 3)   # слой 1 (коляска) + слой 4 (датчик монстра)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if door == null:
		push_warning("DoorTrigger '%s': не назначена дверь" % name)

func _on_body_entered(body: Node3D) -> void:
	if body is Wheelchair:
		_activate(true)    # дверь открыл игрок

func _on_area_entered(area: Area3D) -> void:
	if react_to_monster and area.is_in_group("monster_sensor"):
		_activate(false)   # дверь открыл монстр

func _activate(by_player: bool = false) -> void:
	if door == null:
		return
	if one_shot and _used:
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(door):
		return

	if action == Action.OPEN:
		door.open(by_player)
		if auto_close_time > 0.0:
			_start_auto_close()
	else:
		door.close()

func _start_auto_close() -> void:
	_close_token += 1
	var token := _close_token

	await get_tree().create_timer(auto_close_time).timeout
	if token != _close_token or not is_instance_valid(door):
		return
	door.close()
