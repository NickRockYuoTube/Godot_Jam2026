extends Node3D
class_name Cutscene

@export_file("*.tscn") var next_level: String   # куда перейти после катсцены
@export var animation_name := "scene"           # имя анимации в AnimationPlayer
@export var fade_in_time := 1.0                 # проявление в начале, сек
@export var fade_out_time := 1.0                # затемнение в конце, сек
@export var hold_black_time := 0.8              # пауза в темноте перед переходом, сек
@export var allow_skip := true                  # Enter, пробел или ESC пропускают катсцену
@export var impact_sound: AudioStreamPlayer     # звук удара (необязательно)
@export var shake_strength := 0.12              # сила тряски при ударе
@export var shake_time := 0.7                   # длительность тряски, сек

@export_group("Покачивание при ходьбе")
@export var head_bob := true
@export var bob_strength := 0.02
@export var bob_speed := 7.0                    # шагов в секунду * 2π, больше = чаще
@export var bob_stop_time := 8.3                # на какой секунде герой останавливается (0 = не качать)

var _anim: AnimationPlayer
var _camera: Camera3D
var _fade_layer: CanvasLayer
var _flash: ColorRect
var _fade: ColorRect
var _finishing := false
var _shake_left := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_camera = find_child("Camera3D", true, false) as Camera3D
	if _camera:
		_camera.current = true

	_create_overlay()

	if _anim == null or not _anim.has_animation(animation_name):
		push_warning("Cutscene: не найдена анимация '%s' в AnimationPlayer" % animation_name)
		return

	_anim.animation_finished.connect(func(_name: StringName) -> void: finish())

	# Проявление из черного, потом запуск шкалы
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, fade_in_time)
	_anim.play(animation_name)

func _process(delta: float) -> void:
	if _camera == null:
		return
	var h := 0.0
	var v := 0.0

	# Покачивание при ходьбе, плавно затухает перед остановкой героя
	if head_bob and _anim and _anim.is_playing() and bob_stop_time > 0.0:
		var t := _anim.current_animation_position
		if t < bob_stop_time:
			var k := clampf((bob_stop_time - t) / 0.5, 0.0, 1.0)
			v += sin(t * bob_speed) * bob_strength * k
			h += sin(t * bob_speed * 0.5) * bob_strength * 0.5 * k

	# Тряска при ударе
	if _shake_left > 0.0:
		_shake_left -= delta
		var s := clampf(_shake_left / maxf(shake_time, 0.001), 0.0, 1.0)
		h += randf_range(-1.0, 1.0) * shake_strength * s
		v += randf_range(-1.0, 1.0) * shake_strength * s

	_camera.h_offset = h
	_camera.v_offset = v

func _unhandled_input(event: InputEvent) -> void:
	if allow_skip and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		finish()

# Вызывается из анимации (Call Method Track) в момент столкновения
func impact() -> void:
	if impact_sound:
		impact_sound.play()
	_shake_left = shake_time
	if _flash:
		_flash.color = Color(1.0, 1.0, 1.0, 0.9)   # короткая белая вспышка
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)

# Затемнение и переход на следующий уровень
func finish() -> void:
	if _finishing:
		return
	_finishing = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, fade_out_time)
	await t.finished
	await get_tree().create_timer(hold_black_time).timeout

	if next_level.is_empty() or not ResourceLoader.exists(next_level):
		push_warning("Cutscene: не выбран следующий уровень (поле Next Level)")
		return
	get_tree().change_scene_to_file(next_level)

func _create_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 90
	add_child(_fade_layer)

	_flash = ColorRect.new()
	_fade_layer.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)

	_fade = ColorRect.new()
	_fade_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)   # старт с черного экрана
