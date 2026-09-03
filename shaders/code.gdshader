shader_type canvas_item;

uniform float speed = 1.5;
uniform float columns = 30.0;
uniform float strength = 0.35;

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // coluna discreta
    float col = floor(UV.x * columns);
    float col_seed = rand(vec2(col, 0.0));

    // movimento vertical
    float y = fract(UV.y + TIME * speed * (0.5 + col_seed));

    // cria “cabeça” da gota
    float head = smoothstep(0.8, 1.0, y);

    // rastro abaixo da cabeça
    float trail = smoothstep(0.0, 0.8, y) * 0.3;

    float code = head + trail;

    // cor estilo Matrix (verde com glow leve)
    vec3 code_color = vec3(0.1, 1.0, 0.2);

    // mistura suave
    vec3 final_color = mix(tex.rgb, tex.rgb + code_color, code * strength);

    COLOR = vec4(final_color, tex.a);
}