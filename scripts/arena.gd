extends Node3D
class_name ArenaStage

## Stage 1: textured 3D arena, adjustable orthographic camera and depth layers.
## Runtime materials are original generated art or authored scene materials.

@export_group("Camera")
@export_range(20.0, 55.0, 0.5) var camera_pitch: float = 37.0
@export_range(9.0, 22.0, 0.1) var ortho_size: float = 19.0
@export var target_offset := Vector3(0.0, 0.0, 0.0)
@export var camera_follow_speed: float = 4.0
@export var camera_push_amount: float = 0.025

@export_group("Arena")
@export var arena_width: float = 18.0
@export var arena_depth: float = 13.0

const STONE_TEXTURE := "res://assets/arena/arena_stone_tile_gen.png"
const RITUAL_TEXTURE := "res://assets/arena/arena_ritual_decal_gen.png"
const STONE_SHADER := "res://shaders/stone_bump.gdshader"
const FLOOR_CENTER_Z := 1.25
const GATE_Z := -6.15

var _camera: Camera3D
var _camera_home := Vector3(0.0, 0.0, 0.0)
var _camera_target := Vector3(0.0, 1.8, FLOOR_CENTER_Z)
var _elapsed := 0.0
var _stone_material: StandardMaterial3D
var _floor_material: ShaderMaterial
var _dark_stone_material: StandardMaterial3D
var _grass_material: StandardMaterial3D
var _bronze_material: StandardMaterial3D
var _wick_material: StandardMaterial3D
var _decal_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_create_environment()
	_create_arena_floor()
	_create_arena_rim()
	_create_gate_and_chains()
	_create_candles()
	_create_edge_details()
	_create_camera()
	_create_key_light()


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_camera):
		_camera.position = _camera.position.lerp(_camera_home + Vector3(0.0, sin(_elapsed * 0.38) * camera_push_amount, 0.0), 1.0 - exp(-camera_follow_speed * delta))
		_camera.look_at(_camera_target, Vector3.UP)


func set_camera_target(world_position: Vector3) -> void:
	## Called by the player controller in the next stage. The player has not yet been added.
	_camera_home = world_position + target_offset + Vector3(0.0, 10.4, 14.0)
	_camera_target = world_position + target_offset + Vector3(0.0, 1.8, 0.0)


func clamp_to_arena(world_position: Vector3, margin: float = 0.55) -> Vector3:
	## Shared boundary helper for the player controller; follows the visible slab outline.
	var polygon := _arena_outline()
	var local_point := Vector2(world_position.x, world_position.z - FLOOR_CENTER_Z)
	if Geometry2D.is_point_in_polygon(local_point, polygon):
		# Keep a small margin from the broken stone lip.
		var closest := local_point
		var best_distance := INF
		for i in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			var edge := b - a
			var length_sq := edge.length_squared()
			if length_sq < 0.0001:
				continue
			var t := clampf((local_point - a).dot(edge) / length_sq, 0.0, 1.0)
			var candidate := a + edge * t
			var distance := local_point.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				closest = candidate
		if best_distance < margin * margin:
			local_point = closest.move_toward(local_point, margin)
	else:
		var closest := polygon[0]
		var best_distance := INF
		for i in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			var edge := b - a
			var length_sq := edge.length_squared()
			if length_sq < 0.0001:
				continue
			var t := clampf((local_point - a).dot(edge) / length_sq, 0.0, 1.0)
			var candidate := a + edge * t
			var distance := local_point.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				closest = candidate
		local_point = closest.move_toward(Vector2.ZERO, margin)
	return Vector3(local_point.x, world_position.y, local_point.y + FLOOR_CENTER_Z)


func set_camera_shake(strength: float) -> void:
	## Small bounded interface for later combat feedback.
	var bounded := clampf(strength, 0.0, 0.18)
	_camera.position += Vector3(randf_range(-bounded, bounded), randf_range(-bounded, bounded), 0.0)


func _create_materials() -> void:
	var stone_texture := load(STONE_TEXTURE) as Texture2D
	var ritual_texture := load(RITUAL_TEXTURE) as Texture2D
	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_texture = stone_texture
	_stone_material.uv1_scale = Vector3.ONE
	_stone_material.albedo_color = Color(0.82, 0.80, 0.78)
	_stone_material.roughness = 0.94
	_stone_material.metallic = 0.0
	_stone_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = load(STONE_SHADER)
	_floor_material.set_shader_parameter("albedo_tex", stone_texture)
	_floor_material.set_shader_parameter("tile_scale", Vector2(2.3, 2.0))
	_floor_material.set_shader_parameter("tint_color", Color(0.82, 0.80, 0.78, 1.0))
	_floor_material.set_shader_parameter("bump_strength", 0.32)
	_dark_stone_material = _make_material(Color(0.17, 0.135, 0.14), stone_texture, Vector3(1.8, 1.0, 1.8))
	_grass_material = _make_material(Color(0.31, 0.34, 0.19), stone_texture, Vector3(2.4, 1.0, 2.4))
	_bronze_material = _make_material(Color(0.43, 0.25, 0.12), null, Vector3.ONE, 0.56, 0.18)
	_wick_material = _make_material(Color(1.0, 0.36, 0.055), null, Vector3.ONE, 0.6, 0.0)
	_wick_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wick_material.emission_enabled = true
	_wick_material.emission = Color(1.0, 0.18, 0.025)
	_wick_material.emission_energy_multiplier = 2.2
	_decal_material = StandardMaterial3D.new()
	_decal_material.albedo_texture = ritual_texture
	_decal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_decal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_decal_material.no_depth_test = false
	_decal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_decal_material.uv1_scale = Vector3(1.0, 1.0, 1.0)


func _make_material(color: Color, texture: Texture2D = null, uv_scale: Vector3 = Vector3.ONE, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = texture
	mat.uv1_scale = uv_scale
	mat.roughness = roughness
	mat.metallic = metallic
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat


func _create_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.009, 0.019)
	sky_material.sky_horizon_color = Color(0.08, 0.035, 0.04)
	sky_material.ground_bottom_color = Color(0.009, 0.006, 0.012)
	sky_material.ground_horizon_color = Color(0.035, 0.018, 0.023)
	sky_material.sun_angle_max = 0.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.30, 0.27)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.04
	env_node.environment = env
	add_child(env_node)


func _create_arena_floor() -> void:
	var decal := MeshInstance3D.new()
	decal.name = "OriginalRitualMedallion"
	var decal_mesh := PlaneMesh.new()
	decal_mesh.size = Vector2(10.8, 10.8)
	decal.mesh = decal_mesh
	decal.material_override = _decal_material
	decal.position = Vector3(0.0, 0.018, FLOOR_CENTER_Z)
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(decal)

	# Thin grout and worn outer rim use textured stone rather than a flat-color ground.
	var outline := _arena_outline()
	_create_polygon_surface("WalkableStoneSlab", outline, 0.0, FLOOR_CENTER_Z, _floor_material, Vector2(7.5, 6.4))
	var outer_outline := _scaled_outline(outline, 1.14)
	_create_ring_surface("BrokenMossAndRubbleLip", outline, outer_outline, -0.055, FLOOR_CENTER_Z, _grass_material)
	_create_edge_walls(outline, FLOOR_CENTER_Z)


func _create_arena_rim() -> void:
	var beyond_depth := 28.0
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(80.0, beyond_depth)
	var abyss := MeshInstance3D.new()
	abyss.name = "Abyss"
	abyss.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.018, 0.013, 0.021)
	mat.albedo_texture = load(STONE_TEXTURE)
	mat.uv1_scale = Vector3(18.0, 1.0, 8.0)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	abyss.material_override = mat
	abyss.position = Vector3(0, -1.25, -10.8)
	add_child(abyss)

	# A few fractured stone fragments break the dark edge beyond the irregular moss lip.
	for i in range(12):
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_box("OuterBrokenSlab_%02d" % i, Vector3(randf_range(0.45, 1.15), 0.22, randf_range(0.4, 1.1)), Vector3(side * randf_range(8.6, 10.4), -0.28, FLOOR_CENTER_Z + randf_range(-6.4, 6.4)), _dark_stone_material)


func _create_gate_and_chains() -> void:
	# Textured, layered gate silhouette. Stone blocks have volume and cast shadows.
	var gate_center := Vector3(0.0, 0.0, GATE_Z)
	_add_box("GateLeftPier", Vector3(0.9, 3.25, 1.05), gate_center + Vector3(-2.65, 1.56, 0), _stone_material)
	_add_box("GateRightPier", Vector3(0.9, 3.25, 1.05), gate_center + Vector3(2.65, 1.56, 0), _stone_material)
	_add_box("GateBaseLeft", Vector3(1.45, 0.45, 1.25), gate_center + Vector3(-2.48, 0.18, 0), _dark_stone_material)
	_add_box("GateBaseRight", Vector3(1.45, 0.45, 1.25), gate_center + Vector3(2.48, 0.18, 0), _dark_stone_material)
	# Segmental voussoirs form a genuinely thick, readable stone arch.
	for i in range(9):
		var angle_deg := 180.0 - i * 22.5
		var angle := deg_to_rad(angle_deg)
		var voussoir := _add_box("ArchStone_%02d" % i, Vector3(1.02, 0.72, 1.35), gate_center + Vector3(2.55 * cos(angle), 3.0 + 2.25 * sin(angle), -0.04), _stone_material)
		voussoir.rotation_degrees.z = angle_deg + 90.0

	var portal := _add_box("GateDarkOpening", Vector3(3.5, 3.6, 0.22), gate_center + Vector3(0, 1.95, 0.4), _dark_stone_material)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A carved circular seal catches sickly green light as a separate rear layer.
	var seal := MeshInstance3D.new()
	seal.name = "GateSeal"
	var seal_mesh := CylinderMesh.new()
	seal_mesh.top_radius = 0.70
	seal_mesh.bottom_radius = 0.70
	seal_mesh.height = 0.07
	seal.mesh = seal_mesh
	var seal_mat := _make_material(Color(0.19, 0.25, 0.11), null, Vector3.ONE, 0.76, 0.1)
	seal_mat.emission_enabled = true
	seal_mat.emission = Color(0.08, 0.13, 0.02)
	seal_mat.emission_energy_multiplier = 0.50
	seal.material_override = seal_mat
	seal.position = gate_center + Vector3(0, 4.05, 0.52)
	seal.rotation_degrees.x = 90.0
	add_child(seal)

	# Thick interlocking chain links span the rear backdrop.
	for i in range(23):
		var link := MeshInstance3D.new()
		link.name = "ChainLink_%02d" % i
		var main_link_mesh := TorusMesh.new()
		main_link_mesh.inner_radius = 0.15
		main_link_mesh.outer_radius = 0.36
		link.mesh = main_link_mesh
		link.material_override = _bronze_material
		link.position = Vector3(-8.6 + i * 0.78, 6.55 + 0.20 * cos(i * 0.47), GATE_Z - 0.45)
		link.scale = Vector3(1.0, 1.15, 0.78)
		link.rotation_degrees = Vector3(90 if i % 2 == 0 else 0, 0, 90)
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(link)

	# Side hanging chains anchor into the gate pillars.
	for side in [-1.0, 1.0]:
		for i in range(8):
			var link := MeshInstance3D.new()
			link.name = "SideChain_%s_%02d" % [side, i]
			var side_link_mesh := TorusMesh.new()
			side_link_mesh.inner_radius = 0.13
			side_link_mesh.outer_radius = 0.29
			link.mesh = side_link_mesh
			link.material_override = _bronze_material
			link.position = Vector3(side * (5.0 + 0.10 * sin(i)), 5.9 - i * 0.59, GATE_Z - 0.5)
			link.rotation_degrees = Vector3(90 if i % 2 == 0 else 0, 0, 18 * side)
			add_child(link)


func _create_candles() -> void:
	for side in [-1.0, 1.0]:
		for i in range(3):
			var x: float = side * (5.8 + (i % 2) * 1.0)
			var z: float = GATE_Z + 1.5 + i * 1.25
			_add_box("CandleStone_%s_%d" % [side, i], Vector3(0.66, 0.9 + (i % 2) * 0.22, 0.6), Vector3(x, 0.42, z), _dark_stone_material)
			var candle := MeshInstance3D.new()
			candle.name = "Candle_%s_%d" % [side, i]
			var candle_mesh := CylinderMesh.new()
			candle_mesh.top_radius = 0.12
			candle_mesh.bottom_radius = 0.17
			candle_mesh.height = 0.48
			candle.mesh = candle_mesh
			candle.material_override = _make_material(Color(0.26, 0.19, 0.13))
			candle.position = Vector3(x, 1.18, z)
			add_child(candle)
			var flame := MeshInstance3D.new()
			flame.name = "CandleFlame_%s_%d" % [side, i]
			var flame_mesh := SphereMesh.new()
			flame_mesh.radius = 0.12
			flame_mesh.height = 0.36
			flame.mesh = flame_mesh
			flame.material_override = _wick_material
			flame.position = Vector3(x, 1.52, z)
			add_child(flame)
			var light := OmniLight3D.new()
			light.name = "CandleGlow_%s_%d" % [side, i]
			light.light_color = Color(1.0, 0.23, 0.055)
			light.light_energy = 0.82
			light.omni_range = 4.6
			light.position = Vector3(x, 1.68, z)
			add_child(light)


func _create_edge_details() -> void:
	# Grass tufts and broken stones are placed outside the combat lane.
	for i in range(64):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := randf_range(FLOOR_CENTER_Z - 5.7, FLOOR_CENTER_Z + 5.7)
		var x := side * randf_range(8.9, 10.1)
		var tuft := MeshInstance3D.new()
		tuft.name = "GrassTuft_%02d" % i
		var mesh := PrismMesh.new()
		mesh.size = Vector3(randf_range(0.12, 0.32), randf_range(0.18, 0.55), 0.06)
		tuft.mesh = mesh
		tuft.material_override = _make_material(Color(randf_range(0.12, 0.23), randf_range(0.20, 0.29), randf_range(0.075, 0.13)), null)
		tuft.position = Vector3(x, 0.08, z)
		tuft.rotation_degrees.y = randf_range(-50, 50)
		add_child(tuft)
	for i in range(24):
		var side := -1.0 if i % 2 == 0 else 1.0
		var rock := MeshInstance3D.new()
		rock.name = "Rubble_%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.12, 0.34)
		mesh.height = mesh.radius * randf_range(0.5, 1.1)
		rock.mesh = mesh
		rock.material_override = _dark_stone_material
		rock.position = Vector3(side * randf_range(8.3, 9.7), 0.02, randf_range(FLOOR_CENTER_Z - 6.4, FLOOR_CENTER_Z + 6.4))
		rock.scale = Vector3(randf_range(0.9, 1.8), 0.65, randf_range(0.8, 1.7))
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rock)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ArenaCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ortho_size
	_camera.near = 0.1
	_camera.far = 120.0
	var look_target := Vector3(target_offset.x, 1.8 + target_offset.y, FLOOR_CENTER_Z + target_offset.z)
	var distance := 17.0
	_camera.position = look_target + Vector3(0, sin(deg_to_rad(camera_pitch)) * distance, cos(deg_to_rad(camera_pitch)) * distance)
	_camera_home = _camera.position
	_camera.current = true
	add_child(_camera)
	_camera.look_at(look_target, Vector3.UP)


func _create_key_light() -> void:
	var key := DirectionalLight3D.new()
	key.name = "ColdMoonlight"
	key.rotation_degrees = Vector3(-51.0, -24.0, 0.0)
	key.light_color = Color(0.62, 0.55, 0.49)
	key.light_energy = 0.82
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 35.0
	add_child(key)
	var gate_glow := OmniLight3D.new()
	gate_glow.name = "SicklyGateGlow"
	gate_glow.light_color = Color(0.53, 0.58, 0.18)
	gate_glow.light_energy = 1.1
	gate_glow.omni_range = 7.0
	gate_glow.position = Vector3(0, 3.0, GATE_Z + 0.6)
	add_child(gate_glow)


func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	item.position = at
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(item)
	return item


func _arena_outline() -> PackedVector2Array:
	var raw := PackedVector2Array([
		Vector2(-7.8, -6.2), Vector2(-6.8, -6.85), Vector2(-2.4, -6.65),
		Vector2(2.1, -6.95), Vector2(6.5, -6.7), Vector2(7.7, -5.9),
		Vector2(8.15, -4.25), Vector2(7.95, -1.1), Vector2(8.35, 2.3),
		Vector2(7.75, 4.9), Vector2(7.0, 6.05), Vector2(5.6, 6.45),
		Vector2(1.8, 6.25), Vector2(-1.4, 6.6), Vector2(-5.8, 6.38),
		Vector2(-7.3, 5.95), Vector2(-8.05, 4.55), Vector2(-7.9, 1.2),
		Vector2(-8.3, -2.3), Vector2(-8.05, -4.9)
	])
	var result := PackedVector2Array()
	for point in raw:
		result.append(Vector2(point.x * arena_width / 16.7, point.y * arena_depth / 13.9))
	return result


func _scaled_outline(outline: PackedVector2Array, scale_factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in outline:
		result.append(point * scale_factor)
	return result


func _create_polygon_surface(node_name: String, polygon: PackedVector2Array, height: float, z_offset: float, material: Material, uv_world_scale: Vector2) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for index in indices:
		var point: Vector2 = polygon[index]
		vertices.append(Vector3(point.x, height, point.y + z_offset))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x / uv_world_scale.x, point.y / uv_world_scale.y))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var polygon_mesh := ArrayMesh.new()
	polygon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = polygon_mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _create_ring_surface(node_name: String, inner: PackedVector2Array, outer: PackedVector2Array, height: float, z_offset: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(inner.size()):
		var next := (i + 1) % inner.size()
		var a := Vector3(inner[i].x, height, inner[i].y + z_offset)
		var b := Vector3(outer[i].x, height, outer[i].y + z_offset)
		var c := Vector3(inner[next].x, height, inner[next].y + z_offset)
		var d := Vector3(outer[next].x, height, outer[next].y + z_offset)
		st.set_uv(Vector2(0, 0)); st.add_vertex(a)
		st.set_uv(Vector2(1, 0)); st.add_vertex(b)
		st.set_uv(Vector2(0, 1)); st.add_vertex(c)
		st.set_uv(Vector2(1, 0)); st.add_vertex(b)
		st.set_uv(Vector2(1, 1)); st.add_vertex(d)
		st.set_uv(Vector2(0, 1)); st.add_vertex(c)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _create_edge_walls(outline: PackedVector2Array, z_offset: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var next := (i + 1) % outline.size()
		var a := Vector3(outline[i].x, 0.0, outline[i].y + z_offset)
		var b := Vector3(outline[next].x, 0.0, outline[next].y + z_offset)
		var c := Vector3(outline[i].x, -0.52, outline[i].y + z_offset)
		var d := Vector3(outline[next].x, -0.52, outline[next].y + z_offset)
		st.set_uv(Vector2(0, 0)); st.add_vertex(a)
		st.set_uv(Vector2(1, 0)); st.add_vertex(b)
		st.set_uv(Vector2(0, 1)); st.add_vertex(c)
		st.set_uv(Vector2(1, 0)); st.add_vertex(b)
		st.set_uv(Vector2(1, 1)); st.add_vertex(d)
		st.set_uv(Vector2(0, 1)); st.add_vertex(c)
	st.generate_normals()
	var edge := MeshInstance3D.new()
	edge.name = "RoughStoneBrokenEdge"
	edge.mesh = st.commit()
	edge.material_override = _dark_stone_material
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge)
