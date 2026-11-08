extends Area3D
class_name HintTrigger

@export_multiline var text := ""
@export var duration := 6.0          # сколько секунд висит подсказка
@export var one_shot := true
@export var show_on_start := false   # показать при запуске сцены (форма столкновения тогда не нужна)
@export var start_delay := 1.5       # пауза перед подсказкой при запуске, сек

var _used := false

func _ready() -> void:
	collision_layer = 0   # триггер сам ни с чем не сталкивается
	collision_mask = 1    # реагируем на слой 1 (коляска)
	body_entered.connect(_on_body_entered)

	if show_on_start:
		await get_tree().create_timer(start_delay).timeout
		_show()

func _on_body_entered(body: Node3D) -> void:
	if body is Wheelchair:
		_show()

func _show() -> void:
	if one_shot and _used:
		return
	_used = true
	Hints.show_hint(text, duration)
