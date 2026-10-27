extends CharacterBody3D
class_name FairytalePlayer

signal attack_requested

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
var _arena: Node
var _attack_data: Array[AttackData] = []
var _attack_stage := -1
var _attack_elapsed := 0.0
var _attack_hit_targets: Dictionary = {}
var _combo_buffered := false
var _attack_direction := Vector3(0.0, 0.0, 1.0)
var _feedback: CombatFeedback

var is_invulnerable: bool:
	get:
		return _invulnerability_timer > 0.0


func _ready() -> void:
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
	for path in ATTACK_DATA_PATHS:
		_attack_data.append(load(path) as AttackData)
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


func apply_hit(_damage: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable or _dead:
		return
	velocity += knockback
	_invulnerability_timer = 0.38
	_attack_locked = true
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
