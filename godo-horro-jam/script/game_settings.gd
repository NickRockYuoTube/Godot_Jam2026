extends Node
# Autoload: GameSettings. Настройки игры и открытые концовки, сохраняются в user://settings.cfg

signal language_changed   # ← НОВОЕ
signal endings_changed

const SAVE_PATH := "user://settings.cfg"
const TOTAL_ENDINGS := 2
const ENDING_NAMES := {   # ← ИЗМЕНЕНО: теперь это ключи из таблицы переводов
	1: "ENDING_1",
	2: "ENDING_2",
}

const LANGUAGES := ["en", "ru"]                           # ← НОВОЕ
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский"}   # ← НОВОЕ

const BRIGHTNESS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float gamma = 1.0;
void fragment() {
	vec3 c = max(texture(screen_tex, SCREEN_UV).rgb, vec3(0.0));
	COLOR = vec4(pow(c, vec3(1.0 / gamma)), 1.0);
}
"""

var master_volume := 1.0        # 0..1
var mouse_sensitivity := 1.0    # множитель чувствительности
var brightness := 1.0           # гамма: больше = светлее тени
var fullscreen := false
var language := ""              # ← НОВОЕ: "" = определить по системе при первом запуске
var endings: Array[int] = []    # номера открытых концовок

var _gamma_rect: ColorRect
var _gamma_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_brightness_layer()
	load_all()
	apply_all()

# ---------------- Сохранение ----------------

func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return   # файла ещё нет, остаются значения по умолчанию
	master_volume = cfg.get_value("settings", "master_volume", 1.0)
	mouse_sensitivity = cfg.get_value("settings", "mouse_sensitivity", 1.0)
	brightness = cfg.get_value("settings", "brightness", 1.0)
	fullscreen = cfg.get_value("settings", "fullscreen", false)
	language = cfg.get_value("settings", "language", "")   # ← НОВОЕ
	endings.clear()
	for id in cfg.get_value("progress", "endings", []):
		endings.append(int(id))

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "brightness", brightness)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "language", language)   # ← НОВОЕ
	cfg.set_value("progress", "endings", endings)
	cfg.save(SAVE_PATH)

# ---------------- Применение настроек ----------------

func apply_all() -> void:
	_apply_language()   # ← НОВОЕ
	_apply_volume()
	_apply_brightness()
	if fullscreen:   # оконный режим не трогаем, пока игрок сам не переключил
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.1, 3.0)

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.5, 2.0)
	_apply_brightness()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	set_fullscreen(not is_full)

# ---------------- Язык ---------------- (← НОВОЕ: весь раздел)

func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		return
	language = code
	TranslationServer.set_locale(code)
	language_changed.emit()

# Переключает на следующий язык по кругу
func cycle_language() -> void:
	var i := LANGUAGES.find(language)
	set_language(LANGUAGES[(i + 1) % LANGUAGES.size()])

# Название текущего языка на нём самом (для кнопки)
func language_name() -> String:
	return LANGUAGE_NAMES.get(language, language)

func _apply_language() -> void:
	if language == "" or not LANGUAGES.has(language):
		language = "ru" if OS.get_locale_language() == "ru" else "en"   # по языку системы
	TranslationServer.set_locale(language)

# ---------------- Громкость, яркость ----------------

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))

func _apply_brightness() -> void:
	if _gamma_material == null:
		return
	_gamma_material.set_shader_parameter("gamma", brightness)
	_gamma_rect.visible = absf(brightness - 1.0) > 0.01   # при 1.0 фильтр не нужен

func _build_brightness_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10   # над 3D и обычным интерфейсом, под затемнениями, паузой и скримером
	add_child(layer)

	_gamma_rect = ColorRect.new()
	layer.add_child(_gamma_rect)
	_gamma_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gamma_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = BRIGHTNESS_SHADER
	_gamma_material = ShaderMaterial.new()
	_gamma_material.shader = shader
	_gamma_rect.material = _gamma_material

# ---------------- Концовки ----------------

# Возвращает true, если концовка открыта впервые
func unlock_ending(id: int) -> bool:
	if endings.has(id):
		return false
	endings.append(id)
	save_all()
	endings_changed.emit()   # ← НОВОЕ
	return true

func is_ending_unlocked(id: int) -> bool:
	return endings.has(id)

# Текст для меню: заголовок и список (открытые по имени, остальные «???»)
func endings_text() -> String:   # ← ИЗМЕНЕНО: названия и заголовок теперь переводятся
	var fmt := tr("ENDINGS_COUNT")
	if not fmt.contains("%d"):
		fmt = "Endings: %d / %d"   # запасной вариант, если ключа нет в таблице
	var lines: Array[String] = [fmt % [endings.size(), TOTAL_ENDINGS]]
	for id in ENDING_NAMES:
		lines.append(tr(ENDING_NAMES[id]) if endings.has(id) else "???")
	return "\n".join(lines)
	


# Для чит-кода: сбрасывает все открытые концовки
func reset_endings() -> void:
	endings.clear()
	save_all()
	endings_changed.emit()
	print("Чит-код: сохранённые концовки сброшены")
