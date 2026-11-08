extends Node
# Autoload: Hints. Показывает подсказки внизу экрана: Hints.show_hint("текст", 6.0)

const FONT_SIZE := 28
const BOTTOM_MARGIN := 90.0   # отступ от нижнего края экрана

var _label: Label
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.layer = 80   # над игрой, под затемнениями, паузой и скримером
	add_child(layer)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.modulate.a = 0.0
	layer.add_child(_label)

	# Привязываем к низу экрана, текст растёт вверх
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 40.0
	_label.offset_right = -40.0
	_label.offset_bottom = -BOTTOM_MARGIN
	_label.offset_top = -BOTTOM_MARGIN - 10.0
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

func show_hint(text: String, duration := 6.0, fade := 0.6) -> void:
	_label.text = text
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, fade)
	_tween.tween_interval(maxf(duration - fade * 2.0, 0.1))
	_tween.tween_property(_label, "modulate:a", 0.0, fade)

func hide_hint(fade := 0.4) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 0.0, fade)
