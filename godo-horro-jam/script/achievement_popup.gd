extends Node
class_name AchievementPopup

@export var text := "Ending 1 Unlocked"
@export var delay := 1.5            # пауза после запуска сцены, сек
@export var show_time := 4.0        # сколько секунд плашка висит
@export var slide_time := 0.5       # сколько секунд она выезжает и уезжает
@export var on_left := false        # false = справа внизу, true = слева внизу
@export var font_size := 22
@export var sound: AudioStream      # необязательно: звук появления («дзынь»)

var _panel: PanelContainer

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110               # поверх всего, в том числе виньетки
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(-5000.0, -5000.0)   # пока за экраном, чтобы не мелькнула
	layer.add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.95)
	style.border_color = Color(0.4, 0.62, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	_panel.add_child(label)

	await get_tree().create_timer(delay).timeout
	_show_popup()

func _show_popup() -> void:
	var vp := get_viewport().get_visible_rect().size
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size

	var margin := 24.0
	var y := vp.y - panel_size.y - margin
	var x_on := margin if on_left else vp.x - panel_size.x - margin    # на экране
	var x_off := -panel_size.x - margin if on_left else vp.x + margin  # за краем экрана
	_panel.position = Vector2(x_off, y)

	if sound:
		var player := AudioStreamPlayer.new()
		player.stream = sound
		add_child(player)
		player.play()

	var tween := create_tween()
	tween.tween_property(_panel, "position:x", x_on, slide_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(show_time)
	tween.tween_property(_panel, "position:x", x_off, slide_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_panel.queue_free)
