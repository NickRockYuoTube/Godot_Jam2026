extends Node3D
class_name Terminal

# Сигнал: что сейчас нажато на терминале
# forward: 1 = вперёд, -1 = назад; turn: 1 = влево, -1 = вправо
signal command_changed(forward: float, turn: float)

var _forward := 0.0
var _turn := 0.0

func _process(_delta: float) -> void:
	var f := Input.get_axis("chair_back", "chair_forward")
	var t := Input.get_axis("chair_turn_right", "chair_turn_left")
	# Шлём сигнал только при изменении
	if f != _forward or t != _turn:
		_forward = f
		_turn = t
		command_changed.emit(_forward, _turn)
