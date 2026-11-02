extends Node
class_name FlashbackEffect

const SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fisheye = 0.3;        // сила рыбьего глаза
uniform float saturation = 0.0;     // 0 = серый, 1 = цветной
uniform vec3 tint : source_color = vec3(0.93, 0.96, 1.0);   // легкий холодный оттенок
uniform float vignette = 0.5;       // затемнение по краям
uniform float grain = 0.03;         // зернистость
uniform float aberration = 0.0015;  // цветная кайма по краям линзы

void fragment() {
	// Рыбий глаз с поправкой на пропорции экрана
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = SCREEN_UV - 0.5;
	vec2 p = uv * vec2(aspect, 1.0);
	float r2 = dot(p, p);
	float k = fisheye * 0.8;
	float max_r2 = 0.25 * (aspect * aspect + 1.0);
	// Делим на значение в углу, чтобы по краям не появлялась чернота
	vec2 d = uv * (1.0 + k * r2) / (1.0 + k * max_r2);
	vec2 suv = d + 0.5;

	// Цветная кайма: каналы чуть смещены от центра
	vec2 dir = normalize(d + vec2(0.0001)) * aberration * r2 * 4.0;
	vec3 col;
	col.r = texture(screen_tex, suv + dir).r;
	col.g = texture(screen_tex, suv).g;
	col.b = texture(screen_tex, suv - dir).b;

	// Серые тона
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(g), col, saturation) * tint;

	// Виньетка и зерно
	col *= 1.0 - smoothstep(0.25, 0.8, length(p)) * vignette;
	float n = fract(sin(dot(SCREEN_UV * vec2(1920.0, 1080.0) + TIME * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
"""

@export_range(0.0, 1.0, 0.01) var fisheye := 0.3:
	set(value):
		fisheye = value
		_apply()
@export_range(0.0, 1.0, 0.01) var saturation := 0.0:
	set(value):
		saturation = value
		_apply()
@export var tint := Color(0.93, 0.96, 1.0):
	set(value):
		tint = value
		_apply()
@export_range(0.0, 1.0, 0.01) var vignette := 0.5:
	set(value):
		vignette = value
		_apply()
@export_range(0.0, 0.3, 0.005) var grain := 0.03:
	set(value):
		grain = value
		_apply()
@export_range(0.0, 0.01, 0.0005) var aberration := 0.0015:
	set(value):
		aberration = value
		_apply()
@export var effect_layer := 50    # поверх 3D-картинки, но под затемнением катсцены (90)

var _material: ShaderMaterial

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = effect_layer
	add_child(layer)

	var rect := ColorRect.new()
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	rect.material = _material
	_apply()

func _apply() -> void:
	if _material == null:
		return   # сеттер сработал при загрузке сцены, до _ready()
	_material.set_shader_parameter("fisheye", fisheye)
	_material.set_shader_parameter("saturation", saturation)
	_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("vignette", vignette)
	_material.set_shader_parameter("grain", grain)
	_material.set_shader_parameter("aberration", aberration)
