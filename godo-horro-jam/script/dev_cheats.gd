extends Node
# Autoload: DevCheats. Быстрые переходы по уровням для тестов:
# зажми H и нажми цифру (H+1 = Level1, H+2 = Level2 и т.д.)

# Шаблон пути к уровням: %d заменяется цифрой
const LEVEL_PATH := "res://levels/Level%d.tscn"

# Другие сцены на цифры, которые не подходят под шаблон (например, концовки).
# Формат: цифра: "путь". Путь проще взять через «Копировать путь» в панели файлов
const EXTRA_SCENES := {
	# 5: "res://levels/GoodEND.tscn",
	# 6: "res://levels/BedEND.tscn",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # работает и во время паузы
	if not OS.is_debug_build():
		set_process_input(false)   # в релизной сборке чит выключен

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Физическая клавиша H: работает при любой раскладке (RU и EN)
	if not Input.is_physical_key_pressed(KEY_H):
		return

	var digit := _digit_of(key.physical_keycode)
	if digit < 0:
		return

	var path: String = EXTRA_SCENES.get(digit, LEVEL_PATH % digit)
	_go_to(path)

# Цифра с основной клавиатуры или с цифрового блока, иначе -1
func _digit_of(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return -1

func _go_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("DevCheats: сцена '%s' не найдена" % path)
		return
	print("Чит-код: загружаю ", path)

	if get_tree().paused:
		PauseMenu._set_paused(false)   # снимаем паузу, чтобы новая сцена не зависла
	PlayerHealth.reset()               # свежее состояние для теста
	PowerSystem.reset()
	get_tree().change_scene_to_file.call_deferred(path)
