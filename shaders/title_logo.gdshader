shader_type canvas_item;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float value = max(color.r, max(color.g, color.b));
	COLOR = vec4(color.rgb, smoothstep(0.28, 0.55, value));
}
