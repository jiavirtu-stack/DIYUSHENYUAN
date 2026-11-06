shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform float disturbance : hint_range(0.0, 1.0) = 0.0;

float noise(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float border = max(abs(uv.x - 0.5) * 2.0, abs(uv.y - 0.5) * 2.0);
	float edge = smoothstep(0.62, 0.97, border);
	float tick = floor(TIME * 7.0);
	float scan = step(0.975, noise(vec2(floor(uv.y * 150.0), tick)));
	float shift = (noise(vec2(tick, floor(uv.y * 70.0))) - 0.5) * 0.009 * scan * disturbance;
	vec2 sample_uv = clamp(uv + vec2(shift, 0.0), vec2(0.001), vec2(0.999));
	vec3 color = texture(artwork, sample_uv).rgb;
	float split = 0.0025 * edge * disturbance;
	color.r = texture(artwork, clamp(sample_uv + vec2(split, 0.0), vec2(0.001), vec2(0.999))).r;
	color.b = texture(artwork, clamp(sample_uv - vec2(split, 0.0), vec2(0.001), vec2(0.999))).b;
	float grain = noise(floor(uv * vec2(850.0, 560.0)) + tick);
	color += (grain - 0.5) * edge * disturbance * 0.12;
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
}
