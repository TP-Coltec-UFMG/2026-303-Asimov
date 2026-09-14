shader_type canvas_item;
render_mode unshaded;

// Assistência: acrescenta pistas de matiz e brilho à imagem normal.
// Não representa nem simula a visão de uma pessoa com daltonismo.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int modo = 0;
uniform float intensidade : hint_range(0.0, 1.0) = 0.60;
uniform float pista_luminancia : hint_range(0.0, 0.20) = 0.07;

float faixa_matiz(float matiz, float centro, float largura) {
	float distancia = abs(matiz - centro);
	distancia = min(distancia, 1.0 - distancia);
	return 1.0 - smoothstep(largura * 0.4, largura, distancia);
}

vec3 cor_assistida(vec3 original) {
	if (modo < 1 || modo > 3 || intensidade <= 0.0) {
		return original;
	}
	float maior = max(max(original.r, original.g), original.b);
	float menor = min(min(original.r, original.g), original.b);
	float croma = maior - menor;
	if (croma <= 0.08) {
		return original;
	}
	float matiz = 0.0;
	if (maior == original.r) {
		matiz = (original.g - original.b) / croma;
	} else if (maior == original.g) {
		matiz = 2.0 + (original.b - original.r) / croma;
	} else {
		matiz = 4.0 + (original.r - original.g) / croma;
	}
	matiz = fract(matiz / 6.0 + 1.0);
	// Transições suaves; não há um degrau visível em gradientes de iluminação.
	float peso = smoothstep(0.08, 0.28, croma)
		* smoothstep(0.25, 0.65, croma / max(maior, 0.001))
		* smoothstep(0.08, 0.30, maior);
	// Preserva a família laranja/marrom usada no piso, madeira e luz do fogo.
	peso *= 1.0 - faixa_matiz(matiz, 0.085, 0.055);
	float vermelho = faixa_matiz(matiz, 0.0, 0.075);
	float verde = faixa_matiz(matiz, 0.33, 0.13);
	float azul = faixa_matiz(matiz, 0.63, 0.10);
	float roxo = faixa_matiz(matiz, 0.79, 0.075);
	float amarelo = faixa_matiz(matiz, 0.167, 0.045);
	vec3 deslocamento = vec3(0.0);
	float brilho = 0.0;
	if (modo == 1) {
		// Protan: reforça o brilho do vermelho e separa verde por azul.
		deslocamento = vermelho * vec3(0.04, 0.12, -0.04)
			+ verde * vec3(-0.04, 0.0, 0.20)
			+ roxo * vec3(0.10, 0.0, -0.04);
		brilho = vermelho - verde * 0.25 + roxo * 0.25;
	} else if (modo == 2) {
		// Deutan: pista azul mais forte nos verdes; vermelho levemente quente.
		deslocamento = vermelho * vec3(0.04, 0.08, -0.04)
			+ verde * vec3(-0.06, -0.02, 0.24)
			+ roxo * vec3(0.12, 0.0, -0.04);
		brilho = vermelho * 0.25 + verde * 0.60 + roxo * 0.25;
	} else {
		// Tritan: pistas no eixo vermelho e no brilho, sem tingir o mapa de rosa.
		deslocamento = azul * vec3(0.16, -0.02, 0.0)
			+ verde * vec3(-0.08, 0.04, 0.0)
			+ amarelo * vec3(0.04, -0.10, -0.02);
		brilho = verde * 0.45 - azul * 0.35 + amarelo * 0.30;
	}
	// Limita a alteração por canal mesmo que a intensidade seja aumentada.
	float luma_delta = dot(deslocamento, vec3(0.2126, 0.7152, 0.0722));
	vec3 delta = deslocamento - vec3(luma_delta) + vec3(brilho * pista_luminancia);
	delta = clamp(delta, vec3(-0.20), vec3(0.20));
	return clamp(original + delta * peso * clamp(intensidade, 0.0, 1.0), 0.0, 1.0);
}

void fragment() {
	vec4 original = textureLod(screen_texture, SCREEN_UV, 0.0);
	COLOR = vec4(cor_assistida(original.rgb), original.a);
}
