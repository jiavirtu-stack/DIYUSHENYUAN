shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.3, 0.7, 1.0, 0.6);
uniform float style = 0.0;
uniform float age = 0.0;
uniform bool preview = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = style > 0.5 && style < 1.5 ? max(abs(p.x), abs(p.y)) : length(p);
	if (d > 1.0) discard;
	float rim = smoothstep(0.88, 0.94, d);
	float wave = 0.5 + 0.5 * sin(d * 23.0 - age * 5.0);
	float pattern = wave * 0.1;
	if (style > 0.5 && style < 1.5) {
		vec2 cell = abs(fract(UV * 5.0) - 0.5);
		pattern = step(0.46, max(cell.x, cell.y)) * 0.28;
	}
	if (style > 1.5) {
		pattern = pow(0.5 + 0.5 * sin(atan(p.y, p.x) * 3.0 + d * 15.0 - age * 5.0), 8.0) * 0.4;
	}
	ALBEDO = tint.rgb * (0.8 + rim * 0.3);
	ALPHA = tint.a * (rim * 0.75 + (preview ? 0.05 : 0.10 + pattern));
}
