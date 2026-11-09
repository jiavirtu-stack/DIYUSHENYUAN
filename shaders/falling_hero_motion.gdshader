shader_type canvas_item;

uniform float animation_time = 0.0;
uniform float motion_strength : hint_range(0.0, 2.0) = 1.0;

float region(vec2 uv, vec4 rect) {
	vec2 enter = smoothstep(rect.xy, rect.xy + vec2(0.025), uv);
	vec2 leave = 1.0 - smoothstep(rect.zw - vec2(0.025), rect.zw, uv);
	return enter.x * enter.y * leave.x * leave.y;
}

vec2 swing(vec2 uv, vec2 pivot, float angle, vec4 rect) {
	float w = region(uv, rect);
	float c = cos(angle * w);
	float s = sin(angle * w);
	vec2 p = uv - pivot;
	return pivot + vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float scarf_color(vec4 color) {
	return smoothstep(0.025, 0.075, color.r - color.b * 0.95) * smoothstep(0.02, 0.07, color.r - color.g * 1.4) * color.a;
}

void fragment() {
	float t = animation_time;
	float a = motion_strength;
	vec2 uv = UV;
	// Each limb has a separate phase and soft joint region, so the torso stays still.
	uv = swing(uv, vec2(0.515, 0.447), sin(t * 1.24) * 0.043 * a, vec4(0.43, 0.14, 0.605, 0.465));
	uv = swing(uv, vec2(0.642, 0.660), sin(t * 1.03 + 1.6) * 0.027 * a, vec4(0.51, 0.405, 0.695, 0.68));
	uv = swing(uv, vec2(0.694, 0.535), sin(t * 0.92 + 0.7) * 0.035 * a, vec4(0.65, 0.205, 0.865, 0.55));
	uv = swing(uv, vec2(0.781, 0.600), sin(t * 0.92 + 2.4) * -0.043 * a, vec4(0.765, 0.35, 0.955, 0.62));
	// The bell lags behind the upper body and swings a little more than the hands.
	uv = swing(uv, vec2(0.405, 0.704), (sin(t * 1.45 - 0.8) * 0.085 + sin(t * 2.9) * 0.014) * a, vec4(0.325, 0.695, 0.477, 0.88));
	vec4 base = texture(TEXTURE, uv);
	// Red-only cloth advection keeps the mask and hood from wobbling with the scarf.
	float tail = (1.0 - smoothstep(0.27, 0.47, UV.x)) * region(UV, vec4(0.025, 0.045, 0.49, 0.79));
	vec2 cloth_uv = UV + vec2(sin(t * 1.8 - UV.y * 13.0) * 0.014, cos(t * 1.45 - UV.x * 9.0) * 0.008) * tail * a;
	vec4 cloth = texture(TEXTURE, cloth_uv);
	float cloth_mask = max(scarf_color(base), scarf_color(cloth)) * tail;
	// Preserve opaque non-red details underneath the loose ends.
	if (base.a < 0.1 || scarf_color(base) > 0.1) {
		base = mix(base, cloth, cloth_mask);
	}
	COLOR = base;
}
