extends Node3D
class_name InfantryRoom

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/corrupted_villager.gd")
const HUD_SCRIPT := preload("res://scripts/battle_hud.gd")
const FEEDBACK_SCRIPT := preload("res://scripts/combat_feedback.gd")
const STONE_TEXTURE := "res://assets/arena/arena_stone_tile_gen.png"
const HALL_SCENE := "res://scenes/connecting_hall.tscn"
const BOSS_SCENE := "res://scenes/arena.tscn"

@export_range(15.0, 35.0, 0.5) var camera_ortho_size := 22.0
@export_range(10.0, 45.0, 0.5) var camera_pitch := 24.0
@export var camera_follow_speed := 4.2
@export_range(0.0, 5.0, 0.1) var camera_edge_look_ahead := 2.4

const HALF_WIDTH := 28.0
const HALF_DEPTH := 22.0
const EXIT_POSITION := Vector3(0.0, 0.0, -20.1)

var _camera: Camera3D
var _camera_target := Vector3(0.0, 1.5, 0.0)
var _camera_home := Vector3.ZERO
var _camera_shake := Vector3.ZERO
var _player: FairytalePlayer
var _door_blocker: StaticBody3D
var _exit_glow: MeshInstance3D
var _remaining_enemies := 0
var _total_enemies := 0
var _door_open := false
var _transitioning := false
var _room_number := 1
var _room_exit := Vector3.ZERO


func _ready() -> void:
	randomize()
	var run_state := get_node_or_null("/root/RunState")
	_room_number = clampi((run_state.cleared_rooms if run_state != null else 0) + 1, 1, 3)
	_room_exit = EXIT_POSITION
	_build_world_environment()
	_build_room()
	_build_obstacles()
	_build_lanterns()
	_build_exit_gate()
	_build_spawn_marker()
	_create_camera()
	_create_lighting()
	_create_combat_feedback()
	_spawn_player()
	_spawn_enemies()
	_spawn_hud()


func _process(delta: float) -> void:
	if is_instance_valid(_camera):
		var desired := _camera_home + _camera_shake
		_camera.position = _camera.position.lerp(desired, 1.0 - exp(-camera_follow_speed * delta))
		_camera.look_at(_camera_target, Vector3.UP)
		_camera_shake = _camera_shake.lerp(Vector3.ZERO, 1.0 - exp(-12.0 * delta))
	if not _door_open and _remaining_enemies <= 0:
		_open_exit_gate()
	if _door_open and not _transitioning and is_instance_valid(_player):
		if _room_number < 3 and _player.global_position.z <= -22.8 and absf(_player.global_position.x) <= 2.0:
			_enter_next_area()


func set_camera_target(world_position: Vector3) -> void:
	# Keep the camera centered on the player until its viewport reaches a room
	# edge, then lock it there so the room geometry fills the frame without void.
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
	var half_view_width := camera_ortho_size * aspect * 0.5
	var half_view_depth := camera_ortho_size * 0.5 / maxf(0.25, cos(deg_to_rad(camera_pitch)))
	var x_min := -HALF_WIDTH + half_view_width
	var x_max := HALF_WIDTH - half_view_width
	var z_min := -HALF_DEPTH + half_view_depth
	var z_max := HALF_DEPTH - half_view_depth
	var camera_x := clampf(world_position.x, minf(x_min, x_max), maxf(x_min, x_max))
	var camera_z := clampf(world_position.z, minf(z_min, z_max), maxf(z_min, z_max))
	if _door_open and _room_number < 3 and world_position.z < -19.8:
		camera_z = world_position.z
	_camera_target = Vector3(camera_x, 1.45, camera_z)
	var distance := 24.0
	var pitch := deg_to_rad(camera_pitch)
	_camera_home = _camera_target + Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)


func clamp_to_arena(world_position: Vector3, margin: float = 0.65) -> Vector3:
	if _door_open and _room_number < 3 and absf(world_position.x) <= 2.0 and world_position.z < -19.8:
		return Vector3(world_position.x, world_position.y, minf(world_position.z, -23.0))
	return Vector3(
		clampf(world_position.x, -HALF_WIDTH + margin, HALF_WIDTH - margin),
		world_position.y,
		clampf(world_position.z, -HALF_DEPTH + margin, HALF_DEPTH - margin)
	)


func set_camera_shake(strength: float) -> void:
	var bounded := clampf(strength, 0.0, 0.18)
	_camera_shake = Vector3(randf_range(-bounded, bounded), randf_range(-bounded, bounded), 0.0)


func get_hud_status() -> String:
	if not _door_open:
		return "村落区域 %d / 3 · 清除敌人  %02d / %02d" % [_room_number, _total_enemies - _remaining_enemies, _total_enemies]
	if is_instance_valid(_player) and _player.global_position.distance_to(_room_exit) <= 3.1:
		return "通道已开启 · 按 E 前进"
	return "敌人已清除 · 前往北侧出口"


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or not _door_open or not is_instance_valid(_player):
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			if _player.global_position.distance_to(_room_exit) <= 3.1 and _room_number == 3:
				_enter_next_area()
				get_viewport().set_input_as_handled()


func _build_world_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.010, 0.018)
	sky_material.sky_horizon_color = Color(0.075, 0.040, 0.036)
	sky_material.ground_bottom_color = Color(0.008, 0.007, 0.012)
	sky_material.ground_horizon_color = Color(0.035, 0.020, 0.022)
	sky_material.sun_angle_max = 0.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.39, 0.31)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.20
	environment.glow_bloom = 0.035
	world.environment = environment
	add_child(world)


func _build_room() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "LargeCryptFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(HALF_WIDTH * 2.0, HALF_DEPTH * 2.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = load(STONE_TEXTURE) as Texture2D
	floor_material.albedo_color = Color(0.74, 0.72, 0.68)
	floor_material.uv1_scale = Vector3(7.0, 1.0, 6.0)
	floor_material.roughness = 0.98
	floor_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	floor.material_override = floor_material
	floor.position.y = -0.06
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)

	var border_material := _material(Color(0.15, 0.12, 0.12), Color(0.035, 0.024, 0.025), 0.95)
	var wall_material := _material(Color(0.29, 0.24, 0.20), Color(0.025, 0.018, 0.018), 0.92)
	_add_wall("WestBoundary", Vector3(0.8, 2.9, HALF_DEPTH * 2.0 + 1.0), Vector3(-HALF_WIDTH - 0.4, 1.35, 0.0), wall_material)
	_add_wall("EastBoundary", Vector3(0.8, 2.9, HALF_DEPTH * 2.0 + 1.0), Vector3(HALF_WIDTH + 0.4, 1.35, 0.0), wall_material)
	_add_wall("SouthWallLeft", Vector3(HALF_WIDTH - 2.4, 2.9, 0.9), Vector3(-HALF_WIDTH * 0.5 - 1.2, 1.35, HALF_DEPTH + 0.3), wall_material)
	_add_wall("SouthWallRight", Vector3(HALF_WIDTH - 2.4, 2.9, 0.9), Vector3(HALF_WIDTH * 0.5 + 1.2, 1.35, HALF_DEPTH + 0.3), wall_material)
	_add_wall("NorthWallLeft", Vector3(HALF_WIDTH - 2.4, 2.9, 0.9), Vector3(-HALF_WIDTH * 0.5 - 1.2, 1.35, -HALF_DEPTH - 0.3), wall_material)
	_add_wall("NorthWallRight", Vector3(HALF_WIDTH - 2.4, 2.9, 0.9), Vector3(HALF_WIDTH * 0.5 + 1.2, 1.35, -HALF_DEPTH - 0.3), wall_material)
	_add_wall("NorthHeader", Vector3(4.8, 0.8, 1.0), Vector3(0.0, 2.55, -HALF_DEPTH - 0.3), wall_material)
	_add_wall("SouthHeader", Vector3(4.8, 0.8, 1.0), Vector3(0.0, 2.55, HALF_DEPTH + 0.3), wall_material)
	_add_decorative_border(border_material)


func _add_decorative_border(material: Material) -> void:
	for side in [-1.0, 1.0]:
		for index in range(11):
			var z := -13.0 + index * 2.6
			_add_box("BoundaryBlock_%s_%02d" % [side, index], Vector3(0.9, 0.75, 0.75), Vector3(side * (HALF_WIDTH - 0.25), 0.4, z), material, false)
	for index in range(12):
		var x := -15.0 + index * 2.7
		if absf(x) < 3.0:
			continue
		_add_box("NorthMasonry_%02d" % index, Vector3(0.78, 0.72, 0.72), Vector3(x, 0.38, -HALF_DEPTH + 0.15), material, false)
		_add_box("SouthMasonry_%02d" % index, Vector3(0.78, 0.72, 0.72), Vector3(x, 0.38, HALF_DEPTH - 0.15), material, false)


func _build_obstacles() -> void:
	var stone_material := _material(Color(0.34, 0.29, 0.24), Color(0.04, 0.025, 0.02), 0.96)
	var moss_material := _material(Color(0.22, 0.25, 0.16), Color(0.018, 0.027, 0.01), 0.95)
	var crate_material := _material(Color(0.28, 0.16, 0.085), Color(0.05, 0.025, 0.008), 0.92)
	var obstacles := [
		[Vector3(-12.0, 0.0, 8.0), Vector3(1.8, 1.7, 1.8), stone_material],
		[Vector3(-6.8, 0.0, 5.0), Vector3(1.5, 1.0, 1.4), crate_material],
		[Vector3(8.8, 0.0, 7.0), Vector3(2.0, 1.5, 1.8), moss_material],
		[Vector3(14.0, 0.0, 1.0), Vector3(1.6, 2.2, 1.6), stone_material],
		[Vector3(-13.0, 0.0, -1.0), Vector3(2.0, 1.6, 1.8), moss_material],
		[Vector3(-7.0, 0.0, -4.0), Vector3(1.8, 1.4, 1.6), stone_material],
		[Vector3(7.0, 0.0, -4.0), Vector3(1.7, 1.2, 1.6), crate_material],
		[Vector3(13.0, 0.0, -7.5), Vector3(1.9, 1.8, 1.9), moss_material],
		[Vector3(-11.0, 0.0, -9.0), Vector3(1.6, 1.4, 1.6), stone_material],
		[Vector3(0.0, 0.0, 3.0), Vector3(1.4, 1.9, 1.4), stone_material],
		[Vector3(0.0, 0.0, -8.5), Vector3(1.3, 1.8, 1.3), crate_material],
	]
	var obstacle_index := 0
	for entry in obstacles:
		var position: Vector3 = entry[0]
		var size: Vector3 = entry[1]
		var material: Material = entry[2]
		var obstacle := _add_box("RoomObstacle_%02d" % obstacle_index, size, position + Vector3.UP * size.y * 0.5, material, true)
		obstacle.rotation_degrees.y = randf_range(-8.0, 8.0)
		obstacle_index += 1
		if obstacle_index % 3 == 0:
			_add_box("MossCap_%02d" % obstacle_index, Vector3(size.x * 0.72, 0.16, size.z * 0.72), position + Vector3.UP * (size.y + 0.06), moss_material, false)

	# Rubble and shallow puddles decorate the walkable lanes without blocking movement.
	for index in range(24):
		var rubble := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.12, 0.34)
		mesh.height = mesh.radius * randf_range(0.5, 0.9)
		rubble.mesh = mesh
		rubble.material_override = stone_material
		rubble.position = Vector3(randf_range(-HALF_WIDTH + 2.0, HALF_WIDTH - 2.0), 0.06, randf_range(-HALF_DEPTH + 2.0, HALF_DEPTH - 2.0))
		rubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rubble)


func _build_lanterns() -> void:
	var stone := _material(Color(0.20, 0.17, 0.15), Color(0.025, 0.015, 0.014), 0.9)
	var flame_material := _material(Color(1.0, 0.34, 0.065), Color(0.9, 0.14, 0.02), 0.55)
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.19, 0.025)
	flame_material.emission_energy_multiplier = 2.0
	for position in [Vector3(-16.8, 0.0, -9.0), Vector3(16.8, 0.0, -9.0), Vector3(-16.8, 0.0, 0.0), Vector3(16.8, 0.0, 0.0), Vector3(-16.8, 0.0, 9.0), Vector3(16.8, 0.0, 9.0)]:
		_add_box("LanternPedestal", Vector3(0.55, 1.1, 0.55), position + Vector3.UP * 0.55, stone, false)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.15
		flame_mesh.height = 0.34
		flame.mesh = flame_mesh
		flame.material_override = flame_material
		flame.position = position + Vector3.UP * 1.28
		add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.28, 0.08)
		light.light_energy = 0.85
		light.omni_range = 5.0
		light.position = position + Vector3.UP * 1.5
		add_child(light)


func _build_exit_gate() -> void:
	var stone := _material(Color(0.31, 0.25, 0.20), Color(0.035, 0.02, 0.015), 0.91)
	var dark := _material(Color(0.025, 0.018, 0.025), Color(0.025, 0.045, 0.055), 0.72)
	var seal := _material(Color(0.20, 0.22, 0.15), Color(0.22, 0.25, 0.08), 0.62)
	seal.emission_enabled = true
	seal.emission = Color(0.12, 0.19, 0.045)
	seal.emission_energy_multiplier = 0.65
	_add_box("ExitPillarLeft", Vector3(0.85, 3.3, 1.15), Vector3(-2.5, 1.65, -21.8), stone, false)
	_add_box("ExitPillarRight", Vector3(0.85, 3.3, 1.15), Vector3(2.5, 1.65, -21.8), stone, false)
	_add_box("ExitLintel", Vector3(5.7, 0.8, 1.25), Vector3(0.0, 3.1, -21.8), stone, false)
	_add_box("PortalDarkness", Vector3(3.6, 3.0, 0.18), Vector3(0.0, 1.5, -21.45), dark, false)
	var rune := MeshInstance3D.new()
	var rune_mesh := CylinderMesh.new()
	rune_mesh.top_radius = 0.62
	rune_mesh.bottom_radius = 0.62
	rune_mesh.height = 0.08
	rune.mesh = rune_mesh
	rune.material_override = seal
	rune.rotation_degrees.x = 90.0
	rune.position = Vector3(0.0, 2.05, -21.30)
	add_child(rune)
	_exit_glow = MeshInstance3D.new()
	var glow_mesh := PlaneMesh.new()
	glow_mesh.size = Vector2(3.2, 2.8)
	_exit_glow.mesh = glow_mesh
	var glow_material := _material(Color(0.45, 0.72, 0.32, 0.0), Color(0.2, 0.6, 0.12), 0.4)
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.emission_enabled = true
	glow_material.emission = Color(0.25, 0.72, 0.12)
	glow_material.emission_energy_multiplier = 1.1
	_exit_glow.material_override = glow_material
	_exit_glow.position = Vector3(0.0, 1.55, -21.27)
	_exit_glow.visible = false
	add_child(_exit_glow)
	_door_blocker = StaticBody3D.new()
	_door_blocker.name = "LockedExitBarrier"
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(3.5, 3.0, 0.55)
	blocker_shape.shape = blocker_box
	blocker_shape.position = Vector3(0.0, 1.5, -21.2)
	_door_blocker.add_child(blocker_shape)
	add_child(_door_blocker)


func _build_spawn_marker() -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.72
	ring_mesh.outer_radius = 0.82
	ring_mesh.rings = 4
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	var material := _material(Color(0.55, 0.32, 0.12, 0.7), Color(0.34, 0.12, 0.02), 0.6)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.48, 0.19, 0.035)
	ring.material_override = material
	ring.position = Vector3(0.0, 0.05, 12.0)
	add_child(ring)
	_add_box("ArrivalStoneA", Vector3(1.0, 0.18, 0.55), Vector3(-1.4, 0.05, 12.0), _material(Color(0.30, 0.24, 0.18), Color(0.02, 0.01, 0.01), 1.0), false)
	_add_box("ArrivalStoneB", Vector3(1.0, 0.18, 0.55), Vector3(1.4, 0.05, 12.0), _material(Color(0.30, 0.24, 0.18), Color(0.02, 0.01, 0.01), 1.0), false)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RoomCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_ortho_size
	_camera.near = 0.1
	_camera.far = 160.0
	var pitch := deg_to_rad(camera_pitch)
	_camera.position = Vector3(0.0, sin(pitch) * 24.0 + 1.45, cos(pitch) * 24.0)
	_camera.current = true
	add_child(_camera)
	_camera.look_at(_camera_target, Vector3.UP)
	_camera_home = _camera.position


func _create_lighting() -> void:
	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moonlight.light_color = Color(0.62, 0.56, 0.50)
	moonlight.light_energy = 0.66
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_max_distance = 48.0
	add_child(moonlight)


func _create_combat_feedback() -> void:
	var feedback := Node3D.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(FEEDBACK_SCRIPT)
	add_child(feedback)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as FairytalePlayer
	_player.name = "Player"
	_player.position = Vector3(0.0, 0.0, 11.7)
	add_child(_player)


func _spawn_enemies() -> void:
	var spawn_points := [
		Vector3(-11.0, 0.0, 8.0), Vector3(11.0, 0.0, 7.0),
		Vector3(-13.0, 0.0, 0.0), Vector3(13.0, 0.0, -1.0),
		Vector3(-8.0, 0.0, -9.5), Vector3(8.0, 0.0, -10.0),
		Vector3(0.0, 0.0, -4.0), Vector3(0.0, 0.0, 3.0),
	]
	var count := 5 + _room_number
	spawn_points.resize(count)
	for index in range(count):
		var x: float = [-12.0, 11.0, -7.0, 8.0, -13.0, 13.0, 0.0, -4.0][index]
		var z: float = [7.0, 6.0, 0.0, -1.0, -8.0, -9.0, -4.0, 2.0][index]
		spawn_points[index] = Vector3(x, 0.0, z)
	_total_enemies = spawn_points.size()
	_remaining_enemies = _total_enemies
	for index in range(spawn_points.size()):
		var enemy := CharacterBody3D.new()
		enemy.name = "CorruptedVillager_%02d" % (index + 1)
		enemy.set_script(ENEMY_SCRIPT)
		enemy.position = spawn_points[index]
		add_child(enemy)
		enemy.connect("defeated", _on_enemy_defeated)


func _spawn_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "BattleHUD"
	hud.set_script(HUD_SCRIPT)
	add_child(hud)


func _on_enemy_defeated(_enemy: Node) -> void:
	_remaining_enemies = maxi(0, _remaining_enemies - 1)
	if _remaining_enemies <= 0:
		_open_exit_gate()


func _open_exit_gate() -> void:
	if _door_open:
		return
	_door_open = true
	if is_instance_valid(_door_blocker):
		_door_blocker.queue_free()
	if _room_number < 3:
		var wall_nodes := ["NorthWallLeft_Collision", "NorthWallRight_Collision", "NorthHeader_Collision"]
		for node_name in wall_nodes:
			var wall_body := get_node_or_null(node_name)
			if wall_body != null:
				wall_body.queue_free()
	if is_instance_valid(_exit_glow):
		_exit_glow.visible = true


func _enter_next_area() -> void:
	_transitioning = true
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null and is_instance_valid(_player):
		run_state.carried_health = _player.health
		run_state.cleared_rooms = _room_number
	if _room_number < 3:
		get_tree().change_scene_to_file(HALL_SCENE)
	else:
		get_tree().change_scene_to_file(BOSS_SCENE)


func _add_wall(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	_add_box(node_name, size, at, material, true)


func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	item.position = at
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size.y > 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	if solid:
		var body := StaticBody3D.new()
		body.name = "%s_Collision" % node_name
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		body.position = at
		body.add_child(collision)
		add_child(body)
	return item


func _material(albedo: Color, emission: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emission.r + emission.g + emission.b > 0.0001:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.75
	return material
