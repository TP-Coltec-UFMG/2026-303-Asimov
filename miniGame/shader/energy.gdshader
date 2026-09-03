shader_type canvas_item;

uniform vec4 electric_color : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 1.0;
uniform float speed : hint_range(0.0, 10.0) = 13.0;
uniform float thickness : hint_range(0.001, 0.2) = 0.04;
uniform float distortion : hint_range(0.0, 0.5) = 0.12;

float random(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(random(i), random(i + vec2(1.0, 0.0)), f.x),
		mix(random(i + vec2(0.0, 1.0)), random(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	// IMPORTANTE:
	// COLOR já contém a textura + modulate do Sprite2D
	vec4 tex = texture(TEXTURE, UV);
	vec4 base_color = COLOR;

	vec2 uv = UV;
	float time = TIME * speed;

	// Distorção irregular
	float n1 = noise(vec2(uv.y * 12.0, time * 0.8));
	float n2 = noise(vec2(uv.y * 25.0, time * 1.3));

	uv.x += (n1 - 0.5) * distortion;
	uv.x += sin(uv.y * 40.0 + time * 3.0) * 0.015;

	// Linhas elétricas
	float electric = 0.0;

	float line1 = abs(fract(uv.x * 8.0 + time * 0.7) - 0.5);
	float line2 = abs(fract(uv.x * 17.0 - time * 1.1) - 0.5);

	electric += smoothstep(thickness, 0.0, line1);
	electric += smoothstep(thickness * 0.6, 0.0, line2) * 0.6;

	// Ruído
	electric *= mix(0.4, 1.0, n2);

	// Adiciona eletricidade à cor já modificada
	base_color.rgb += electric_color.rgb * electric * intensity;

	COLOR = base_color;
}