shader_type canvas_item;

void fragment() {
	vec2 uv = UV;

	vec4 tex = texture(TEXTURE, uv);

	float brilho = (tex.r + tex.g + tex.b) / 3.0;

	// Vermelho
	vec3 vermelho = vec3(brilho, 0.0, 0.0);

	// Scanlines
	float scanline = sin(uv.y * 400.0) * 0.15;

	vermelho += vec3(scanline, 0.0, 0.0);

	// Flicker
	float flicker = sin(TIME * 10.0) * 0.05;

	vermelho += vec3(flicker, 0.0, 0.0);

	COLOR = vec4(vermelho, tex.a);
}