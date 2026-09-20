shader_type canvas_item;

uniform vec4 cor_viva : source_color = vec4(1.0, 0.95, 0.25, 1.0);
uniform vec4 cor_viva_2 : source_color = vec4(1.0, 0.82, 0.10, 1.0);
uniform vec4 cor_dourada : source_color = vec4(1.0, 0.65, 0.05, 1.0);
uniform vec4 cor_dourada_2 : source_color = vec4(0.90, 0.45, 0.02, 1.0);
uniform vec4 cor_escura : source_color = vec4(0.60, 0.22, 0.0, 1.0);

uniform float tamanho_aura : hint_range(1.0, 15.0) = 7.0;
uniform float intensidade : hint_range(0.0, 5.0) = 1.5;


void fragment() {

    vec4 original = texture(TEXTURE, UV);

    vec2 pixel = TEXTURE_PIXEL_SIZE;

    float fora = 1.0 - original.a;


    // =====================================================
    // CAMADA 1 — LUZ MUITO VIVA
    // =====================================================

    float camada1 = 0.0;

    camada1 += texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a;
    camada1 += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a;
    camada1 += texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a;
    camada1 += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a;

    camada1 += texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a;
    camada1 += texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a;
    camada1 += texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a;
    camada1 += texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a;

    camada1 /= 8.0;


    // =====================================================
    // CAMADA 2 — AINDA MUITO VIVA
    // =====================================================

    float camada2 = 0.0;

    camada2 += texture(TEXTURE, UV + vec2(-pixel.x * 2.0, 0.0)).a;
    camada2 += texture(TEXTURE, UV + vec2(pixel.x * 2.0, 0.0)).a;
    camada2 += texture(TEXTURE, UV + vec2(0.0, -pixel.y * 2.0)).a;
    camada2 += texture(TEXTURE, UV + vec2(0.0, pixel.y * 2.0)).a;

    camada2 += texture(TEXTURE, UV + vec2(-pixel.x * 1.5, -pixel.y * 1.5)).a;
    camada2 += texture(TEXTURE, UV + vec2(pixel.x * 1.5, -pixel.y * 1.5)).a;
    camada2 += texture(TEXTURE, UV + vec2(-pixel.x * 1.5, pixel.y * 1.5)).a;
    camada2 += texture(TEXTURE, UV + vec2(pixel.x * 1.5, pixel.y * 1.5)).a;

    camada2 /= 8.0;


    // =====================================================
    // CAMADA 3 — DOURADO VIVO
    // =====================================================

    float camada3 = 0.0;

    camada3 += texture(TEXTURE, UV + vec2(-pixel.x * 3.0, 0.0)).a;
    camada3 += texture(TEXTURE, UV + vec2(pixel.x * 3.0, 0.0)).a;
    camada3 += texture(TEXTURE, UV + vec2(0.0, -pixel.y * 3.0)).a;
    camada3 += texture(TEXTURE, UV + vec2(0.0, pixel.y * 3.0)).a;

    camada3 += texture(TEXTURE, UV + vec2(-pixel.x * 2.2, -pixel.y * 2.2)).a;
    camada3 += texture(TEXTURE, UV + vec2(pixel.x * 2.2, -pixel.y * 2.2)).a;
    camada3 += texture(TEXTURE, UV + vec2(-pixel.x * 2.2, pixel.y * 2.2)).a;
    camada3 += texture(TEXTURE, UV + vec2(pixel.x * 2.2, pixel.y * 2.2)).a;

    camada3 /= 8.0;


    // =====================================================
    // CAMADA 4 — DOURADO
    // =====================================================

    float camada4 = 0.0;

    camada4 += texture(TEXTURE, UV + vec2(-pixel.x * 4.0, 0.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(pixel.x * 4.0, 0.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(0.0, -pixel.y * 4.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(0.0, pixel.y * 4.0)).a;

    camada4 += texture(TEXTURE, UV + vec2(-pixel.x * 3.0, -pixel.y * 3.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(pixel.x * 3.0, -pixel.y * 3.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(-pixel.x * 3.0, pixel.y * 3.0)).a;
    camada4 += texture(TEXTURE, UV + vec2(pixel.x * 3.0, pixel.y * 3.0)).a;

    camada4 /= 8.0;


    // =====================================================
    // CAMADA 5 — DOURADO ESCURO
    // =====================================================

    float camada5 = 0.0;

    camada5 += texture(TEXTURE, UV + vec2(-pixel.x * 5.0, 0.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(pixel.x * 5.0, 0.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(0.0, -pixel.y * 5.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(0.0, pixel.y * 5.0)).a;

    camada5 += texture(TEXTURE, UV + vec2(-pixel.x * 4.0, -pixel.y * 4.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(pixel.x * 4.0, -pixel.y * 4.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(-pixel.x * 4.0, pixel.y * 4.0)).a;
    camada5 += texture(TEXTURE, UV + vec2(pixel.x * 4.0, pixel.y * 4.0)).a;

    camada5 /= 8.0;


    // =====================================================
    // CAMADA 6 — SOMBRA EXTERNA
    // =====================================================

    float camada6 = 0.0;

    camada6 += texture(TEXTURE, UV + vec2(-pixel.x * tamanho_aura, 0.0)).a;
    camada6 += texture(TEXTURE, UV + vec2(pixel.x * tamanho_aura, 0.0)).a;
    camada6 += texture(TEXTURE, UV + vec2(0.0, -pixel.y * tamanho_aura)).a;
    camada6 += texture(TEXTURE, UV + vec2(0.0, pixel.y * tamanho_aura)).a;

    camada6 /= 4.0;


    // =====================================================
    // SOMENTE FORA DO SPRITE
    // =====================================================

    camada1 *= fora;
    camada2 *= fora;
    camada3 *= fora;
    camada4 *= fora;
    camada5 *= fora;
    camada6 *= fora;


    // =====================================================
    // AURA
    // =====================================================

    vec3 aura = vec3(0.0);
    float alpha_aura = 0.0;


    // Região mais próxima
    aura += cor_viva.rgb * camada1 * 2.0;
    alpha_aura += camada1 * 1.0;


    // Região ainda muito viva
    aura += cor_viva_2.rgb * camada2 * 1.4;
    alpha_aura += camada2 * 0.85;


    // Dourado vivo
    aura += cor_dourada.rgb * camada3 * 1.1;
    alpha_aura += camada3 * 0.65;


    // Dourado
    aura += cor_dourada_2.rgb * camada4 * 0.8;
    alpha_aura += camada4 * 0.45;


    // Dourado escuro
    aura += cor_escura.rgb * camada5 * 0.55;
    alpha_aura += camada5 * 0.25;


    // Sombra
    aura += cor_escura.rgb * camada6 * 0.25;
    alpha_aura += camada6 * 0.12;


    // =====================================================
    // NORMALIZAÇÃO
    // =====================================================

    if (alpha_aura > 0.0) {
        aura /= alpha_aura;
    }


    // =====================================================
    // RESULTADO
    // =====================================================

    float intensidade_final = clamp(
        alpha_aura * intensidade,
        0.0,
        1.0
    );

    vec3 cor_final = mix(
        original.rgb,
        aura,
        intensidade_final
    );

    float alpha_final = max(
        original.a,
        clamp(alpha_aura, 0.0, 1.0)
    );

    COLOR = vec4(
        cor_final,
        alpha_final
    );
}