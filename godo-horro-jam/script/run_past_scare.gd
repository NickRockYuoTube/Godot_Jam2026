extends ScareEvent
class_name RunPastScare

@export var monster: Node3D
@export var start_point: Marker3D
@export var end_point: Marker3D
@export var sound: AudioStreamPlayer3D
@export var anim_player: AnimationPlayer
@export var animation_name := "mixamo_com_001"      # точное имя анимации из AnimationPlayer
@export var animation_speed := 1.0
@export var loop_animation := true       # зациклить бег на время пробежки
@export var duration := 1.2              # за сколько секунд монстр пробегает путь
@export var hide_when_done := true

var _playing := false

func _ready() -> void:
	# Автопоиск по именам, если поля не заполнены в Inspector
	if monster == null:
		monster = find_child("Monster", true, false) as Node3D
	if start_point == null:
		start_point = find_child("StartPoint", true, false) as Marker3D
	if end_point == null:
		end_point = find_child("EndPoint", true, false) as Marker3D
	if sound == null and monster:
		sound = monster.find_child("ScareSound", true, false) as AudioStreamPlayer3D
	if anim_player == null and monster:
		anim_player = monster.find_child("AnimationPlayer", true, false) as AnimationPlayer

	# Импортированные анимации по умолчанию не зациклены
	if anim_player and loop_animation and anim_player.has_animation(animation_name):
		anim_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR

	if monster:
		monster.visible = false   # до сцены монстра не видно

func play() -> void:
	if _playing or monster == null or start_point == null or end_point == null:
		return
	_playing = true

	monster.global_position = start_point.global_position
	monster.look_at(end_point.global_position, Vector3.UP)
	monster.visible = true

	# Запуск анимации
	if anim_player:
		if anim_player.has_animation(animation_name):
			anim_player.play(animation_name, -1, animation_speed)
		else:
			push_warning("Нет анимации '%s'. Доступные: %s" % [animation_name, anim_player.get_animation_list()])

	if sound:
		sound.play()

	var tween := create_tween()
	tween.tween_property(monster, "global_position", end_point.global_position, duration)
	tween.tween_callback(_on_done)

func _on_done() -> void:
	if anim_player:
		anim_player.stop()
	if hide_when_done:
		monster.visible = false
	_playing = false
	finished.emit()
