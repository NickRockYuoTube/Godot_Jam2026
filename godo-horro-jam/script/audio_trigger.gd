extends Area3D
class_name AudioTrigger

enum Action { PLAY, STOP }

@export var player: Node                  # AudioStreamPlayer (или AudioStreamPlayer3D) на уровне
@export var action: Action = Action.PLAY  # что сделать при пересечении
@export var fade_time := 2.0              # плавность, сек (0 = мгновенно)
@export var one_shot := false             # true = сработать только один раз

const SILENT_DB := -60.0

var _used := false

func _ready() -> void:
	collision_layer = 0   # триггер сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if player == null:
		push_warning("AudioTrigger '%s': не назначен плеер" % name)
		return
	# Запоминаем исходную громкость плеера, чтобы возвращаться к ней
	if not player.has_meta("base_db"):
		player.set_meta("base_db", player.get("volume_db"))

func _on_body_entered(body: Node3D) -> void:
	if not (body is Wheelchair) or player == null:
		return
	if one_shot and _used:
		return
	_used = true

	if action == Action.PLAY:
		_play_music()
	else:
		_stop_music()

func _play_music() -> void:
	var p = player
	var base_db := _base_db()
	_kill_fade()

	if fade_time <= 0.0:
		p.volume_db = base_db
		if not p.playing:
			p.play()
		return

	if not p.playing:
		p.volume_db = SILENT_DB
		p.play()
	var tween := create_tween()
	player.set_meta("fade_tween", tween)
	tween.tween_property(p, "volume_db", base_db, fade_time)

func _stop_music() -> void:
	var p = player
	var base_db := _base_db()
	_kill_fade()

	if not p.playing:
		return
	if fade_time <= 0.0:
		p.stop()
		p.volume_db = base_db
		return

	var tween := create_tween()
	player.set_meta("fade_tween", tween)
	tween.tween_property(p, "volume_db", SILENT_DB, fade_time)
	tween.tween_callback(func() -> void:
		p.stop()
		p.volume_db = base_db   # возвращаем громкость для следующего запуска
	)

func _base_db() -> float:
	return float(player.get_meta("base_db", 0.0))

# Останавливает прошлый фейд этого плеера, чтобы триггеры не мешали друг другу
func _kill_fade() -> void:
	if not player.has_meta("fade_tween"):
		return   # фейдов ещё не было, останавливать нечего
	var old = player.get_meta("fade_tween")
	if old is Tween and old.is_valid():
		old.kill()
