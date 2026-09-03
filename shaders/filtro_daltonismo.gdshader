shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform int modo = 0;
// 0 = desligado
// 1 = auxílio protanopia
// 2 = auxílio deuteranopia
// 3 = auxílio tritanopia

uniform float intensidade : hint_range(0.0, 1.0) = 1.0;
uniform float forca_correcao : hint_range(0.0, 2.0) = 1.35;

uniform float saturacao_extra : hint_range(0.0, 1.0) = 0.08;
uniform float contraste_extra : hint_range(0.0, 1.0) = 0.10;

uniform float realce_bordas : hint_range(0.0, 1.0) = 0.10;
uniform float largura_borda : hint_range(1.0, 4.0) = 1.0;

uniform bool preservar_luminancia = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float luminancia(vec3 cor) {
	return dot(cor, LUMA);
}

vec3 rgb_para_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 0.000001;

	return vec3(
		abs(q.z + (q.w - q.y) / (6.0 * d + e)),
		d / (q.x + e),
		q.x
	);
}

vec3 hsv_para_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float distancia_hue(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}

float mascara_hue(float hue, float centro, float largura, float suavidade) {
	float d = distancia_hue(hue, centro);
	return 1.0 - smoothstep(largura, largura + suavidade, d);
}

vec3 preservar_luma_original(vec3 original, vec3 alterada) {
	float lo = luminancia(original);
	float la = max(luminancia(alterada), 0.001);
	alterada *= lo / la;
	return clamp(alterada, 0.0, 1.0);
}

vec3 aumentar_contraste(vec3 cor, float valor) {
	return clamp((cor - 0.5) * (1.0 + valor) + 0.5, 0.0, 1.0);
}

vec3 aumentar_saturacao(vec3 cor, float valor) {
	float luma = luminancia(cor);
	return clamp(mix(vec3(luma), cor, 1.0 + valor), 0.0, 1.0);
}

float fator_cor_util(vec3 hsv) {
	float sat = smoothstep(0.05, 0.25, hsv.y);
	float val = smoothstep(0.05, 0.20, hsv.z);
	return sat * val;
}

vec3 aplicar_alvo_hsv(
	vec3 cor_original,
	float hue_alvo,
	float sat_min,
	float ajuste_valor,
	float mascara
) {
	vec3 hsv = rgb_para_hsv(cor_original);

	vec3 hsv_alvo = hsv;
	hsv_alvo.x = hue_alvo;
	hsv_alvo.y = max(hsv.y, sat_min);
	hsv_alvo.z = clamp(hsv.z + ajuste_valor, 0.0, 1.0);

	vec3 cor_alvo = hsv_para_rgb(hsv_alvo);

	if (preservar_luminancia) {
		cor_alvo = preservar_luma_original(cor_original, cor_alvo);
	}

	float forca = clamp(mascara * forca_correcao, 0.0, 1.0);
	return mix(cor_original, cor_alvo, forca);
}

/* =========================
   PROTANOPIA
   =========================
   vermelho/rosa/laranja -> azul/roxo
   verde -> amarelo
   amarelo-esverdeado -> ciano
*/
vec3 corrigir_protanopia(vec3 cor) {
	vec3 hsv = rgb_para_hsv(cor);
	float h = hsv.x;
	float fator = fator_cor_util(hsv);

	float vermelho_1 = mascara_hue(h, 0.00, 0.05, 0.05);
	float vermelho_2 = mascara_hue(h, 0.98, 0.05, 0.05);
	float rosa = mascara_hue(h, 0.90, 0.08, 0.06);
	float laranja = mascara_hue(h, 0.08, 0.07, 0.05);

	float verde = mascara_hue(h, 0.33, 0.11, 0.07);
	float verde_amarelo = mascara_hue(h, 0.23, 0.07, 0.05);
	float amarelo = mascara_hue(h, 0.15, 0.06, 0.05);

	float mask_vermelhos = max(max(vermelho_1, vermelho_2), max(rosa, laranja)) * fator;
	float mask_verdes = verde * fator;
	float mask_verde_amarelo = verde_amarelo * fator;
	float mask_amarelo = amarelo * fator * 0.50;

	vec3 corrigida = cor;

	// vermelho/rosa -> azul-violeta
	corrigida = aplicar_alvo_hsv(corrigida, 0.72, 0.75, 0.04, mask_vermelhos);

	// verde -> amarelo forte
	corrigida = aplicar_alvo_hsv(corrigida, 0.15, 0.75, 0.10, mask_verdes);

	// verde-amarelado -> ciano
	corrigida = aplicar_alvo_hsv(corrigida, 0.50, 0.70, 0.05, mask_verde_amarelo);

	// amarelos podem ganhar leve puxada para dourado claro
	corrigida = aplicar_alvo_hsv(corrigida, 0.13, 0.65, 0.06, mask_amarelo);

	return clamp(corrigida, 0.0, 1.0);
}

/* =========================
   DEUTERANOPIA
   =========================
   vermelho/rosa -> azul/magenta
   verde -> ciano
   amarelo-esverdeado -> laranja/amarelo
*/
vec3 corrigir_deuteranopia(vec3 cor) {
	vec3 hsv = rgb_para_hsv(cor);
	float h = hsv.x;
	float fator = fator_cor_util(hsv);

	float vermelho_1 = mascara_hue(h, 0.00, 0.05, 0.05);
	float vermelho_2 = mascara_hue(h, 0.98, 0.05, 0.05);
	float rosa = mascara_hue(h, 0.90, 0.08, 0.06);
	float laranja = mascara_hue(h, 0.08, 0.07, 0.05);

	float verde = mascara_hue(h, 0.33, 0.12, 0.08);
	float verde_amarelo = mascara_hue(h, 0.23, 0.08, 0.06);
	float amarelo = mascara_hue(h, 0.15, 0.06, 0.05);

	float mask_vermelhos = max(max(vermelho_1, vermelho_2), max(rosa, laranja * 0.8)) * fator;
	float mask_verdes = verde * fator;
	float mask_verde_amarelo = verde_amarelo * fator;
	float mask_amarelo = amarelo * fator * 0.45;

	vec3 corrigida = cor;

	// vermelho/rosa -> magenta-azulado
	corrigida = aplicar_alvo_hsv(corrigida, 0.78, 0.76, 0.03, mask_vermelhos);

	// verde -> ciano
	corrigida = aplicar_alvo_hsv(corrigida, 0.50, 0.74, 0.06, mask_verdes);

	// verde-amarelo -> laranja/amarelo
	corrigida = aplicar_alvo_hsv(corrigida, 0.10, 0.74, 0.08, mask_verde_amarelo);

	// amarelos continuam amarelos, mas mais brilhantes
	corrigida = aplicar_alvo_hsv(corrigida, 0.14, 0.65, 0.08, mask_amarelo);

	return clamp(corrigida, 0.0, 1.0);
}

/* =========================
   TRITANOPIA
   =========================
   azul/ciano -> magenta/roxo
   amarelo -> verde
*/
vec3 corrigir_tritanopia(vec3 cor) {
	vec3 hsv = rgb_para_hsv(cor);
	float h = hsv.x;
	float fator = fator_cor_util(hsv);

	float azul = mascara_hue(h, 0.62, 0.11, 0.08);
	float ciano = mascara_hue(h, 0.50, 0.10, 0.07);
	float azul_roxo = mascara_hue(h, 0.72, 0.08, 0.06);

	float amarelo = mascara_hue(h, 0.15, 0.08, 0.06);
	float laranja = mascara_hue(h, 0.08, 0.07, 0.05);
	float verde_amarelo = mascara_hue(h, 0.23, 0.08, 0.06);

	float mask_azuis = max(max(azul, ciano), azul_roxo) * fator;
	float mask_amarelos = max(max(amarelo, laranja * 0.6), verde_amarelo) * fator;

	vec3 corrigida = cor;

	// azul/ciano -> roxo/magenta
	corrigida = aplicar_alvo_hsv(corrigida, 0.84, 0.74, 0.04, mask_azuis);

	// amarelo -> verde
	corrigida = aplicar_alvo_hsv(corrigida, 0.34, 0.72, 0.06, mask_amarelos);

	return clamp(corrigida, 0.0, 1.0);
}

vec3 aplicar_correcao(vec3 cor, int tipo) {
	vec3 corrigida = cor;

	if (tipo == 1) {
		corrigida = corrigir_protanopia(cor);
	} else if (tipo == 2) {
		corrigida = corrigir_deuteranopia(cor);
	} else if (tipo == 3) {
		corrigida = corrigir_tritanopia(cor);
	}

	corrigida = aumentar_saturacao(corrigida, saturacao_extra);
	corrigida = aumentar_contraste(corrigida, contraste_extra);

	return clamp(corrigida, 0.0, 1.0);
}

float perfil_cor(vec3 cor, int tipo) {
	vec3 hsv = rgb_para_hsv(cor);
	float h = hsv.x;
	float fator = fator_cor_util(hsv);

	if (tipo == 1 || tipo == 2) {
		float vermelhos = max(
			max(mascara_hue(h, 0.00, 0.05, 0.05), mascara_hue(h, 0.98, 0.05, 0.05)),
			max(mascara_hue(h, 0.90, 0.08, 0.06), mascara_hue(h, 0.08, 0.07, 0.05))
		);

		float verdes = max(
			mascara_hue(h, 0.33, 0.12, 0.08),
			mascara_hue(h, 0.23, 0.08, 0.06)
		);

		return (vermelhos - verdes) * fator;
	}

	if (tipo == 3) {
		float azuis = max(
			mascara_hue(h, 0.62, 0.11, 0.08),
			mascara_hue(h, 0.50, 0.10, 0.07)
		);

		float amarelos = max(
			mascara_hue(h, 0.15, 0.08, 0.06),
			mascara_hue(h, 0.23, 0.08, 0.06)
		);

		return (azuis - amarelos) * fator;
	}

	return 0.0;
}

float calcular_borda(vec2 uv, int tipo) {
	ivec2 tam = textureSize(screen_texture, 0);
	vec2 pixel = vec2(largura_borda) / vec2(tam);

	vec3 centro = texture(screen_texture, uv).rgb;
	vec3 direita = texture(screen_texture, uv + vec2(pixel.x, 0.0)).rgb;
	vec3 esquerda = texture(screen_texture, uv - vec2(pixel.x, 0.0)).rgb;
	vec3 cima = texture(screen_texture, uv + vec2(0.0, pixel.y)).rgb;
	vec3 baixo = texture(screen_texture, uv - vec2(0.0, pixel.y)).rgb;

	float p = perfil_cor(centro, tipo);

	float borda = 0.0;
	borda += abs(p - perfil_cor(direita, tipo));
	borda += abs(p - perfil_cor(esquerda, tipo));
	borda += abs(p - perfil_cor(cima, tipo));
	borda += abs(p - perfil_cor(baixo, tipo));

	return clamp(borda * 2.5, 0.0, 1.0);
}

vec3 aplicar_borda(vec3 cor, float borda, float forca) {
	float luma = luminancia(cor);
	vec3 alvo = (luma > 0.5) ? vec3(0.0) : vec3(1.0);
	return mix(cor, alvo, borda * forca);
}

void fragment() {
	vec4 cor_tela = texture(screen_texture, SCREEN_UV);
	vec3 cor_original = cor_tela.rgb;
	vec3 cor_final = cor_original;

	if (modo != 0) {
		vec3 cor_corrigida = aplicar_correcao(cor_original, modo);

		if (realce_bordas > 0.0) {
			float borda = calcular_borda(SCREEN_UV, modo);
			cor_corrigida = aplicar_borda(cor_corrigida, borda, realce_bordas);
		}

		cor_final = mix(cor_original, cor_corrigida, intensidade);
	}

	COLOR = vec4(cor_final, cor_tela.a);
}