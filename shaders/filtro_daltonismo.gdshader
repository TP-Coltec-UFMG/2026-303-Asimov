shader_type canvas_item;
render_mode unshaded;

// Apenas contorno. O interior mantém a arte original, sem recoloração dupla.
uniform int modo = 0;
uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 outline_uv = vec2(0.01);
varying vec4 item_color;

void vertex() {
	item_color = COLOR;
}

float alpha_at(vec2 uv) {
	vec2 texel_size = 1.0 / vec2(textureSize(sprite_texture, 0));
	vec2 inside = step(frame_uv.xy, uv) * step(uv, frame_uv.zw);
	vec2 safe_uv = clamp(uv, frame_uv.xy + texel_size * 0.5,
		frame_uv.zw - texel_size * 0.5);
	return texture(sprite_texture, safe_uv).a * inside.x * inside.y;
}

void fragment() {
	float center = alpha_at(UV);
	float right = alpha_at(UV + vec2(outline_uv.x, 0.0));
	float left = alpha_at(UV - vec2(outline_uv.x, 0.0));
	float top = alpha_at(UV - vec2(0.0, outline_uv.y));
	float bottom = alpha_at(UV + vec2(0.0, outline_uv.y));
	float outside_edge = (1.0 - center) * max(max(right, left), max(top, bottom));
	float inside_edge = center * (1.0 - min(min(right, left), min(top, bottom)));
	// Borda clara no fundo escuro, apoio escuro no fundo claro.
	// Só o contorno é unshaded; não ilumina a textura nem revela nós ocultos.
	vec4 overlay = vec4(0.0);
	if (outside_edge > 0.01) {
		overlay = vec4(vec3(0.94), outside_edge * 0.90);
	} else if (inside_edge > 0.01) {
		overlay = vec4(vec3(0.035), inside_edge * 0.65);
	}
	// Tinturas de dano/interação não devem mudar a cor do contorno.
	// A transparência continua acompanhando os fades do personagem/objeto.
	COLOR = modo == 0 ? vec4(0.0) : vec4(overlay.rgb, overlay.a * item_color.a);
}
