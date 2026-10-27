extends Button
class_name SceneButton

@export_file("*.tscn") var target_scene: String   # на какую сцену перейти по нажатию

func _ready() -> void:
	pressed.connect(_on_pressed)
	if target_scene.is_empty():
		push_warning("SceneButton '%s': не выбрана целевая сцена" % name)

func _on_pressed() -> void:
	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_warning("SceneButton '%s': сцена '%s' не найдена" % [name, target_scene])
		return
	get_tree().change_scene_to_file.call_deferred(target_scene)
