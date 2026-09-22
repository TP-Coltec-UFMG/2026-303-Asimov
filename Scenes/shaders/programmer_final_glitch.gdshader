shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

float random_line(float line, float seed) {
	return fract(sin(line * 91.731 + seed * 37.719) * 43758.5453);
}

void fragment() {
	float overlay_alpha = COLOR.a;
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 24.0);
	float line = floor(uv.y * 72.0);
	float noise = random_line(line, tick);
	float active_band = step(0.76, noise);
	float displacement = (noise - 0.5) * 0.038 * active_band;
	vec2 shifted_uv = clamp(uv + vec2(displacement, 0.0), vec2(0.0), vec2(1.0));
	vec4 base = texture(screen_texture, shifted_uv);
	float split = 0.006 * active_band;
	float red = texture(screen_texture, clamp(shifted_uv + vec2(split, 0.0), vec2(0.0), vec2(1.0))).r;
	float blue = texture(screen_texture, clamp(shifted_uv - vec2(split, 0.0), vec2(0.0), vec2(1.0))).b;
	float scanline = step(0.86, fract(uv.y * 115.0 + TIME * 5.0));
	vec3 recalculated = vec3(red, base.g, blue);
	recalculated += vec3(0.06, 0.72, 0.22) * (active_band * 0.28 + scanline * 0.12);
	COLOR = vec4(recalculated, 0.94 * overlay_alpha);
}
