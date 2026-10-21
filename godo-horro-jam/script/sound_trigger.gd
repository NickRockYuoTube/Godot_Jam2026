extends Area3D
class_name SoundTrigger

@export var player: AudioStreamPlayer3D   # звук, который нужно запустить (например, телефон)
@export var delay := 0.0                  # пауза после касания, сек
@export var one_shot := true              # сыграть только один раз
@export var restart_if_playing := false   # перезапускать, если уже играет

var _used := false

func _ready() -> void:
	collision_layer = 0   # триггер сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if player == null:
		push_warning("SoundTrigger '%s': не назначен плеер" % name)

func _on_body_entered(body: Node3D) -> void:
	if not (body is Wheelchair) or player == null:
		return
	if one_shot and _used:
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(player):
		return

	if player.playing and not restart_if_playing:
		return
	player.play()
