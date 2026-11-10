extends "res://scripts/corrupted_villager.gd"

@export var role := 0
var _nav_timer := 0.0

func _ready() -> void:
	if role > 0: attack_range = 7.0
	super._ready()
	if is_instance_valid(_target):
		var offset := position - _target.position
		_orbit_angle = atan2(offset.z, offset.x)
	_tactic_left = randf_range(0.1, 0.5)
var _path_direction := Vector3.ZERO

func _get_move_direction(direction: Vector3) -> Vector3:
	_nav_timer -= get_physics_process_delta_time()
	if _nav_timer <= 0.0 and is_instance_valid(_target):
		_nav_timer = 0.18
		var room := get_parent().get_parent()
		_path_direction = room.get("_art").call("path_direction", global_position, _target.global_position)
	return _path_direction if _path_direction.length_squared() > 0.01 else direction

func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	_body_material = _material(Color(0.18, 0.24, 0.28), 0.95)
	_add_box("EmptySuit", Vector3(0.8, 0.95, 0.42), Vector3(0, 0.95, 0), _body_material)
	_add_box("LeftLeg", Vector3(0.23, 0.55, 0.25), Vector3(-0.23, 0.28, 0), _body_material)
	_add_box("RightLeg", Vector3(0.23, 0.55, 0.25), Vector3(0.23, 0.28, 0), _body_material)
	_add_box("LabelFace", Vector3(0.54, 0.5, 0.45), Vector3(0, 1.65, 0), _material(Color(0.69, 0.65, 0.54), 1.0))
	var label := Label3D.new()
	label.text = ["近战", "远程", "魔法"][role]
	label.position = Vector3(0, 2.3, 0)
	label.font_size = 32
	label.pixel_size = 0.014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_root.add_child(label)
	_telegraph = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.5, 0.035, 2.5)
	_telegraph.mesh = mesh
	var material := _material(Color(0.8, 0.12, 0.08, 0.5), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph.material_override = material
	_telegraph.position.y = 0.05
	_telegraph.visible = false
	_visual_root.add_child(_telegraph)



var decision := "接近"
var _recover := 0.0
var _retreating := false
var _strafe_sign := 1.0
var _strafe_left := 0.0
var _cast_point := Vector3.ZERO
var _magic_mark: Node3D
var _tactical_goal := Vector3.ZERO
var _goal_valid := false
var _relocating := false
var _tactic_left := 0.0
var _goal_target_origin := Vector3.ZERO
var _orbit_angle := 0.0
var _route: Array[Vector3] = []
var _route_index := 0
var _route_goal := Vector3.INF

func _physics_process(delta: float) -> void:
	if _dead or get_tree().paused: return
	if _hit_pause_left > 0.0:
		_hit_pause_left = maxf(0, _hit_pause_left - delta)
		velocity = Vector3.ZERO
		return
	if _card_frozen:
		velocity = Vector3.ZERO
		return
	if not is_instance_valid(_target) or _target.health <= 0:
		decision = "待机"
		velocity = Vector3.ZERO
		return
	_elapsed += delta
	_attack_cooldown = maxf(0, _attack_cooldown - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, delta * 13)
	var offset := _target.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	var forward := offset.normalized()
	_visual_root.rotation.y = atan2(forward.x, forward.z)
	_visual_root.position.y = 0.03 + sin(_elapsed * 8) * 0.025
	var movement := Vector3.ZERO
	if _windup_timer > 0:
		decision = "攻击前摇"
		_visual_root.rotation.y = atan2(_attack_direction.x, _attack_direction.z)
		_windup_timer -= delta
		if _windup_timer <= 0:
			_perform_attack()
			_recover = 0.32 if role == 0 else 0.48
	elif _recover > 0:
		decision = "攻击后摇"
		_recover = maxf(0, _recover - delta)
	else:
		var clear := _can_see_target()
		var reach := 1.45 if role == 0 else (6.5 if role == 1 else 8.0)
		if role > 0:
			if distance < (3.0 if role == 1 else 3.8): _retreating = true
			if distance > (4.2 if role == 1 else 4.8): _retreating = false
		_tactic_left -= delta
		var frontline := role == 0 and _is_frontline()
		var can_attack := clear and distance <= reach and (role > 0 or frontline) and not _retreating
		if can_attack and _attack_cooldown <= 0:
			_begin_role_attack(forward)
		elif role > 0 and clear and not _retreating and distance >= (4.2 if role == 1 else 5.0) and distance <= reach and _tactic_left > 0 and not _relocating:
			# A useful firing position is worth keeping; don't orbit every cooldown tick.
			decision = "守住射击位置" if role == 1 else "外围等待施法"
		else:
			if not _goal_valid or _tactic_left <= 0 or _goal_target_origin.distance_to(_target.position) > 2.5 or (_retreating and _tactical_goal.distance_to(_target.position) < 4.0):
				_pick_tactical_goal(frontline)
			if role == 0:
				decision = "分侧包围" if frontline else "外圈待机"
			elif _retreating:
				decision = "后撤保持距离"
			else:
				decision = "寻找分散射击点" if role == 1 else "外围换位"
			if _goal_valid and position.distance_to(_tactical_goal) <= 0.55:
				_relocating = false
			if _goal_valid and position.distance_to(_tactical_goal) > 0.55:
				movement = _navigate(_tactical_goal, delta)

	if movement.length_squared() > 0.01:
		var separation := Vector3.ZERO
		for other in get_tree().get_nodes_in_group("minions"):
			if other == self or not is_instance_valid(other) or not other.visible: continue
			var away: Vector3 = position - other.position
			if away.length_squared() > 0.01 and away.length_squared() < 1.0:
				separation += away.normalized() * 0.45
		movement = (movement + separation.limit_length(0.6)).limit_length(1)
	velocity = movement * move_speed * _card_speed_factor + _knockback_velocity + _card_forced_velocity
	move_and_slide()

func _is_frontline() -> bool:
	var world := get_parent()
	var now := Time.get_ticks_msec()
	if not world.has_meta("frontline_until") or now >= int(world.get_meta("frontline_until")):
		var candidates: Array = []
		for other in get_tree().get_nodes_in_group("minions"):
			if is_instance_valid(other) and not other._dead and other.visible and other.get("role") == 0:
				candidates.append(other)
		candidates.sort_custom(func(a: Node3D, b: Node3D):
			var da := a.position.distance_squared_to(_target.position)
			var db := b.position.distance_squared_to(_target.position)
			return a.get_instance_id() < b.get_instance_id() if is_equal_approx(da, db) else da < db)
		var ids: Array[int] = []
		for other in candidates.slice(0, 4): ids.append(other.get_instance_id())
		world.set_meta("frontline_ids", ids)
		world.set_meta("frontline_until", now + 900)
	return get_instance_id() in world.get_meta("frontline_ids", [])

func _pick_tactical_goal(frontline: bool) -> void:
	var art: Node = get_parent().get_parent()._art
	var radius := 1.25 if frontline else (4.0 if role == 0 else (5.5 if role == 1 else 7.0))
	var options: Array = []
	var used: Dictionary = {}
	var peers: Array = []
	for other in get_tree().get_nodes_in_group("minions"):
		if other != self and is_instance_valid(other) and not other._dead and other.visible: peers.append(other)
	# Keep the approach sector inherited from spawning, rather than crossing the room.
	for i in range(16):
		var angle := _orbit_angle + i * TAU / 16
		for scale_factor in [0.9, 1.12]:
			var wanted: Vector3 = _target.position + Vector3(cos(angle), 0, sin(angle)) * radius * scale_factor
			var cell: Vector2i = art._nearest_cell(art.to_pixel(wanted))
			if used.has(cell) or art.navigation.is_point_solid(cell): continue
			used[cell] = true
			var point: Vector3 = art.to_world(art.navigation.get_point_position(cell))
			var distance := point.distance_to(_target.position)
			if frontline and (distance < 0.65 or distance > 1.4): continue
			if not frontline and absf(distance - radius) > 1.8: continue
			var score := position.distance_to(point) * 0.6 + absf(angle_difference(_orbit_angle, angle)) * 1.4
			for other in peers:
				if point.distance_to(other.position) < 1.2: score += 5.0
				if other.get("_goal_valid") == true and point.distance_to(other._tactical_goal) < 1.2: score += 9.0
			options.append({"point":point, "score":score, "cell":cell})
	options.sort_custom(func(a: Dictionary, b: Dictionary): return a.score < b.score)
	_goal_valid = false
	var start: Vector2i = art._nearest_cell(art.to_pixel(position))
	for option in options:
		var point: Vector3 = option.point
		if role > 0 and not _line_clear(point, _target.position): continue
		if art.navigation.get_id_path(start, option.cell).is_empty(): continue
		_tactical_goal = point
		_goal_valid = true
		break
	# When no firing position is reachable, hold instead of pathing into the player.
	_tactic_left = randf_range(1.6, 2.5) if role != 2 else randf_range(2.5, 3.8)
	_goal_target_origin = _target.position
	_relocating = _goal_valid and position.distance_to(_tactical_goal) > 0.55
	_nav_timer = 0.0

func _navigate(goal: Vector3, delta: float) -> Vector3:
	_nav_timer -= delta
	var art: Node = get_parent().get_parent()._art
	if _route_goal.distance_to(goal) > 0.8 or _nav_timer <= 0:
		_nav_timer = 0.7
		_route_goal = goal
		_route.clear()
		_route_index = 0
		var ids: Array[Vector2i] = art.navigation.get_id_path(art._nearest_cell(art.to_pixel(position)), art._nearest_cell(art.to_pixel(goal)))
		for i in range(1, ids.size()):
			_route.append(art.to_world(art.navigation.get_point_position(ids[i])))
		if ids.size() == 1: _route.append(goal)
	while _route_index < _route.size() and position.distance_to(_route[_route_index]) < 0.35:
		_route_index += 1
	if _route_index >= _route.size(): return Vector3.ZERO
	# Cut unnecessary grid corners only when a body-width corridor is clear.
	for ahead in range(mini(_route_index + 3, _route.size() - 1), _route_index, -1):
		if _walk_clear(position, _route[ahead]):
			_route_index = ahead
			break
	return (_route[_route_index] - position).normalized()

func _walk_clear(from: Vector3, to: Vector3) -> bool:
	var art: Node = get_parent().get_parent()._art
	var offset := to - from
	var side := Vector3(offset.z, 0, -offset.x).normalized() * 0.42
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		if not art.is_walkable(from.lerp(to, fraction)): return false
	return _line_clear(from, to) and _line_clear(from + side, to + side) and _line_clear(from - side, to - side)

func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.65, to + Vector3.UP * 0.65, 1, [get_rid(), _target.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.65, _target.global_position + Vector3.UP * 0.65, 1, [get_rid(), _target.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _begin_role_attack(direction: Vector3) -> void:
	_attack_direction = direction
	_cast_point = _target.position
	_windup_timer = [0.42, 0.55, 0.9][role]
	_attack_cooldown = randf_range(1.2, 1.8) if role == 0 else randf_range(2.0, 2.8)
	_telegraph.visible = role != 2
	if role == 2:
		_magic_mark = get_parent().get_parent()._box("MagicWarning", Vector3(1.8, 0.04, 1.8), _cast_point + Vector3.UP * 0.06, Color(0.75, 0.3, 1, 0.5))

func _perform_attack() -> void:
	_telegraph.visible = false
	if not is_instance_valid(_target): return
	if role == 0:
		var offset := _target.position - position
		if offset.length() <= attack_range + 0.35 and offset.normalized().dot(_attack_direction) > 0.2:
			_target.apply_hit(attack_damage, _attack_direction * 2)
	elif role == 1:
		var bolt := Node3D.new()
		bolt.set_script(load("res://scripts/chapter01/enemy_bolt.gd"))
		bolt.position = position + Vector3.UP * 0.65
		bolt.direction = _attack_direction
		bolt.damage = attack_damage
		get_parent().add_child(bolt)
	else:
		if is_instance_valid(_magic_mark): _magic_mark.queue_free()
		var offset := _target.position - _cast_point
		if absf(offset.x) <= 0.9 and absf(offset.z) <= 0.9:
			_target.apply_hit(attack_damage)

func _die() -> void:
	if is_instance_valid(_magic_mark): _magic_mark.queue_free()
	super._die()
