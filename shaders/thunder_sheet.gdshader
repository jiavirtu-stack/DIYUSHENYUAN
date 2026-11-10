shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float frame_index = 48.0;
uniform float opacity = 1.0;
void fragment() {
	float frame = floor(frame_index);
	vec2 cell = vec2(mod(frame, 12.0), floor(frame / 12.0));
	vec2 inset_uv = clamp(UV, vec2(0.003), vec2(0.997));
	vec4 tex = texture(atlas, (cell + inset_uv) / vec2(12.0, 10.0));
	float lightness = max(tex.r, max(tex.g, tex.b));
	ALBEDO = tex.rgb;
	ALPHA = tex.a * smoothstep(0.015, 0.13, lightness) * opacity;
}
