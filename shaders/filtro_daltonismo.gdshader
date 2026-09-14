shader_type canvas_item;

// Sobreposição local da silhueta. Nunca lê a tela ou transforma o cenário.
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

vec3 assist_color(vec3 original) {
	// Pequena separação de tons próximos, mantendo a luminância da arte.
	// Sem matrizes de deficiência visual, redução de canais ou troca de paleta.
	float red = max(original.r - max(original.g, original.b), 0.0);
	float green = max(original.g - max(original.r, original.b), 0.0);
	float blue = max(original.b - max(original.r, original.g), 0.0);
	vec3 delta = vec3(0.0);
	if (modo == 1) {
		delta = red * vec3(0.04, 0.01, -0.02) + green * vec3(-0.01, 0.01, 0.04);
	} else if (modo == 2) {
		delta = red * vec3(0.025, 0.005, -0.02) + green * vec3(-0.02, 0.005, 0.05);
	} else if (modo == 3) {
		delta = blue * vec3(0.04, -0.005, 0.01) + green * vec3(-0.015, 0.015, -0.015);
	}
	delta -= vec3(dot(delta, vec3(0.2126, 0.7152, 0.0722)));
	return clamp(original + delta, 0.0, 1.0);
}

void fragment() {
	vec2 texel_size = 1.0 / vec2(textureSize(sprite_texture, 0));
	vec2 safe_uv = clamp(UV, frame_uv.xy + texel_size * 0.5,
		frame_uv.zw - texel_size * 0.5);
	vec4 source = texture(sprite_texture, safe_uv);
	float center = alpha_at(UV);
	float right = alpha_at(UV + vec2(outline_uv.x, 0.0));
	float left = alpha_at(UV - vec2(outline_uv.x, 0.0));
	float top = alpha_at(UV - vec2(0.0, outline_uv.y));
	float bottom = alpha_at(UV + vec2(0.0, outline_uv.y));
	float outside_edge = (1.0 - center) * max(max(right, left), max(top, bottom));
	float inside_edge = center * (1.0 - min(min(right, left), min(top, bottom)));
	vec4 overlay = vec4(assist_color(source.rgb), center * 0.18);
	// Linha clara fina e apoio escuro por dentro: informação de forma, não só cor.
	if (outside_edge > 0.01) {
		overlay = vec4(0.86, 0.85, 0.77, outside_edge * 0.8);
	} else if (inside_edge > 0.01) {
		overlay = vec4(mix(assist_color(source.rgb), vec3(0.06, 0.065, 0.07), 0.3), center * 0.35);
	}
	COLOR = modo == 0 ? vec4(0.0) : overlay * item_color;
}
