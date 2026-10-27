extends Control

const START_LEVEL := "res://levels/Level1.tscn"

@export_file("*.tscn") var authors_scene: String   # сцена с авторами (выбери в Inspector)

@onready var start_btn = $MenuRight/StartBtn
@onready var authors_btn = $MenuRight/AuthorsBtn
@onready var exit_btn = $MenuRight/ExitBtn

# Используем get_node_or_null: если узла нет, переменная будет просто null, и ошибки не будет
@onready var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound")
@onready var hover_sound: AudioStreamPlayer = get_node_or_null("HoverSound")

var _changing := false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # курсор после игры снова виден

	var buttons = [start_btn, authors_btn, exit_btn]

	for btn in buttons:
		if btn != null:
			btn.pressed.connect(_on_button_pressed.bind(btn))
			btn.mouse_entered.connect(_on_button_hover)

	start_btn.pressed.connect(_on_start_pressed)
	authors_btn.pressed.connect(_on_authors_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func _on_button_pressed(btn: Button):
	if click_sound: # Проверяем, существует ли звук
		click_sound.play()

func _on_button_hover():
	if hover_sound and hover_sound.stream: # Проверяем и существование, и наличие аудиофайла
		hover_sound.play()

func _on_start_pressed():
	_change_scene(START_LEVEL)

func _on_authors_pressed():
	_change_scene(authors_scene)

func _on_exit_pressed():
	get_tree().quit()

# Переход с небольшой паузой, чтобы успел прозвучать клик
func _change_scene(path: String) -> void:
	if _changing:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Меню: сцена '%s' не найдена" % path)
		return
	_changing = true
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(path)
