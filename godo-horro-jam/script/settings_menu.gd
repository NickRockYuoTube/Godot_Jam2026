extends Control

@export_file("*.tscn") var menu_scene: String   # главное меню (выбери в Inspector)

@onready var click_sound: AudioStreamPlayer = get_node_or_null("ClickSound")
@onready var hover_sound: AudioStreamPlayer = get_node_or_null("HoverSound")

var _changing := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Ползунки: имя, минимум, максимум, текущее значение, что вызвать при изменении
	_setup_slider("VolumeSlider", 0.0, 1.0, GameSettings.master_volume, GameSettings.set_master_volume)
	_setup_slider("BrightnessSlider", 0.6, 1.8, GameSettings.brightness, GameSettings.set_brightness)
	_setup_slider("SensitivitySlider", 0.3, 2.0, GameSettings.mouse_sensitivity, GameSettings.set_mouse_sensitivity)

	var fs := find_child("FullscreenCheck", true, false) as BaseButton
	if fs:
		fs.button_pressed = GameSettings.fullscreen
		fs.toggled.connect(GameSettings.set_fullscreen)

	var back := find_child("BackBtn", true, false) as Button
	if back:
		back.pressed.connect(_on_back_pressed)
		back.mouse_entered.connect(_on_hover)
	else:
		push_warning("Settings: не найдена кнопка BackBtn")

func _setup_slider(slider_name: String, min_v: float, max_v: float, value: float, callback: Callable) -> void:
	var slider := find_child(slider_name, true, false) as Range
	if slider == null:
		push_warning("Settings: не найден ползунок %s" % slider_name)
		return
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(callback)

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
		push_warning("Settings: не выбрана сцена меню (поле Menu Scene)")
		return
	_changing = true
	GameSettings.save_all()   # настройки сохраняются при выходе
	await get_tree().create_timer(0.12).timeout   # даём прозвучать клику
	get_tree().change_scene_to_file(menu_scene)
