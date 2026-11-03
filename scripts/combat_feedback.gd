extends Node3D
class_name CombatFeedback

const SWING_SOUND := "res://assets/audio/swing.wav"
const LIGHT_HIT_SOUND := "res://assets/audio/hit_light.wav"
const HEAVY_HIT_SOUND := "res://assets/audio/hit_heavy.wav"

var _hit_stop_running := false
var _swing_stream: AudioStream
var _light_stream: AudioStream
var _heavy_stream: AudioStream


func _ready() -> void:
	_swing_stream = load(SWING_SOUND)
	_light_stream = load(LIGHT_HIT_SOUND)
	_heavy_stream = load(HEAVY_HIT_SOUND)


func play_swing(at: Vector3, direction: Vector3, reach: float) -> void:
	_spawn_sound(_swing_stream, at, -12.0)
	_spawn_slash(at, direction, reach)


func register_hit(target: Node3D, damage: float, at: Vector3, direction: Vector3, heavy: bool = false) -> void:
	_spawn_hit_particles(at, heavy)
	_spawn_sound(_heavy_stream if heavy else _light_stream, at, -7.0 if heavy else -12.0)
	_spawn_damage_number(damage, at)
	_spawn_slash(at, direction, 0.72 if heavy else 0.55, true)
	var arena := get_parent()
	if arena.has_method("set_camera_shake"):
		arena.call("set_camera_shake", 0.12 if heavy else 0.065)
	_trigger_hit_stop(0.075 if heavy else 0.048)


func register_ability_hit(target: Node3D, damage: float, at: Vector3, _direction: Vector3) -> void:
	## Ability hit feedback without the melee sweep arc.
	_spawn_hit_particles(at, true)
	_spawn_sound(_heavy_stream, at, -9.0)
	_spawn_damage_number(damage, at)
	var arena := get_parent()
	if arena.has_method("set_camera_shake"):
		arena.call("set_camera_shake", 0.09)
	_trigger_hit_stop(0.055)


func _spawn_sound(stream: AudioStream, at: Vector3, volume_db: float) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = 24.0
	player.bus = "SFX"
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.position = at
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _spawn_hit_particles(at: Vector3, heavy: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "HitSparks"
	particles.amount = 18 if heavy else 11
	particles.lifetime = 0.34 if heavy else 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = at
	particles.process_material = _spark_material(heavy)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.035 if not heavy else 0.05
	spark_mesh.height = spark_mesh.radius * 2.0
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.72, 0.24)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.28, 0.035)
	spark_material.emission_energy_multiplier = 2.4
	spark_mesh.material = spark_material
	particles.draw_pass_1 = spark_mesh
	add_child(particles)
	particles.emitting = true
	_auto_free(particles, 1.0)


func _spark_material(heavy: bool) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.8, 0.0)
	material.spread = 180.0
	material.gravity = Vector3(0.0, -5.0, 0.0)
	material.initial_velocity_min = 1.8 if not heavy else 2.8
	material.initial_velocity_max = 4.0 if not heavy else 6.0
	material.angular_velocity_min = -480.0
	material.angular_velocity_max = 480.0
	material.scale_min = 0.45
	material.scale_max = 1.25
	material.color = Color(1.0, 0.61, 0.2, 1.0)
	return material


func _spawn_damage_number(damage: float, at: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 16
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var label := Label.new()
	label.text = str(roundi(damage))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.49))
	label.add_theme_color_override("font_outline_color", Color(0.055, 0.025, 0.02))
	label.add_theme_constant_override("outline_size", 5)
	label.position = camera.unproject_position(at) - Vector2(15.0, 32.0)
	layer.add_child(label)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "position:y", label.position.y - 44.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.34)
	tween.tween_callback(layer.queue_free)


func _spawn_slash(at: Vector3, direction: Vector3, reach: float, heavy: bool = false) -> void:
	var safe_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3(0.0, 0.0, 1.0)
	var center_angle := atan2(safe_direction.x, safe_direction.z)
	var half_angle := deg_to_rad(60.0 if heavy else 48.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.53, 0.16, 0.76 if heavy else 0.56)
	material.emission_enabled = true
	material.emission = Color(0.82, 0.18, 0.025)
	material.emission_energy_multiplier = 1.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 10
	for index in range(segments):
		var angle_a := center_angle - half_angle + (half_angle * 2.0) * index / segments
		var angle_b := center_angle - half_angle + (half_angle * 2.0) * (index + 1) / segments
		var inner_a := at + Vector3(sin(angle_a) * 0.32, 0.04, cos(angle_a) * 0.32)
		var outer_a := at + Vector3(sin(angle_a) * reach, 0.04, cos(angle_a) * reach)
		var inner_b := at + Vector3(sin(angle_b) * 0.32, 0.04, cos(angle_b) * 0.32)
		var outer_b := at + Vector3(sin(angle_b) * reach, 0.04, cos(angle_b) * reach)
		for vertex in [inner_a, outer_a, inner_b, outer_a, outer_b, inner_b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	st.generate_normals()
	var slash := MeshInstance3D.new()
	slash.name = "WeaponSweepArc"
	slash.mesh = st.commit()
	slash.material_override = material
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slash)
	var tween := create_tween()
	tween.tween_method(_set_alpha.bind(material), material.albedo_color.a, 0.0, 0.14)
	tween.parallel().tween_property(slash, "scale", Vector3(1.0, 1.0, 1.12), 0.14)
	tween.tween_callback(slash.queue_free)


func _set_alpha(alpha: float, material: StandardMaterial3D) -> void:
	var color := material.albedo_color
	color.a = alpha
	material.albedo_color = color


func _trigger_hit_stop(duration: float) -> void:
	if _hit_stop_running:
		return
	_hit_stop_running = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = previous_scale
	_hit_stop_running = false


func _auto_free(node: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	if is_instance_valid(node):
		node.queue_free()
