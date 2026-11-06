extends Node3D

signal cast_started(index: int)
signal cast_denied(reason: String)

const TITLES := ["雷贯光波", "余烬回信", "霜封档案", "追索火种", "逆风回廊"]
const COOLDOWNS := [6.0, 10.0, 12.0, 9.0, 14.0]
const COLORS := [Color(0.48, 0.43, 1.0), Color(1.0, 0.29, 0.08), Color(0.42, 0.88, 1.0), Color(1.0, 0.66, 0.14), Color(0.35, 0.83, 0.70)]
const RANGES := [14.0, 9.0, 8.0, 6.0, 7.0]
const GROUND_SHADER := preload("res://shaders/card_ground.gdshader")

var actor: FairytalePlayer
var cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0]
var aim_index := -1
var aim_age := 0.0
var aim_point := Vector3.ZERO
var _preview: Node3D
var _preview_line: MeshInstance3D
var _preview_area: MeshInstance3D
var _preview_arc: Array[MeshInstance3D] = []
var _recovery := 0.0
var _effects: Array[Dictionary] = []
var _transients: Array[Dictionary] = []
var _statuses: Dictionary = {}
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	actor = get_parent().get_node("Player") as FairytalePlayer

func _physics_process(delta: float) -> void:
	if actor.health <= 0.0 or bool(get_parent().get("won")):
		clear_effects()
		return
	_clock += delta
	_recovery = maxf(0.0, _recovery - delta)
	for i in range(5):
		cooldowns[i] = maxf(0.0, float(cooldowns[i]) - delta)
	_tick_statuses(delta)
	for effect in _effects.duplicate():
		if not _live(effect.node):
			_effects.erase(effect)
			continue
		effect.age += delta
		match str(effect.kind):
			"letter": _advance_letter(effect)
			"fire", "frost", "wind": _advance_zone(effect, delta)
			"embers": _advance_embers(effect, delta)
		if _live(effect.node) and float(effect.age) >= float(effect.duration):
			if effect.kind == "wind":
				_hit_area(effect.center, 3.0, 12.0, "wind")
				for target in _nearby(effect.center, 3.0):
					if target is CharacterBody3D:
						var status := _status_for(target)
						status.push_velocity = (target.global_position - (effect.center as Vector3)).normalized() * 4.0
						status.push_left = 0.2
				_burst(effect.center, COLORS[4], 12)
			_dispose(effect)
	_apply_controls()
	for transient in _transients.duplicate():
		if not _live(transient.node):
			_transients.erase(transient)
			continue
		transient.age += delta
		transient.node.position += transient.velocity * delta
		var fraction := clampf(float(transient.age) / float(transient.duration), 0.0, 1.0)
		transient.node.scale = transient.scale * (1.0 - fraction * fraction)
		if fraction >= 1.0:
			transient.node.queue_free()
			_transients.erase(transient)
	if aim_index >= 0:
		aim_age += delta
		aim_point = _mouse_ground()
		_update_preview()

func begin_aim(index: int) -> bool:
	if not _can_cast(index):
		cast_denied.emit("技能冷却中" if float(cooldowns[clampi(index, 0, 4)]) > 0.0 else "暂时无法施放")
		return false
	cancel_aim()
	aim_index = index
	aim_age = 0.0
	aim_point = _mouse_ground()
	_preview = Node3D.new()
	_preview.name = "CardAimPreview"
	add_child(_preview)
	if index == 0:
		_preview_line = _box(Vector3.ONE, Vector3.ZERO, COLORS[0], _preview)
	else:
		var diameter: float = [0.0, 4.8, 5.0, 2.6, 6.0][index]
		_preview_area = _ground(Vector3.ZERO, diameter, COLORS[index], 1.0 if index == 2 else (2.0 if index == 4 else 0.0), true)
		remove_child(_preview_area)
		_preview.add_child(_preview_area)
		if index == 1:
			for i in range(8):
				_preview_arc.append(_box(Vector3.ONE, Vector3.ZERO, COLORS[1], _preview))
	_update_preview()
	return true

func release_aim() -> bool:
	if aim_index < 0:
		return false
	var index := aim_index
	var at := _mouse_ground()
	var charge := clampf(aim_age, 0.0, 1.0)
	cancel_aim()
	return cast_at(index, at, charge)

func cancel_aim() -> void:
	aim_index = -1
	aim_age = 0.0
	if _live(_preview):
		_preview.queue_free()
	_preview = null
	_preview_line = null
	_preview_area = null
	_preview_arc.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_aim()

func _can_cast(index: int) -> bool:
	return index >= 0 and index < 5 and not get_tree().paused and actor.health > 0.0 and not bool(get_parent().get("won")) and float(cooldowns[index]) <= 0.0 and _recovery <= 0.0

func cast_at(index: int, requested: Vector3, charge: float = 0.0) -> bool:
	if not _can_cast(index):
		return false
	var at := _limited_point(requested, float(RANGES[index]))
	if index in [1, 2, 4] and not _valid_ground(at):
		cast_denied.emit("该处无法落地")
		return false
	# Preview and cast share wall clipping. A cast against an adjacent wall is invalid.
	if index != 0 and index != 3 and actor.position.distance_to(at) < 0.45 and not _clear(actor.position, requested):
		cast_denied.emit("落点被墙体阻挡")
		return false
	cooldowns[index] = float(COOLDOWNS[index])
	_recovery = 0.25
	actor.set_facing_direction((at - actor.position).normalized())
	match index:
		0: _cast_beam(requested, clampf(charge, 0.0, 1.0))
		1: _cast_letter(at)
		2: _cast_frost(at)
		3: _cast_embers(requested)
		4: _cast_wind(at)
	_play_sound(index)
	cast_started.emit(index)
	return true

func _mouse_ground() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return actor.position + Vector3(0, 0, -5)
	var mouse := get_viewport().get_mouse_position()
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return point if point != null else actor.position + Vector3(0, 0, -5)

func _limited_point(requested: Vector3, reach: float) -> Vector3:
	var direction := Vector3(requested.x - actor.position.x, 0, requested.z - actor.position.z)
	var at := actor.position + direction.limit_length(reach)
	var hit := _solid_ray(actor.position + Vector3.UP * 0.65, at + Vector3.UP * 0.65)
	if not hit.is_empty():
		at = (hit.position as Vector3) - direction.normalized() * 0.12
		at.y = 0
	return at

func _valid_ground(at: Vector3) -> bool:
	var art: Node = get_parent().get("_art")
	return art == null or bool(art.call("is_walkable", at))

func _update_preview() -> void:
	if not _live(_preview):
		return
	var at := _limited_point(aim_point, float(RANGES[aim_index]))
	if aim_index == 0:
		var direction := (aim_point - actor.position).normalized()
		var end := _limited_point(actor.position + direction * 14.0, 14.0)
		_position_line(_preview_line, actor.position + Vector3.UP * 0.06, end + Vector3.UP * 0.06, lerpf(0.45, 0.9, minf(aim_age, 1.0)))
	else:
		if aim_index == 3:
			at = actor.position
		_preview_area.position = Vector3(at.x, 0.08, at.z)
		(_preview_area.material_override as ShaderMaterial).set_shader_parameter("age", aim_age)
		var tint: Color = COLORS[aim_index] if aim_index == 3 or _valid_ground(at) else Color(1.0, 0.15, 0.2)
		(_preview_area.material_override as ShaderMaterial).set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 0.8))
		if aim_index == 1:
			var start := actor.position + Vector3.UP * 0.8
			for i in range(8):
				var t0 := i / 8.0
				var t1 := (i + 1) / 8.0
				_position_line(_preview_arc[i], start.lerp(at, t0) + Vector3.UP * sin(t0 * PI) * 2.0, start.lerp(at, t1) + Vector3.UP * sin(t1 * PI) * 2.0, 0.035)

func _position_line(node: MeshInstance3D, from: Vector3, to: Vector3, width: float) -> void:
	node.position = (from + to) * 0.5
	node.scale = Vector3(width, width, maxf(0.01, from.distance_to(to)))
	if from.distance_squared_to(to) > 0.001:
		node.look_at(to, Vector3.UP)

func _cast_beam(requested: Vector3, charge: float) -> void:
	var direction := Vector3(requested.x - actor.position.x, 0, requested.z - actor.position.z).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3(0, 0, -1)
	var start := actor.position + Vector3.UP * 0.65
	var end := start + direction * 14.0
	var solid := _solid_ray(start, end)
	if not solid.is_empty():
		end = solid.position
	var length := start.distance_to(end)
	var shape := BoxShape3D.new()
	shape.size = Vector3(lerpf(0.45, 0.9, charge), 1.0, maxf(0.1, length))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), start + direction * length * 0.5)
	query.collision_mask = 2
	var targets: Array[Node3D] = []
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target := hit.collider as Node3D
		if _valid_target(target) and not targets.has(target):
			targets.append(target)
	targets.sort_custom(func(a: Node3D, b: Node3D): return start.distance_squared_to(a.global_position) < start.distance_squared_to(b.global_position))
	for target in targets:
		if not _valid_target(target):
			continue
		_hit(target, lerpf(18.0, 36.0, charge), "thunder")
		if _live(target) and target.is_in_group("card_paper") and target.collision_layer & 2:
			end = start + direction * minf(start.distance_to(end), start.distance_to(target.global_position))
			break
	var beam := _line(start, end, lerpf(0.12, 0.27, charge), COLORS[0])
	_transient(beam, 0.28)
	_transient(_line(start, end, 0.055, Color(0.86, 0.9, 1)), 0.16)
	for i in range(5):
		var at := start.lerp(end, (i + 0.3) / 5.0)
		var side := Vector3(direction.z, 0, -direction.x) * (0.3 if i % 2 == 0 else -0.3)
		_transient(_line(at, at + direction * 0.8 + side, 0.035, COLORS[0]), 0.25)

func _cast_letter(at: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	_box(Vector3(0.58, 0.12, 0.4), Vector3.ZERO, Color(0.64, 0.4, 0.21), node)
	_box(Vector3(0.15, 0.14, 0.14), Vector3(0, 0.06, 0), COLORS[1], node)
	_effects.append({"kind":"letter", "node":node, "age":0.0, "duration":0.45, "center":at, "start":actor.position + Vector3.UP * 0.8})

func _advance_letter(effect: Dictionary) -> void:
	var t := clampf(float(effect.age) / 0.45, 0.0, 1.0)
	effect.node.position = (effect.start as Vector3).lerp(effect.center, t) + Vector3.UP * sin(t * PI) * 2.0
	effect.node.rotation.y += 0.12
	if t >= 1.0:
		_hit_area(effect.center, 2.4, 18.0, "fire")
		_burst(effect.center, COLORS[1], 16)
		_add_zone("fire", effect.center, 4.8, 3.0, COLORS[1], 0.0)
		_dispose(effect)

func _cast_frost(at: Vector3) -> void:
	_hit_area(at, 2.5, 6.0, "ice", true)
	_add_zone("frost", at, 5.0, 4.0, COLORS[2], 1.0)
	_burst(at, COLORS[2], 10)

func _cast_wind(at: Vector3) -> void:
	_add_zone("wind", at, 6.0, 2.4, COLORS[4], 2.0)

func _add_zone(kind: String, at: Vector3, size: float, duration: float, color: Color, style: float) -> void:
	var node := _ground(at, size, color, style)
	_effects.append({"kind":kind, "node":node, "center":at, "age":0.0, "duration":duration, "next_tick":0.6 if kind == "wind" else 1.0, "dwell":{}, "frozen":{}, "ribbon":0.0})

func _advance_zone(effect: Dictionary, delta: float) -> void:
	(effect.node.material_override as ShaderMaterial).set_shader_parameter("age", float(effect.age))
	var radius := 2.5 if effect.kind == "frost" else (3.0 if effect.kind == "wind" else 2.4)
	var inside := _nearby(effect.center, radius, effect.kind == "frost")
	var seen: Dictionary = {}
	for target in inside:
		var id := target.get_instance_id()
		seen[id] = true
		var status := _status_for(target)
		if effect.kind == "frost" and not target.is_in_group("card_paper"):
			status.slow_left = 0.15
			status.slow_factor = 0.8 if _elite(target) else 0.65
			effect.dwell[id] = float(effect.dwell.get(id, 0.0)) + delta
			if float(effect.dwell[id]) >= 1.6 and not effect.frozen.has(id) and not _elite(target) and not target.is_in_group("card_boss"):
				status.freeze_left = 0.8
				effect.frozen[id] = true
				_burst(target.global_position, COLORS[2], 6)
		elif effect.kind == "wind" and target is CharacterBody3D:
			var offset := (effect.center as Vector3) - target.global_position
			status.force += offset.normalized() * minf(offset.length() * 2.0, 1.0 if _elite(target) else 2.6)
	for id in effect.dwell.keys():
		if not seen.has(id):
			effect.dwell.erase(id)
	while float(effect.next_tick) <= minf(float(effect.age), float(effect.duration)) + 0.0001:
		for target in inside:
			_hit(target, 3.0 if effect.kind == "frost" else (2.0 if effect.kind == "wind" else 4.0), "ice" if effect.kind == "frost" else ("wind" if effect.kind == "wind" else "fire"))
		effect.next_tick += 0.6 if effect.kind == "wind" else 1.0
	effect.ribbon += delta
	if float(effect.ribbon) > 0.12:
		effect.ribbon = 0.0
		var angle := float(effect.age) * 4.0
		var center: Vector3 = effect.center
		var color: Color = COLORS[4] if effect.kind == "wind" else (COLORS[2] if effect.kind == "frost" else COLORS[1])
		var spark := _box(Vector3(0.18, 0.08, 0.12), center + Vector3(cos(angle) * radius * 0.75, 0.2, sin(angle) * radius * 0.75), color)
		_transient(spark, 0.45, Vector3(-sin(angle), 1.0 if effect.kind == "fire" else 0.3, cos(angle)))
	if effect.kind == "wind":
		for projectile in get_tree().get_nodes_in_group("deflectable_projectile"):
			if projectile is Node3D and projectile.global_position.distance_to(effect.center) < radius:
				_burst(projectile.global_position, COLORS[4], 5)
				projectile.queue_free()

func _cast_embers(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	var birds: Array[Dictionary] = []
	for i in range(3):
		var bird := Node3D.new()
		root.add_child(bird)
		_box(Vector3(0.26, 0.14, 0.45), Vector3.ZERO, COLORS[3], bird)
		_box(Vector3(0.65, 0.035, 0.17), Vector3(0, 0, 0.04), Color(1, 0.42, 0.1), bird)
		birds.append({"node":bird, "target":null, "launched":false, "done":false, "flight":0.0, "retargeted":false})
	_effects.append({"kind":"embers", "node":root, "age":0.0, "duration":5.0, "center":at, "birds":birds, "next_launch":0.0})

func _advance_embers(effect: Dictionary, delta: float) -> void:
	var remaining := 0
	for i in range(effect.birds.size()):
		var bird: Dictionary = effect.birds[i]
		if bird.done:
			continue
		remaining += 1
		var node: Node3D = bird.node
		if not bird.launched:
			node.global_position = actor.global_position + Vector3(cos(_clock * 2.5 + i * TAU / 3.0) * 1.0, 1.0, sin(_clock * 2.5 + i * TAU / 3.0) * 1.0)
			if float(effect.age) >= float(effect.next_launch):
				var target := _ember_target(effect.center)
				if target != null:
					bird.target = weakref(target)
					bird.launched = true
					effect.next_launch = float(effect.age) + 0.22
			continue
		bird.flight += delta
		var target: Node3D = bird.target.get_ref() if bird.target != null else null
		if not _valid_target(target) and not bird.retargeted:
			target = _ember_target(effect.center)
			bird.target = weakref(target) if target != null else null
			bird.retargeted = true
		if not _valid_target(target) or float(bird.flight) > 1.8:
			bird.done = true
			node.queue_free()
			continue
		var goal := _target_point(target)
		var old := node.global_position
		var next := old.move_toward(goal, delta * 11.0)
		var query := PhysicsRayQueryParameters3D.create(old, next, 3, [actor.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() or next.distance_to(goal) < 0.28:
			var victim: Node3D = hit.collider as Node3D if not hit.is_empty() else target
			_hit(victim, 10.0, "fire")
			_burst(next, COLORS[3], 5)
			bird.done = true
			node.queue_free()
		else:
			node.global_position = next
			if next.distance_squared_to(goal) > 0.001:
				node.look_at(goal)
	if remaining == 0:
		_dispose(effect)

func _ember_target(preferred: Vector3) -> Node3D:
	var best: Node3D
	var score := INF
	for target in _targets():
		if target.global_position.distance_to(actor.global_position) > 6.0 or not _clear(actor.global_position, target.global_position):
			continue
		var value := target.global_position.distance_squared_to(preferred) + (100.0 if target.is_in_group("card_paper") else 0.0)
		if value < score:
			score = value
			best = target
	return best

func _hit_area(at: Vector3, radius: float, damage: float, element: String, square: bool = false) -> void:
	for target in _nearby(at, radius, square):
		_hit(target, damage, element)

func _nearby(at: Vector3, radius: float, square: bool = false) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for target in _targets():
		var offset := target.global_position - at
		offset.y = 0.0
		if target.is_in_group("card_paper"):
			var half_extent: Vector3 = target.get("extent") * 0.5
			offset.x = signf(offset.x) * maxf(0.0, absf(offset.x) - half_extent.x)
			offset.z = signf(offset.z) * maxf(0.0, absf(offset.z) - half_extent.z)
		var within := absf(offset.x) <= radius and absf(offset.z) <= radius if square else offset.length() <= radius
		if within and _clear(at, target.global_position):
			found.append(target)
	return found

func _hit(target: Node3D, amount: float, element: String) -> void:
	if not _valid_target(target) or bool(get_parent().get("won")):
		return
	var status := _status_for(target)
	var bonus := 0.0
	if float(status.reaction_lock) <= 0.0:
		if element == "fire" and float(status.ice) > 0.0:
			bonus = amount * 0.45
			status.ice = 0.0
			status.freeze_left = 0.0
		elif element == "thunder" and (float(status.ice) > 0.0 or float(status.fire) > 0.0):
			bonus = 6.0
		elif element == "wind" and (float(status.fire) > 0.0 or float(status.ice) > 0.0):
			bonus = 3.0
		if bonus > 0.0:
			status.reaction_lock = 1.0
			_burst(target.global_position, Color(0.88, 0.83, 1), 6)
	if status.has(element):
		status[element] = 3.0
	var position_before := target.global_position
	target.call("receive_hit", amount + bonus, Vector3.ZERO, position_before + Vector3.UP * 0.6)
	var feedback := get_parent().get_node_or_null("CombatFeedback")
	if feedback != null:
		feedback.call("_spawn_damage_number", amount + bonus, position_before + Vector3.UP * 0.6)

func _status_for(target: Node3D) -> Dictionary:
	var id := target.get_instance_id()
	if not _statuses.has(id):
		_statuses[id] = {"target":weakref(target), "fire":0.0, "ice":0.0, "thunder":0.0, "wind":0.0, "reaction_lock":0.0, "slow_left":0.0, "slow_factor":1.0, "freeze_left":0.0, "force":Vector3.ZERO, "push_velocity":Vector3.ZERO, "push_left":0.0, "marker":null}
	return _statuses[id]

func _tick_statuses(delta: float) -> void:
	for id in _statuses.keys():
		var status: Dictionary = _statuses[id]
		if not _valid_target(status.target.get_ref()):
			if _live(status.marker):
				status.marker.queue_free()
			_statuses.erase(id)
			continue
		for key in ["fire", "ice", "thunder", "wind", "reaction_lock", "slow_left", "freeze_left", "push_left"]:
			status[key] = maxf(0.0, float(status[key]) - delta)
		status.force = Vector3.ZERO

func _apply_controls() -> void:
	for status in _statuses.values():
		var target: Node3D = status.target.get_ref()
		if _valid_target(target) and target.has_method("set_card_control"):
			var forced: Vector3 = status.force
			if float(status.push_left) > 0.0:
				forced += status.push_velocity
			target.call("set_card_control", float(status.slow_factor) if float(status.slow_left) > 0.0 else 1.0, float(status.freeze_left) > 0.0, forced.limit_length(4.0))
			if float(status.freeze_left) > 0.0:
				if not _live(status.marker):
					status.marker = _box(Vector3(0.95, 1.8, 0.85), target.global_position + Vector3.UP * 0.9, Color(0.4, 0.85, 1.0, 0.28))
				status.marker.position = target.global_position + Vector3.UP * 0.9
			elif _live(status.marker):
				status.marker.queue_free()
				status.marker = null

func _elite(target: Node3D) -> bool:
	return target.is_in_group("card_boss") or (target is CorruptedVillager and target.max_health > 60.0)

func _valid_target(target: Node) -> bool:
	return _live(target) and target is CollisionObject3D and target.has_method("receive_hit") and (target.collision_layer & 2) != 0

func _targets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for target in get_tree().get_nodes_in_group("card_targets"):
		if _valid_target(target):
			result.append(target as Node3D)
	return result

func _target_point(target: Node3D) -> Vector3:
	var at := target.global_position
	at.y = 0.65
	return at

func _clear(from: Vector3, to: Vector3) -> bool:
	return _solid_ray(Vector3(from.x, 0.65, from.z), Vector3(to.x, 0.65, to.z)).is_empty()

func _solid_ray(from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.0001:
		return {}
	var ignored: Array[RID] = [actor.get_rid()]
	for paper in get_tree().get_nodes_in_group("card_paper"):
		if _live(paper):
			ignored.append(paper.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, ignored)
	return get_world_3d().direct_space_state.intersect_ray(query)

func clear_effects() -> void:
	cancel_aim()
	for status in _statuses.values():
		var target: Node = status.target.get_ref()
		if _live(target) and target.has_method("set_card_control"):
			target.call("set_card_control", 1.0, false, Vector3.ZERO)
	_statuses.clear()
	for child in get_children():
		child.queue_free()
	_effects.clear()
	_transients.clear()

func reset_cooldowns() -> void:
	for i in range(5):
		cooldowns[i] = 0.0
	_recovery = 0.0

func _live(node: Object) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()

func _dispose(effect: Dictionary) -> void:
	if _live(effect.node):
		effect.node.queue_free()
	_effects.erase(effect)

func _ground(at: Vector3, size: float, color: Color, style: float, preview: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	node.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("tint", Color(color.r, color.g, color.b, 0.8))
	material.set_shader_parameter("style", style)
	material.set_shader_parameter("preview", preview)
	node.material_override = material
	node.position = Vector3(at.x, 0.08, at.z)
	add_child(node)
	return node

func _line(from: Vector3, to: Vector3, width: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := _box(Vector3(width, width, maxf(0.01, from.distance_to(to))), (from + to) * 0.5, color, parent)
	if from.distance_squared_to(to) > 0.001:
		node.look_at(to, Vector3.UP)
	return node

func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.25
	node.material_override = material
	node.position = at
	(parent if parent != null else self).add_child(node)
	return node

func _transient(node: Node3D, duration: float, velocity: Vector3 = Vector3.ZERO) -> void:
	_transients.append({"node":node, "age":0.0, "duration":duration, "velocity":velocity, "scale":node.scale})

func _burst(at: Vector3, color: Color, count: int) -> void:
	for i in range(count):
		var angle := i * TAU / count
		var node := _box(Vector3(0.10, 0.08, 0.26), at + Vector3.UP * 0.3, color)
		node.rotation.y = angle
		_transient(node, 0.45, Vector3(cos(angle) * 2.5, 1.3, sin(angle) * 2.5))

func _play_sound(index: int) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load("res://assets/audio/swing.wav" if index in [0, 4] else "res://assets/audio/hit_heavy.wav")
	sound.position = actor.position
	sound.pitch_scale = [1.45, 0.8, 1.75, 1.2, 0.7][index]
	sound.volume_db = -16.0
	sound.bus = "SFX"
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
