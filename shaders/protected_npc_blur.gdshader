shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount = 2.8;

void fragment() {
	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = vec4(screen_color.rgb * 0.72, 0.96);
}
