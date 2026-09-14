shader_type canvas_item;

// Assistência cromática do mapa. Não é uma simulação de daltonismo.
// O shader preserva a imagem original e acrescenta uma pista redundante
// de matiz e luminosidade para os eixos que podem se confundir.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int modo = 0;
// A assistência é discreta por padrão para preservar a paleta original.
uniform float intensidade : hint_range(0.0, 1.0) = 0.60;
uniform float pista_luminancia : hint_range(0.0, 0.20) = 0.07;


float luminancia(vec3 cor) {
	return dot(cor, vec3(0.2126, 0.7152, 0.0722));
}


float croma(vec3 cor) {
	float maior = max(max(cor.r, cor.g), cor.b);
	float menor = min(min(cor.r, cor.g), cor.b);
	return maior - menor;
}


float sinal_oponente(float diferenca, float croma_value) {
	float peso_croma = smoothstep(0.08, 0.30, croma_value);
	// Cores no meio do eixo de confusão recebem a maior pista.
	// Tons muito afastados ainda recebem um reforço pequeno, sem trocar a paleta.
	float proximidade_eixo = 1.0 - smoothstep(0.10, 0.38, abs(diferenca));
	float peso_seletivo = mix(0.30, 1.0, proximidade_eixo);
	return clamp(diferenca * 2.0, -1.0, 1.0) * peso_croma * peso_seletivo;
}


vec3 preservar_luminancia(vec3 original, vec3 alterada) {
	float luma_original = luminancia(original);
	float luma_nova = luminancia(alterada);
	alterada += vec3(luma_original - luma_nova);
	return clamp(alterada, 0.0, 1.0);
}


vec3 cor_assistida(vec3 original) {
	if (modo == 0) {
		return original;
	}

	float croma_value = croma(original);
	// Cinzas, sombras, pisos e marrons pouco cromáticos permanecem intactos.
	if (croma_value < 0.08) {
		return original;
	}

	vec3 alterada = original;
	if (modo == 1 || modo == 2) {
		float rg = sinal_oponente(original.r - original.g, croma_value);
		float lado_vermelho = max(rg, 0.0);
		float lado_verde = max(-rg, 0.0);

		// Vermelhos ganham uma pista quente/amarelada.
		alterada += lado_vermelho * vec3(0.028, 0.14, -0.084);
		// Verdes ganham uma pista fria/ciano-azulada.
		alterada += lado_verde * vec3(-0.07, -0.035, 0.182);
		alterada = preservar_luminancia(original, alterada);

		float forca_luma = modo == 1 ? pista_luminancia : pista_luminancia * 0.55;
		alterada += vec3((lado_vermelho - lado_verde) * forca_luma);
	} else if (modo == 3) {
		float gb = sinal_oponente(original.g - original.b, croma_value);
		float lado_verde_amarelo = max(gb, 0.0);
		float lado_azul_roxo = max(-gb, 0.0);

		// Verde/amarelo recebe uma pista ciano.
		alterada += lado_verde_amarelo * vec3(-0.112, 0.021, 0.154);
		// Azul/roxo/rosa recebe uma pista quente/vermelha.
		alterada += lado_azul_roxo * vec3(0.154, -0.056, -0.028);
		alterada = preservar_luminancia(original, alterada);
		alterada += vec3((lado_verde_amarelo - lado_azul_roxo) * pista_luminancia);
	}

	return clamp(mix(original, alterada, intensidade), 0.0, 1.0);
}


void fragment() {
	vec4 original = textureLod(screen_texture, SCREEN_UV, 0.0);
	COLOR = vec4(cor_assistida(original.rgb), original.a);
}
