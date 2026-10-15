shader_type canvas_item;

// Объявляем текстуру экрана
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Параметры для гибкой настройки прямо в инспекторе Godot
uniform float scanline_density : hint_range(100.0, 1500.0) = 2000.0; // Плотность полос
uniform float scanline_intensity : hint_range(0.0, 0.1) = 0.15;     // Яркость полос
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.003; // Разделение цветов (RGB)
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.08;        // Сила шума/статики
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;      // Сила виньетки
uniform float color_bleed : hint_range(0.0, 1.0) = 0.3;             // Растекание цвета
uniform float desaturation : hint_range(0.0, 1.0) = 0.2;            // Обесцвечивание

void fragment() {
    vec2 uv = SCREEN_UV;

    // 1. Хроматическая аберрация (имитация плохой головки VHS)
    float r = texture(screen_texture, uv + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - vec2(chromatic_aberration, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // 2. Цветовое растекание (Color Bleed) - цвета "плывут" вправо
    vec3 bleed = texture(screen_texture, uv + vec2(0.004, 0.0)).rgb;
    col = mix(col, bleed, color_bleed);

    // 3. Скэнлайны (Горизонтальные полосы от ЭЛТ-монитора/ТВ)
    float scanline = sin(uv.y * scanline_density) * 0.5 + 0.5;
    col -= scanline * scanline_intensity;

    // 4. Шум (Статика)
    // Используем TIME, чтобы шум постоянно "шевелился"
    float noise = fract(sin(dot(uv + vec2(TIME * 15.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
    col += (noise - 0.5) * noise_intensity;

    // 5. Виньетка (Затемнение по краям экрана)
    float dist = distance(uv, vec2(0.5));
    col *= smoothstep(0.8, 0.2, dist * vignette_intensity);

    // 6. Легкое обесцвечивание (выцветшие цвета старой кассеты)
    float gray = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(gray), desaturation);

	// Случайные горизонтальные сдвиги
	float glitch = step(0.98, fract(sin(TIME * 10.0) * 43758.5453)); // Срабатывает редко
	uv.x += glitch * 0.05 * sin(uv.y * 50.0 + TIME * 100.0);


    // Итоговый цвет
    COLOR = vec4(col, 1.0);
}
