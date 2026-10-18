extends ScareEvent
class_name VanishScare

# Если поле пустое, берётся ближайший к триггеру монстр
@export var monster: GazeMonster

func play() -> void:
	var target := monster
	if target == null:
		target = _find_nearest_monster()
	if target == null:
		push_warning("VanishScare: монстр не найден (возможно, он уже исчез)")
		return
	target.vanish()
	finished.emit()

func _find_nearest_monster() -> GazeMonster:
	var best: GazeMonster = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("gaze_monsters"):
		var m := node as GazeMonster
		if m == null:
			continue
		var d := global_position.distance_to(m.global_position)
		if d < best_dist:
			best_dist = d
			best = m
	return best
