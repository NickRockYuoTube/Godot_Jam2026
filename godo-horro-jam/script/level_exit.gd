extends Area3D
class_name LevelExit

@export_file("*.tscn") var next_level: String   # выбери сцену следующего уровня
@export var delay := 0.0                         # пауза перед переходом, сек

var _used := false

func _ready() -> void:
	collision_layer = 0   # триггер сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if next_level.is_empty():
		push_warning("LevelExit '%s': не выбран следующий уровень" % name)

func _on_body_entered(body: Node3D) -> void:
	if _used or not (body is Wheelchair):
		return
	if next_level.is_empty() or not ResourceLoader.exists(next_level):
		push_warning("LevelExit '%s': сцена '%s' не найдена" % [name, next_level])
		return
	_used = true

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	# Глобальный PowerSystem живёт между уровнями. Без этого он «думает»,
	# что коляска всё ещё едет, и динамо с колёсами продолжают работать.
	PowerSystem.set_moving(false)

	# Отложенно, чтобы не удалять физические узлы внутри их собственного сигнала
	get_tree().change_scene_to_file.call_deferred(next_level)
