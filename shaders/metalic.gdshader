shader_type canvas_item;

uniform float shine_duration = 0.6; // tempo do brilho (segundos)
uniform float pause_duration = 3.0; // tempo parado (segundos)
uniform float width = 0.15;
uniform float intensity = 1.0;uniform vec4 shine_color : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float cycle = shine_duration + pause_duration;

    // tempo dentro do ciclo completo
    float t = mod(TIME, cycle);

    float shine = 0.0;

    // só ativa durante o tempo do brilho
    if (t < shine_duration) {
        float progress = t / shine_duration;

        float pos = -width + progress * (1.0 + 2.0 * width);

        shine = smoothstep(pos - width, pos, UV.x) -
                smoothstep(pos, pos + width, UV.x);

        shine *= intensity;
    }

    vec3 final_color = tex.rgb + shine * shine_color.rgb;

    COLOR = vec4(final_color, tex.a);
}