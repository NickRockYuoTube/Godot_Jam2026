extends Label

func _ready() -> void:
	text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
