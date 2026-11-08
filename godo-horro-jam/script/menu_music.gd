extends Node
# Autoload: MenuMusic. Музыка меню играет непрерывно между экранами меню, настроек и авторов
# и плавно затихает, когда игрок уходит на другие сцены.

const MUSIC_PATH := "res://music/HorrorThemMenuV2.ogg"   # путь к музыке меню (проверь!)
const MENU_SCENES := ["Menu", "Authors", "Settings", "SettingMenu"]   # где играет: имя корневого узла или файла сцены
const VOLUME_DB := 0.0
const FADE_IN := 1.0       # сек, плавное появление при первом запуске
const FADE_OUT := 1.2      # сек, затухание при уходе из меню
const SILENT_DB := -40.0

var _player: AudioStreamPlayer
var _tween: Tween
var _last_scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	if ResourceLoader.exists(MUSIC_PATH):
		_player.stream = load(MUSIC_PATH)
		if "loop" in _player.stream:
			_player.stream.loop = true   # зацикливаем
	else:
		push_warning("MenuMusic: нет файла музыки '%s'" % MUSIC_PATH)
	add_child(_player)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _last_scene:
		return   # во время смены сцены current_scene может быть пустым
	_last_scene = scene

	var base := scene.scene_file_path.get_file().get_basename()
	if MENU_SCENES.has(String(scene.name)) or MENU_SCENES.has(base):
		_start()
	else:
		_stop()

func _start() -> void:
	if _player.stream == null:
		return
	_kill_tween()
	if _player.playing:
		# Уже играет: просто возвращаем громкость, если шло затухание. Не перезапускаем!
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", VOLUME_DB, 0.3)
		return
	_player.volume_db = SILENT_DB
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME_DB, FADE_IN)

func _stop() -> void:
	if not _player.playing:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT)
	_tween.tween_callback(_player.stop)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
