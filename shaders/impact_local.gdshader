shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 center = vec2(0.5);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
void fragment() {
	float distance_px = length((SCREEN_UV - center) * viewport_size);
	float mask = 1.0 - smoothstep(34.0, 52.0, distance_px);
	COLOR = vec4(vec3(1.0) - texture(screen_tex, SCREEN_UV).rgb, mask * 0.65);
}
