extends Control

@onready var authors_panel = $AuthorsPanel
@onready var start_btn = $MenuRight/StartBtn
@onready var authors_btn = $MenuRight/AuthorsBtn
@onready var exit_btn = $MenuRight/ExitBtn
@onready var close_btn = $AuthorsPanel/VBoxContainer/CloseBtn

# Используем get_node_or_null: если узла нет, переменная будет просто null, и ошибки не будет
@onready var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound")
@onready var hover_sound: AudioStreamPlayer = get_node_or_null("HoverSound")

func _ready():
	var buttons = [start_btn, authors_btn, exit_btn, close_btn]
	
	for btn in buttons:
		if btn != null:
			btn.pressed.connect(_on_button_pressed.bind(btn))
			btn.mouse_entered.connect(_on_button_hover)
	
	start_btn.pressed.connect(_on_start_pressed)
	authors_btn.pressed.connect(_on_authors_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	close_btn.pressed.connect(_on_close_pressed)

func _on_button_pressed(btn: Button):
	if click_sound: # Проверяем, существует ли звук
		click_sound.play()

func _on_button_hover():
	if hover_sound and hover_sound.stream: # Проверяем и существование, и наличие аудиофайла
		hover_sound.play()

func _on_start_pressed():
	get_tree().change_scene_to_file("res://levels/Level1.tscn")

func _on_authors_pressed():
	authors_panel.visible = true

func _on_exit_pressed():
	get_tree().quit()

func _on_close_pressed():
	authors_panel.visible = false
