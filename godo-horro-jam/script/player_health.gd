extends Node
# Autoload: PlayerHealth. Здоровье игрока и красная виньетка.

signal health_changed(hp: int, max_hp: int)
signal damaged(hp: int)
signal died

const MAX_HP := 2
const INVULNERABLE_TIME := 1.5   # после удара игрока нельзя ударить повторно, сек
const RESTART_DELAY := 2.5       # через сколько секунд после смерти перезапуск уровня
const VIGNETTE_STEADY := 0.55    # постоянная сила виньетки при низком HP
const VIGNETTE_PULSE := 0.12     # амплитуда «пульса» виньетки

const SHADER_CODE := """
shader_type canvas_item;
uniform vec3 tint : source_color = vec3(0.65, 0.0, 0.0);
uniform float intensity = 0.0;
uniform float blackout = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.35, 1.25, d);
	float a = clamp(edge * intensity, 0.0, 1.0);
	vec3 col = mix(tint, vec3(0.0), blackout);
	COLOR = vec4(col, max(a, blackout));
}
"""

var hp := MAX_HP
var is_dead := false

var _invulnerable_left := 0.0
var _flash := 0.0        # короткая вспышка в момент удара
var _blackout := 0.0     # затемнение при смерти
var _time := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100                       # поверх всего интерфейса
	add_child(layer)

	var rect := ColorRect.new()
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # не мешает мыши

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	rect.material = _material
	_update_vignette()

func _process(delta: float) -> void:
	_time += delta
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_flash = maxf(0.0, _flash - delta * 1.2)
	_update_vignette()

func _update_vignette() -> void:
	var base := 0.0
	if hp < MAX_HP and not is_dead:
		base = VIGNETTE_STEADY + sin(_time * 3.0) * VIGNETTE_PULSE
	_material.set_shader_parameter("intensity", clampf(base + _flash, 0.0, 1.0))
	_material.set_shader_parameter("blackout", _blackout)

func take_damage(amount: int = 1) -> void:
	if is_dead or _invulnerable_left > 0.0:
		return
	hp = maxi(0, hp - amount)
	_invulnerable_left = INVULNERABLE_TIME
	_flash = 1.0
	health_changed.emit(hp, MAX_HP)
	damaged.emit(hp)
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit()
	create_tween().tween_property(self, "_blackout", 1.0, 1.2)   # затемнение
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()   # перезапуск уровня
	reset()
	PowerSystem.reset()

func reset() -> void:
	hp = MAX_HP
	is_dead = false
	_flash = 0.0
	_blackout = 0.0
	_invulnerable_left = 0.0
	health_changed.emit(hp, MAX_HP)
