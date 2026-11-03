extends CharacterBody3D
class_name FairytalePlayer

signal attack_requested
signal health_changed(current: float, maximum: float)

const WALK_ATLAS_PATH := "res://assets/player/pilgrim_walk_atlas.png"
const IDLE_STRIP_PATH := "res://assets/player/pilgrim_idle_strip.png"
const ACTION_ATLAS_PATH := "res://assets/player/pilgrim_action_atlas.png"
const PLAYER_HEIGHT := 1.60
const ATTACK_DATA_PATHS := ["res://resources/attacks/light_1.tres", "res://resources/attacks/light_2.tres", "res://resources/attacks/light_3.tres"]

@export_range(1.0, 8.0, 0.1) var move_speed := 4.25
@export_range(0.1, 0.5, 0.01) var dodge_duration := 0.34
@export_range(0.2, 2.0, 0.01) var dodge_cooldown := 1.05
@export_range(0.0, 0.4, 0.01) var dodge_invulnerability := 0.22
@export_range(5.0, 14.0, 0.1) var dodge_speed := 9.2
@export var max_health := 100.0
@export_range(1.0, 100.0, 1.0) var beam_damage := 34.0
@export_range(4.0, 24.0, 0.5) var beam_range := 18.0

@onready var sprite: AnimatedSprite3D = $Visual/Sprite
@onready var contact_shadow: MeshInstance3D = $ContactShadow

var _frames := SpriteFrames.new()
var _facing := Vector3(0.0, 0.0, 1.0)
var _dodge_direction := Vector3(0.0, 0.0, 1.0)
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _invulnerability_timer := 0.0
var _attack_locked := false
var _dead := false
var health := 100.0
var _arena: Node
var _attack_data: Array[AttackData] = []
var _attack_stage := -1
var _attack_elapsed := 0.0
var _attack_hit_targets: Dictionary = {}
var _combo_buffered := false
var _attack_direction := Vector3(0.0, 0.0, 1.0)
var _feedback: CombatFeedback
var _selected_card_index := 0
var _beam_charging := false
var _beam_preview: Node3D

var is_invulnerable: bool:
	get:
		return _invulnerability_timer > 0.0


func _ready() -> void:
	add_to_group("player")
	var run_state := get_node_or_null("/root/RunState")
	var selected_buff: int = run_state.selected_buff if run_state != null else -1
	health = max_health
	if selected_buff == 2:
		max_health += 25.0
		health = max_health
	elif selected_buff == 1:
		dodge_cooldown *= 0.8
	if run_state != null and run_state.carried_health > 0.0:
		health = minf(run_state.carried_health, max_health)
		run_state.carried_health = -1.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_setup_contact_shadow()
	_build_sprite_frames()
	sprite.sprite_frames = _frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = PLAYER_HEIGHT / 313.5
	sprite.offset = Vector2(-313.5 * 0.5, 0.0)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.animation_finished.connect(_on_animation_finished)
	_arena = get_parent()
	_feedback = get_node_or_null("CombatFeedback") as CombatFeedback
	if _feedback == null:
		_feedback = get_parent().get_node_or_null("CombatFeedback") as CombatFeedback
	for path in ATTACK_DATA_PATHS:
		var attack := (load(path) as AttackData).duplicate(true) as AttackData
		if selected_buff == 0:
			attack.damage *= 1.2
		_attack_data.append(attack)
	_play_directional("idle", _facing)
	_update_camera_target()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)
	if _attack_stage >= 0:
		_update_attack(delta)
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = not get_tree().paused
	if get_tree().paused:
		velocity = Vector3.ZERO
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()
		_facing = move_direction
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		if _attack_stage < 0 or _attack_elapsed >= _attack_data[_attack_stage].dodge_cancel_open:
			if _attack_stage >= 0:
				_cancel_attack()
			_begin_dodge(move_direction)
	if Input.is_action_just_pressed("attack"):
		if _attack_stage < 0 and not _attack_locked:
			_begin_attack()
		elif _attack_stage >= 0 and _attack_stage < 2:
			var data := _attack_data[_attack_stage]
			if _attack_elapsed >= data.combo_buffer_open and _attack_elapsed <= data.total_duration() - data.combo_buffer_close:
				_combo_buffered = true
	if _dodge_timer > 0.0:
		velocity.x = _dodge_direction.x * dodge_speed
		velocity.z = _dodge_direction.z * dodge_speed
	else:
		var target_velocity := move_direction * move_speed
		var rate := 21.0 if move_direction.length_squared() > 0.0 else 28.0
		velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	if _arena != null and _arena.has_method("clamp_to_arena"):
		global_position = _arena.call("clamp_to_arena", global_position, 0.58)
	_update_animation(move_direction)
	_update_camera_target()


func _process(_delta: float) -> void:
	if not _beam_charging or get_tree().paused:
		return
	var aim_direction := _get_mouse_aim_direction()
	if aim_direction.length_squared() > 0.001:
		_facing = aim_direction
		if not _attack_locked:
			_play_directional("idle", _facing)
	if is_instance_valid(_beam_preview):
		_update_beam_visual(_beam_preview, global_position + Vector3.UP * 0.78 + aim_direction * 0.48, aim_direction, beam_range)


func set_selected_card(index: int) -> void:
	_selected_card_index = clampi(index, 0, 4)


func begin_beam_charge() -> void:
	if _dead or _selected_card_index != 0 or get_tree().paused or _beam_charging:
		return
	_beam_charging = true
	_beam_preview = _create_beam_visual(Color(0.31, 0.79, 1.0, 0.34), Color(0.84, 0.96, 1.0, 0.55))
	_update_beam_visual(_beam_preview, global_position + Vector3.UP * 0.78, _get_mouse_aim_direction(), beam_range)


func release_beam() -> void:
	if not _beam_charging:
		return
	_beam_charging = false
	if is_instance_valid(_beam_preview):
		_beam_preview.queue_free()
	_beam_preview = null
	if _dead or get_tree().paused:
		return
	_fire_beam()


func cancel_beam_charge() -> void:
	_beam_charging = false
	if is_instance_valid(_beam_preview):
		_beam_preview.queue_free()
	_beam_preview = null


func _fire_beam() -> void:
	var direction := _get_mouse_aim_direction()
	if direction.length_squared() < 0.001:
		return
	_facing = direction
	var start := global_position + Vector3.UP * 0.78 + direction * 0.48
	var end := start + direction * beam_range
	var query := PhysicsRayQueryParameters3D.create(start, end, 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var beam_length := beam_range
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", end)
		beam_length = maxf(0.65, start.distance_to(hit_position))
		var target := hit.get("collider") as Node
		if target != null and target.has_method("receive_hit"):
			target.call("receive_hit", beam_damage, direction * 2.5, hit_position)
			if _feedback != null:
				_feedback.register_ability_hit(target as Node3D, beam_damage, hit_position, direction)
	var visual := _create_beam_visual(Color(0.29, 0.76, 1.0, 0.9), Color(0.95, 0.99, 1.0, 1.0))
	_update_beam_visual(visual, start, direction, beam_length)
	var outer := visual.get_node("Outer") as MeshInstance3D
	var core := visual.get_node("Core") as MeshInstance3D
	var outer_material := outer.material_override as StandardMaterial3D
	var core_material := core.material_override as StandardMaterial3D
	var tween := create_tween()
	tween.tween_method(_fade_beam.bind(outer_material, core_material), 1.0, 0.0, 0.26)
	tween.tween_callback(visual.queue_free)


func _get_mouse_aim_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _facing
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ground_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if ground_point == null:
		var flattened := Vector3(ray_direction.x, 0.0, ray_direction.z)
		return flattened.normalized() if flattened.length_squared() > 0.001 else _facing
	var direction := Vector3(ground_point.x - global_position.x, 0.0, ground_point.z - global_position.z)
	return direction.normalized() if direction.length_squared() > 0.001 else _facing


func _create_beam_visual(outer_color: Color, core_color: Color) -> Node3D:
	var beam := Node3D.new()
	beam.name = "LightWave"
	beam.set_meta("persistent", true)
	get_parent().add_child(beam)
	for part in [["Outer", outer_color, 0.34], ["Core", core_color, 0.12]]:
		var segment := MeshInstance3D.new()
		segment.name = part[0]
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		segment.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = part[1]
		material.emission_enabled = true
		material.emission = Color(part[1].r, part[1].g, part[1].b)
		material.emission_energy_multiplier = 2.6 if part[0] == "Core" else 1.8
		material.no_depth_test = false
		segment.material_override = material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.add_child(segment)
	return beam


func _update_beam_visual(beam: Node3D, start: Vector3, direction: Vector3, length: float) -> void:
	if not is_instance_valid(beam):
		return
	var safe_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if safe_direction.length_squared() < 0.001:
		safe_direction = _facing
	var center := start + safe_direction * (length * 0.5)
	for segment_name in ["Outer", "Core"]:
		var segment := beam.get_node(segment_name) as MeshInstance3D
		segment.global_position = center
		segment.look_at(center + safe_direction, Vector3.UP)
		var width := 0.34 if segment_name == "Outer" else 0.12
		segment.scale = Vector3(width, width, length)


func _fade_beam(alpha: float, outer: StandardMaterial3D, core: StandardMaterial3D) -> void:
	var outer_color := outer.albedo_color
	outer_color.a = 0.9 * alpha
	outer.albedo_color = outer_color
	var core_color := core.albedo_color
	core_color.a = alpha
	core.albedo_color = core_color


func _begin_dodge(move_direction: Vector3) -> void:
	_dodge_direction = move_direction if move_direction.length_squared() > 0.001 else _facing
	_dodge_timer = dodge_duration
	_dodge_cooldown_timer = dodge_cooldown
	_invulnerability_timer = dodge_invulnerability
	_play_action("dodge", 13.0)


func _begin_attack() -> void:
	_start_attack(0)


func _start_attack(stage: int) -> void:
	_attack_stage = stage
	_attack_elapsed = 0.0
	_attack_hit_targets.clear()
	_combo_buffered = false
	_attack_direction = _facing.normalized()
	_attack_locked = true
	attack_requested.emit()
	var data := _attack_data[stage]
	if _feedback != null:
		_feedback.play_swing(global_position + Vector3.UP * 0.05, _attack_direction, data.reach)
	_play_action("attack", 4.0 / data.total_duration())


func _update_attack(delta: float) -> void:
	var data := _attack_data[_attack_stage]
	var previous := _attack_elapsed
	_attack_elapsed += delta
	if previous < data.windup and _attack_elapsed >= data.windup:
		_query_attack_hits(data)
	elif previous >= data.windup and previous < data.windup + data.active_duration:
		_query_attack_hits(data)
	if _attack_elapsed >= data.total_duration():
		var continue_combo := _combo_buffered and _attack_stage < 2
		var next_stage := _attack_stage + 1
		_attack_stage = -1
		_attack_locked = false
		if continue_combo:
			_start_attack(next_stage)
		else:
			_update_animation(Vector3.ZERO)


func _query_attack_hits(data: AttackData) -> void:
	var query := SphereShape3D.new()
	query.radius = data.hit_radius
	var query_params := PhysicsShapeQueryParameters3D.new()
	query_params.shape = query
	query_params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.55 + _attack_direction * data.reach)
	query_params.collision_mask = 2
	query_params.collide_with_areas = true
	query_params.collide_with_bodies = true
	var state := get_world_3d().direct_space_state
	for result in state.intersect_shape(query_params, 16):
		var target := result.get("collider") as Node
		if target == null or _attack_hit_targets.has(target.get_instance_id()):
			continue
		if target.has_method("receive_hit"):
			_attack_hit_targets[target.get_instance_id()] = true
			var direction := Vector3(_attack_direction.x, 0.0, _attack_direction.z).normalized()
			var hit_at: Vector3 = (target as Node3D).global_position + Vector3.UP * 0.55
			target.call("receive_hit", data.damage, direction * data.knockback, hit_at)
			if _feedback != null:
				_feedback.register_hit(target as Node3D, data.damage, hit_at, direction, _attack_stage == 2)


func _cancel_attack() -> void:
	_attack_stage = -1
	_attack_elapsed = 0.0
	_combo_buffered = false
	_attack_locked = false


func apply_hit(damage: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable or _dead:
		return
	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)
	velocity += knockback
	_invulnerability_timer = 0.38
	_attack_locked = true
	if health <= 0.0:
		die()
		return
	_play_action("hurt", 9.0)


func die() -> void:
	_dead = true
	velocity = Vector3.ZERO
	_attack_locked = true
	_play_action("death", 7.0)


func set_facing_direction(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return
	_facing = direction.normalized()
	_play_directional("idle", _facing)


func _build_sprite_frames() -> void:
	var walk_atlas := load(WALK_ATLAS_PATH) as Texture2D
	var idle_atlas := load(IDLE_STRIP_PATH) as Texture2D
	var action_atlas := load(ACTION_ATLAS_PATH) as Texture2D
	var walk_cell := Vector2(walk_atlas.get_width() / 4.0, walk_atlas.get_height() / 4.0)
	var action_cell := Vector2(action_atlas.get_width() / 4.0, action_atlas.get_height() / 4.0)
	var idle_cell := Vector2(idle_atlas.get_width() / 4.0, idle_atlas.get_height())
	for direction_index in range(4):
		var walk_name := _animation_name("walk", direction_index)
		_frames.add_animation(walk_name)
		_frames.set_animation_speed(walk_name, 9.0)
		_frames.set_animation_loop(walk_name, true)
		for frame_index in range(4):
			var region := Rect2(Vector2(frame_index * walk_cell.x, direction_index * walk_cell.y), walk_cell)
			_frames.add_frame(walk_name, _atlas_texture(walk_atlas, region))
		var idle_name := _animation_name("idle", direction_index)
		_frames.add_animation(idle_name)
		_frames.set_animation_speed(idle_name, 1.0)
		_frames.set_animation_loop(idle_name, true)
		var idle_region := Rect2(Vector2(direction_index * idle_cell.x, 0), idle_cell)
		_frames.add_frame(idle_name, _atlas_texture(idle_atlas, idle_region))
	for action_index in range(4):
		var action_name: String = ["attack", "dodge", "hurt", "death"][action_index]
		_frames.add_animation(action_name)
		_frames.set_animation_speed(action_name, 10.0)
		_frames.set_animation_loop(action_name, false)
		for frame_index in range(4):
			var region := Rect2(Vector2(frame_index * action_cell.x, action_index * action_cell.y), action_cell)
			_frames.add_frame(action_name, _atlas_texture(action_atlas, region))


func _atlas_texture(atlas: Texture2D, region: Rect2) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = region
	return frame


func _animation_name(prefix: String, direction_index: int) -> String:
	return "%s_%s" % [prefix, ["front", "left", "back", "right"][direction_index]]


func _direction_index(direction: Vector3) -> int:
	if absf(direction.x) > absf(direction.z):
		return 3 if direction.x > 0.0 else 1
	return 0 if direction.z >= 0.0 else 2


func _visual_row_for_direction(direction: Vector3) -> int:
	if absf(direction.x) < 0.001 and absf(direction.z) < 0.001:
		return 0
	if absf(direction.x) < 0.001:
		return 0 if direction.z >= 0.0 else 2
	if absf(direction.z) < 0.001:
		return 3 if direction.x > 0.0 else 1
	return 0 if direction.z > 0.0 else 2


func _mirror_for_direction(direction: Vector3, row: int) -> bool:
	if row == 0:
		return direction.x < 0.0
	if row == 2:
		return direction.x > 0.0
	return false


func _play_directional(prefix: String, direction: Vector3) -> void:
	var direction_index := _visual_row_for_direction(direction)
	var target_animation := _animation_name(prefix, direction_index)
	if sprite.animation != target_animation:
		if prefix == "idle":
			sprite.pixel_size = PLAYER_HEIGHT / 724.0
			sprite.offset = Vector2(-543.0 * 0.5, 0.0)
		else:
			sprite.pixel_size = PLAYER_HEIGHT / 313.5
			sprite.offset = Vector2(-313.5 * 0.5, 0.0)
		sprite.play(target_animation)
	sprite.flip_h = _mirror_for_direction(direction, direction_index)


func _play_action(action_name: String, animation_speed: float) -> void:
	if not _frames.has_animation(action_name):
		return
	_frames.set_animation_speed(action_name, animation_speed)
	# Use the action atlas's full cell proportions.
	sprite.pixel_size = PLAYER_HEIGHT / (load(ACTION_ATLAS_PATH) as Texture2D).get_height() * 4.0
	sprite.offset = Vector2(-313.5 * 0.5, 0.0)
	sprite.flip_h = _facing.x < 0.0
	sprite.play(action_name)


func _update_animation(move_direction: Vector3) -> void:
	if _dodge_timer > 0.0 or _attack_locked:
		return
	if move_direction.length_squared() > 0.001:
		var direction_index := _visual_row_for_direction(move_direction)
		var walk_name := _animation_name("walk", direction_index)
		if sprite.animation != walk_name:
			sprite.pixel_size = PLAYER_HEIGHT / 313.5
			sprite.offset = Vector2(-313.5 * 0.5, 0.0)
			sprite.play(walk_name)
			sprite.flip_h = _mirror_for_direction(move_direction, direction_index)
	else:
		_play_directional("idle", _facing)


func _on_animation_finished() -> void:
	if sprite.animation in ["dodge", "hurt"]:
		_attack_locked = false
		_update_animation(Vector3.ZERO)


func _setup_contact_shadow() -> void:
	var shadow_mesh := SphereMesh.new()
	shadow_mesh.radius = 0.34
	shadow_mesh.height = 0.06
	contact_shadow.mesh = shadow_mesh
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.018, 0.012, 0.014, 0.58)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	contact_shadow.material_override = shadow_material


func _update_camera_target() -> void:
	if _arena != null and _arena.has_method("set_camera_target"):
		_arena.call("set_camera_target", global_position)
