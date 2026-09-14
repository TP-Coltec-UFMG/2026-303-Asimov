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

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float chroma(vec3 color) {
	float highest = max(max(color.r, color.g), color.b);
	float lowest = min(min(color.r, color.g), color.b);
	return highest - lowest;
}

float opponent_signal(float difference, float chroma_value) {
	float chroma_weight = smoothstep(0.08, 0.30, chroma_value);
	float axis_proximity = 1.0 - smoothstep(0.10, 0.38, abs(difference));
	float selective_weight = mix(0.30, 1.0, axis_proximity);
	return clamp(difference * 2.0, -1.0, 1.0) * chroma_weight * selective_weight;
}

vec3 preserve_luminance(vec3 original, vec3 altered) {
	altered += vec3(luminance(original) - luminance(altered));
	return clamp(altered, 0.0, 1.0);
}

vec3 assist_color(vec3 original) {
	// A assistência cria uma segunda pista de matiz/luminosidade; não simula visão.
	float chroma_value = chroma(original);
	if (chroma_value < 0.08 || modo == 0) {
		return original;
	}

	vec3 altered = original;
	if (modo == 1 || modo == 2) {
		float rg = opponent_signal(original.r - original.g, chroma_value);
		float red_side = max(rg, 0.0);
		float green_side = max(-rg, 0.0);

		// Vermelhos recebem uma pista quente; verdes, uma pista fria.
		altered += red_side * vec3(0.028, 0.14, -0.084);
		altered += green_side * vec3(-0.07, -0.035, 0.182);
		altered = preserve_luminance(original, altered);

		float luminance_hint = modo == 1 ? 0.07 : 0.039;
		altered += vec3((red_side - green_side) * luminance_hint);
	} else if (modo == 3) {
		float gb = opponent_signal(original.g - original.b, chroma_value);
		float green_yellow_side = max(gb, 0.0);
		float blue_purple_side = max(-gb, 0.0);

		altered += green_yellow_side * vec3(-0.112, 0.021, 0.154);
		altered += blue_purple_side * vec3(0.154, -0.056, -0.028);
		altered = preserve_luminance(original, altered);
		altered += vec3((green_yellow_side - blue_purple_side) * 0.07);
	}

	return clamp(altered, 0.0, 1.0);
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
	vec4 overlay = vec4(assist_color(source.rgb), center * 0.30);
	// Linha clara fina e apoio escuro por dentro: informação de forma, não só cor.
	if (outside_edge > 0.01) {
		overlay = vec4(0.86, 0.85, 0.77, outside_edge * 0.8);
	} else if (inside_edge > 0.01) {
		overlay = vec4(mix(assist_color(source.rgb), vec3(0.06, 0.065, 0.07), 0.3), center * 0.45);
	}
	COLOR = modo == 0 ? vec4(0.0) : overlay * item_color;
}
