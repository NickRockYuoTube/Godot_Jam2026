extends Control

@export_file("*.tscn") var menu_scene: String   # главное меню (выбери в Inspector)
@export var back_button: Button                 # если пусто, найдётся по имени

# Необязательные звуки: если таких узлов нет, ничего не произойдёт
@onready var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound")
@onready var hover_sound: AudioStreamPlayer = get_node_or_null("HoverSound")

var _changing := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Ищем кнопку по имени среди детей, если не назначена в Inspector
	if back_button == null:
		back_button = find_child("BackBtn", true, false) as Button
	if back_button == null:
		back_button = find_child("CloseBtn", true, false) as Button
	if back_button == null:
		push_warning("Authors: не найдена кнопка возврата (BackBtn или CloseBtn)")
		return

	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_on_hover)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # ESC тоже возвращает в меню
		_go_back()

func _on_hover() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.play()

func _on_back_pressed() -> void:
	if click_sound:
		click_sound.play()
	_go_back()

func _go_back() -> void:
	if _changing:
		return
	if menu_scene.is_empty() or not ResourceLoader.exists(menu_scene):
		push_warning("Authors: не выбрана сцена меню (поле Menu Scene)")
		return
	_changing = true
	await get_tree().create_timer(0.12).timeout   # даём прозвучать клику
	get_tree().change_scene_to_file(menu_scene)
