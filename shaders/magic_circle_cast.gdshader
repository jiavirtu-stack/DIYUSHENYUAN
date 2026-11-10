shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.6, 0.35, 1.0, 1.0);
uniform float age = 0.0;
float ring(float radius, float target, float width) {
	return 1.0 - smoothstep(width, width + 0.009, abs(radius - target));
}
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return 1.0 - smoothstep(0.009, 0.022, length(p - a - t * ab));
}
void fragment() {
	float opening = mix(0.25, 1.0, smoothstep(0.0, 0.16, age));
	vec2 p = (UV * 2.0 - 1.0) / opening;
	float r = length(p);
	if (r > 1.0) discard;
	float angle = atan(p.y, p.x);
	float spin = age * 0.65;
	float c = cos(spin);
	float s = sin(spin);
	vec2 q = mat2(vec2(c, -s), vec2(s, c)) * p;
	float ink = ring(r, 0.91, 0.012) + ring(r, 0.76, 0.008) + ring(r, 0.50, 0.012);
	float sectors = abs(fract((angle + spin) / 6.2831853 * 24.0) - 0.5);
	ink += (1.0 - smoothstep(0.06, 0.12, sectors)) * step(0.79, r) * step(r, 0.87);
	float short_marks = (1.0 - smoothstep(0.16, 0.21, sectors)) * ring(r, 0.845, 0.009);
	ink += short_marks;
	vec2 a = vec2(0.0, -0.63);
	vec2 b = vec2(0.546, 0.315);
	vec2 d = vec2(-0.546, 0.315);
	ink += segment(q, a, b) + segment(q, b, d) + segment(q, d, a);
	ink += segment(-q, a, b) + segment(-q, b, d) + segment(-q, d, a);
	float wave = exp(-abs(r - age * 1.6) * 32.0) * 0.4;
	float fade = smoothstep(0.0, 0.05, age) * (1.0 - smoothstep(0.34, 0.68, age));
	float light = clamp(ink + wave, 0.0, 1.6);
	ALBEDO = mix(tint.rgb, vec3(0.88, 0.9, 1.0), clamp(ink - 0.8, 0.0, 0.6));
	ALPHA = clamp(light * 0.7, 0.0, 0.85) * fade * tint.a;
}
