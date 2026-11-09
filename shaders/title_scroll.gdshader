shader_type canvas_item;
uniform float travel = 0.0;
uniform float depth = 0.0;

vec4 loop_sample(sampler2D image, vec2 uv) {
	float y = fract(uv.y);
	vec4 first = texture(image, vec2(uv.x, 0.1 + y * 0.8));
	vec4 next = texture(image, vec2(uv.x, 0.1 + (y - 1.0) * 0.8));
	return mix(first, next, smoothstep(0.88, 1.0, y));
}

void fragment() {
	vec4 art = loop_sample(TEXTURE, vec2(UV.x, UV.y + travel));
	if (depth > 0.5) {
		art.a *= smoothstep(0.22, 0.40, abs(UV.x - 0.5));
		art.rgb *= 0.82;
	} else {
		art.rgb *= 0.62;
	}
	COLOR = art;
}
