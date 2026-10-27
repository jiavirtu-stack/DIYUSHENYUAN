shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform vec2 tile_scale = vec2(2.25, 1.95);
uniform vec4 tint_color : source_color = vec4(0.82, 0.80, 0.78, 1.0);
uniform vec2 texel_size = vec2(0.000977, 0.000977);
uniform float bump_strength : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	vec2 tiled_uv = UV * tile_scale;
	vec3 texel = texture(albedo_tex, tiled_uv).rgb;
	float height_center = dot(texel, vec3(0.30, 0.59, 0.11));
	float height_x = dot(texture(albedo_tex, tiled_uv + vec2(texel_size.x, 0.0)).rgb, vec3(0.30, 0.59, 0.11));
	float height_y = dot(texture(albedo_tex, tiled_uv + vec2(0.0, texel_size.y)).rgb, vec3(0.30, 0.59, 0.11));
	vec3 tangent_normal = normalize(vec3((height_center - height_x) * bump_strength * 14.0, (height_center - height_y) * bump_strength * 14.0, 1.0));
	ALBEDO = texel * tint_color.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.34;
}
