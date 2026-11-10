extends Node3D
## Bounded, composable projectile rules. Return retraces the actual reflected path.
var rules := {"split":false, "bounce":false, "pierce":false, "return":false, "blast":false}
var rays: Array[Dictionary] = []
var skills: Node
var shots := 0
var hits := 0
var bounces := 0
var return_hits := 0
var blasts := 0
var _serial := 0

func _ready() -> void:
	skills = get_parent().skills

func cast(at: Vector3, charge: float) -> void:
	shots += 1
	_serial += 1
	var origin: Vector3 = skills.actor.position + Vector3.UP * 0.65
	var direction := Vector3(at.x - origin.x, 0, at.z - origin.z).normalized()
	if direction.length_squared() < 0.01: direction = Vector3.FORWARD
	var config: Dictionary = rules.duplicate()
	var explosions: Dictionary = {}
	for angle in ([-0.22, 0.0, 0.22] if config.split else [0.0]):
		var head: Node3D = load("res://scripts/cards/thunder_sheet_fx.gd").new()
		head.charging = true
		add_child(head)
		head.position = origin
		head.surface.scale = Vector3(0.65, 1, 0.65)
		var ribbon: Node3D = load("res://scripts/cards/thunder_sheet_fx.gd").new()
		ribbon.looping = true
		add_child(ribbon)
		ribbon.span(origin, origin + direction, 0.6)

		rays.append({"position":origin, "direction":direction.rotated(Vector3.UP, angle), "left":22.0, "bounces":3 if config.bounce else 0, "pierces":8 if config.pierce else 1, "returning":false, "path":[origin], "seen":{}, "config":config, "explosions":explosions, "damage":lerpf(18, 38, charge) * (0.72 if config.split else 1.0), "heavy":charge >= 0.75, "head":head, "ribbon":ribbon, "age":0.0})

func _physics_process(delta: float) -> void:
	if get_parent().player.health <= 0 or get_parent().won:
		clear()
		return
	for ray in rays.duplicate():
		ray.age += delta
		if ray.age > 5.0:
			_dispose(ray)
			continue
		var before: Vector3 = ray.position
		if ray.returning:
			_move_return(ray, delta * 26.0)
		else:
			_move_out(ray, minf(delta * 26.0, ray.left))
		if not rays.has(ray): continue
		ray.head.position = ray.position
		var direction: Vector3 = ray.position - before
		if direction.length_squared() > 0.00001:
			ray.ribbon.span(ray.position - direction.normalized() * minf(1.8, direction.length() + 0.6), ray.position, 0.9 if ray.heavy else 0.6)

func _ignored(ray: Dictionary) -> Array[RID]:
	var ignored: Array[RID] = [skills.actor.get_rid()]
	for target in skills._targets():
		if ray.seen.has(target.get_instance_id()):
			ignored.append(target.get_rid())
	return ignored

func _move_out(ray: Dictionary, distance: float) -> void:
	for step in range(16):
		if distance < 0.001: break
		var from: Vector3 = ray.position
		var to: Vector3 = from + ray.direction * distance
		var query := PhysicsRayQueryParameters3D.create(from, to, 3, _ignored(ray))
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			ray.position = to
			ray.left -= distance
			ray.path.append(to)
			break
		var point: Vector3 = hit.position
		var traveled := from.distance_to(point)
		ray.left -= traveled
		distance -= traveled
		ray.position = point
		ray.path.append(point)
		var target: Node3D = hit.collider
		if skills._valid_target(target):
			_hit(ray, target, point, ray.direction)
			ray.pierces -= 1
			if ray.pierces <= 0:
				_turn(ray)
				return
			ray.position += ray.direction * 0.03
			ray.left -= 0.03
			distance = maxf(0, distance - 0.03)
		else:
			if ray.bounces <= 0:
				_turn(ray)
				return
			ray.bounces -= 1
			bounces += 1
			ray.direction = (ray.direction as Vector3).bounce(hit.normal).normalized()
			ray.position += (hit.normal as Vector3) * 0.035
			ray.path.append(ray.position)
			ray.left -= 0.035
			distance = maxf(0, distance - 0.035)
			skills._burst(point, Color(0.55, 0.8, 1), 5)
	if ray.left <= 0.01: _turn(ray)

func _turn(ray: Dictionary) -> void:
	if ray.config["return"] and not ray.returning:
		ray.returning = true
		ray.pierces = 8 if ray.config.pierce else 1
		ray.seen.clear()
		# Remove duplicate end points so return never stalls at the collision surface.
		while not ray.path.is_empty() and ray.position.distance_to(ray.path.back()) < 0.05:
			ray.path.pop_back()
	else:
		_dispose(ray)

func _move_return(ray: Dictionary, distance: float) -> void:
	for step in range(32):
		if ray.path.is_empty():
			_dispose(ray)
			return
		if distance <= 0: return
		var goal: Vector3 = ray.path.back()
		var from: Vector3 = ray.position
		var next := from.move_toward(goal, distance)
		# Outgoing vertices already respect walls. Only query actors along retraced segments.
		for collision in range(12):
			var query := PhysicsRayQueryParameters3D.create(from, next, 2, _ignored(ray))
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			if skills._valid_target(hit.collider):
				_hit(ray, hit.collider, hit.position, (next - from).normalized())
				ray.pierces -= 1
				if ray.pierces <= 0:
					_dispose(ray)
					return
			else: break
		var traveled := from.distance_to(next)
		distance -= traveled
		ray.position = next
		if next.distance_to(goal) < 0.001:
			ray.path.pop_back()
		else: return

func _hit(ray: Dictionary, target: Node3D, at: Vector3, direction: Vector3) -> void:
	var id := target.get_instance_id()
	if ray.seen.has(id): return
	ray.seen[id] = true
	hits += 1
	if ray.returning: return_hits += 1
	skills._hit(target, ray.damage, "thunder")
	get_parent().get_node("CombatFeedback").rule_impact(target, at, direction, ray.heavy)
	if ray.config.blast and not ray.explosions.has(id):
		ray.explosions[id] = true
		blasts += 1
		var ring: MeshInstance3D = skills._ground(Vector3(at.x, 0.04, at.z), 3.2, Color(0.6, 0.72, 1), 0)
		skills._transient(ring, 0.22)
		skills._burst(at, Color(0.6, 0.72, 1), 10)
		for other in skills._nearby(at, 1.6):
			if other != target:
				# Splash is terminal damage, never recursively emits new projectiles/explosions.
				skills._hit(other, ray.damage * 0.45, "thunder")

func _dispose(ray: Dictionary) -> void:
	ray.head.queue_free()
	ray.ribbon.queue_free()
	rays.erase(ray)

func clear() -> void:
	for ray in rays.duplicate(): _dispose(ray)


func preview(at: Vector3) -> void:
	var lines: Array[Vector3] = []
	var start: Vector3 = skills.actor.position + Vector3.UP * 0.65
	var forward := Vector3(at.x - start.x, 0, at.z - start.z).normalized()
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	for angle in ([-0.22, 0.0, 0.22] if rules.split else [0.0]):
		var direction := forward.rotated(Vector3.UP, angle)
		var from := start
		var remaining := 22.0
		for reflection in range(4 if rules.bounce else 1):
			var query := PhysicsRayQueryParameters3D.create(from, from + direction * remaining, 1 if rules.pierce else 3, [skills.actor.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			var end: Vector3 = hit.position if not hit.is_empty() else from + direction * remaining
			lines.append(from)
			lines.append(end)
			remaining -= from.distance_to(end)
			if hit.is_empty() or skills._valid_target(hit.collider) or remaining < 0.01: break
			direction = direction.bounce(hit.normal).normalized()
			from = end + (hit.normal as Vector3) * 0.035
	while skills._preview_arc.size() < lines.size() / 2:
		skills._preview_arc.append(skills._box(Vector3.ONE, Vector3.ZERO, Color(0.42, 0.62, 1, 0.3), skills._preview))
	skills._preview_line.visible = false
	for i in range(skills._preview_arc.size()):
		var line: MeshInstance3D = skills._preview_arc[i]
		line.visible = i * 2 < lines.size()
		if line.visible:
			skills._position_line(line, lines[i * 2], lines[i * 2 + 1], 0.035)
