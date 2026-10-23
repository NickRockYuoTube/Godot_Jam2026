extends Node
class_name AutoLevelChange

@export var music: AudioStream                  # мелодия (перетащи файл сюда)
@export_file("*.tscn") var next_level: String   # куда перейти после мелодии
@export var volume_db := 0.0
@export var start_delay := 0.5                  # пауза перед началом мелодии, сек
@export var end_delay := 1.0                    # пауза после окончания мелодии, сек
@export var allow_skip := true                  # Enter / Пробел пропускают мелодию

var _player: AudioStreamPlayer
var _changing := false

func _ready() -> void:
	if next_level.is_empty() or not ResourceLoader.exists(next_level):
		push_warning("AutoLevelChange '%s': не выбран следующий уровень" % name)
		return
	if music == null:
		push_warning("AutoLevelChange '%s': не выбрана мелодия" % name)
		return

	_player = AudioStreamPlayer.new()
	_player.stream = music
	_player.volume_db = volume_db
	add_child(_player)

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_player.play()

	# Ждём конца мелодии. Считаем по длине трека, поэтому Loop в импорте
	# выключать не обязательно. Если длина неизвестна, ждём сигнал finished
	var length := music.get_length()
	if length > 0.0:
		await get_tree().create_timer(length).timeout
	else:
		await _player.finished

	if end_delay > 0.0:
		await get_tree().create_timer(end_delay).timeout
	_go_next()

func _unhandled_input(event: InputEvent) -> void:
	if allow_skip and event.is_action_pressed("ui_accept"):
		_go_next()

func _go_next() -> void:
	if _changing:
		return   # защита от двойного перехода (например, пропуск + конец мелодии)
	_changing = true
	PowerSystem.set_moving(false)   # на случай, если пришли из игры во время движения
	get_tree().change_scene_to_file.call_deferred(next_level)
