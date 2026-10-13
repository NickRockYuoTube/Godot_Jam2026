extends Node3D
class_name Terminal

signal command_changed(forward: float, turn: float)

var _active := {}   # Command -> bool

func _ready() -> void:
	_collect_buttons(self)

func _collect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is ConsoleButton:
			child.pressed_changed.connect(_on_button_pressed_changed)
		_collect_buttons(child)

func _on_button_pressed_changed(command: ConsoleButton.Command, is_pressed: bool) -> void:
	_active[command] = is_pressed
	var forward := _axis(ConsoleButton.Command.FORWARD, ConsoleButton.Command.BACK)
	var turn := _axis(ConsoleButton.Command.TURN_LEFT, ConsoleButton.Command.TURN_RIGHT)
	command_changed.emit(forward, turn)

func _axis(positive: ConsoleButton.Command, negative: ConsoleButton.Command) -> float:
	return float(_active.get(positive, false)) - float(_active.get(negative, false))
