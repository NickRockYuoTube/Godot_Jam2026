extends ScareEvent
class_name GazeMonster

@export var gaze_target: GazeTarget
@export var vanish_zone: Area3D          # зона: если коляска заехала, монстр исчезает
@export var vanish_sound: AudioStreamPlayer3D
@export var anim_player: AnimationPlayer
@export var idle_animation := ""         # анимация, пока монстр стоит (необязательно)
@export var start_hidden := false        # true = появляется только по ScareTrigger
@export var free_after_vanish := true    # удалить монстра после исчезновения

var _active := false
var _vanished := false

func _ready() -> void:
	add_to_group("gaze_monsters")   # ← НОВОЕ: по этой группе триггер находит монстра

	# Автопоиск по именам, если поля не заполнены в Inspector
	if gaze_target == null:
		gaze_target = find_child("GazeTarget", true, false) as GazeTarget
	if vanish_zone == null:
		vanish_zone = find_child("VanishZone", true, false) as Area3D
	if vanish_sound == null:
		vanish_sound = find_child("VanishSound", true, false) as AudioStreamPlayer3D
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	if gaze_target:
		gaze_target.gaze_completed.connect(_on_gazed)

	if vanish_zone:
		vanish_zone.collision_layer = 0   # зона сама ни с чем не сталкивается
		vanish_zone.collision_mask = 1    # реагируем на слой 1 (коляска)
		vanish_zone.body_entered.connect(_on_zone_entered)

	_set_active(not start_hidden)

# Вызывает ScareTrigger, если монстр должен появиться по триггеру
func play() -> void:
	_set_active(true)

# Принудительное исчезновение (вызывается триггером VanishScare)   ← НОВОЕ
func vanish() -> void:
	_on_gazed()

func _set_active(active: bool) -> void:
	_active = active
	if active:
		_vanished = false
	visible = active
	if gaze_target:
		gaze_target.set_enabled(active)
	if active and anim_player and idle_animation != "" and anim_player.has_animation(idle_animation):
		anim_player.play(idle_animation)

func _on_zone_entered(body: Node3D) -> void:
	if _active and body is Wheelchair:
		_on_gazed.call_deferred()   # отложенно, чтобы не менять физику внутри её сигнала

func _on_gazed() -> void:
	if _vanished or not _active:
		return   # уже исчез, повторно не срабатываем
	_vanished = true
	_set_active(false)
	if vanish_sound:
		vanish_sound.play()
		await vanish_sound.finished   # звук доигрывает, пока узел ещё жив
	finished.emit()
	if free_after_vanish:
		queue_free()
