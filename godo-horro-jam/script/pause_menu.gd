extends Node
# Autoload: PauseMenu. ESC ставит игру на паузу и снимает её.

# Путь к сцене паузы. Оформление (шрифт, цвета, надписи) настраивай прямо в ней.
# Точный путь: в панели файлов правая кнопка по сцене → «Копировать путь»
const PAUSE_SCENE_PATH := "res://scen/PauseScreen.tscn"

var _layer: CanvasLayer
var _screen: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # работает и во время паузы, иначе второй ESC не поймать

	_layer = CanvasLayer.new()
	_layer.layer = 120                        # поверх всего интерфейса
	add_child(_layer)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):   # ESC
		return

	if get_tree().paused:
		_set_paused(false)
	elif _in_gameplay() and not PlayerHealth.is_dead:
		_set_paused(true)
	else:
		return   # в меню и на сценах концовок пауза не нужна
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Если сцена сменилась, пока шла пауза, снимаем её, чтобы меню не зависло
	if get_tree().paused and not _in_gameplay():
		_set_paused(false)

func _set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		_show_screen()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_hide_screen()
		if _in_gameplay():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # возвращаем управление камерой

# Создаёт экран паузы из сцены (каждый раз заново, поэтому правки в сцене видны сразу)
func _show_screen() -> void:
	if _screen and is_instance_valid(_screen):
		return
	if ResourceLoader.exists(PAUSE_SCENE_PATH):
		_screen = (load(PAUSE_SCENE_PATH) as PackedScene).instantiate()
	else:
		push_warning("PauseMenu: сцена '%s' не найдена, показываю простой экран" % PAUSE_SCENE_PATH)
		_screen = _build_default_screen()
	_screen.process_mode = Node.PROCESS_MODE_ALWAYS   # анимации и кнопки работают во время паузы
	_layer.add_child(_screen)

func _hide_screen() -> void:
	if _screen and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null

# Запасной вариант на случай, если сцены нет
func _build_default_screen() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.text = "ПАУЗА\n\nESC — продолжить"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root

# Игра идёт, если на сцене есть коляска (она в группе "player")
func _in_gameplay() -> bool:
	return get_tree().get_first_node_in_group("player") != null
