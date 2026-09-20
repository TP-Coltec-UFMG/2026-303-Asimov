shader_type canvas_item;

uniform float spacing : hint_range(1.0, 20.0) = 4.0;
uniform float strength : hint_range(0.0, 1.0) = 0.15;
uniform float speed : hint_range(-10.0, 10.0) = 0.5;

void fragment() {
    float y = UV.y * 1000.0;

    float scanline = step(
        0.5,
        fract(y / spacing + TIME * speed)
    );

    float alpha = (1.0 - scanline) * strength;

    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}