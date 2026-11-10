extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud.close_dialog()
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	room.player.position = Vector3(0, 0, 2)
	room.player._invulnerability_timer = 100
	for target in get_nodes_in_group("card_targets"): target.queue_free()
	await process_frame
	var points: Array[Vector3] = []
	for y in range(32):
		for x in range(48):
			if room._art.navigation.is_point_solid(Vector2i(x,y)): continue
			var point: Vector3 = room._art.to_world(room._art.navigation.get_point_position(Vector2i(x,y)))
			if point.distance_to(room.player.position) > 5 and point.distance_to(room.player.position) < 10:
				points.append(point)
	var enemies: Array[Node] = []
	for i in range(24):
		var enemy := CharacterBody3D.new()
		enemy.set_script(load("res://scripts/chapter01/office_echo.gd"))
		enemy.role = i % 3
		enemy.max_health = 1000
		enemy.position = points[i * points.size() / 24]
		room.world.add_child(enemy)
		enemies.append(enemy)
	await physics_frame
	await physics_frame
	var front_count := 0
	for enemy in enemies:
		if enemy.role == 0 and enemy._is_frontline(): front_count += 1
		enemy._pick_tactical_goal(enemy.role == 0 and enemy._is_frontline())
		if enemy._goal_valid:
			var distance: float = enemy._tactical_goal.distance_to(room.player.position)
			if enemy.role > 0: assert(distance >= 3.5, "Ranged goals stay outside melee crowd")
			if enemy.role == 0 and not enemy._is_frontline(): assert(distance >= 2.1, "Reserve melee holds an outer ring")
	assert(front_count == 4, "Only four melee are assigned to the front")
	var shooter: Node = enemies[1]
	shooter.position = Vector3(0, 0, -3)
	shooter._tactic_left = 1.5
	shooter._attack_cooldown = 1.0
	shooter._retreating = false
	shooter._relocating = false
	shooter.set_physics_process(false)
	await physics_frame
	await physics_frame
	shooter._physics_process(0.016)
	assert(shooter.decision == "守住射击位置" and shooter.velocity.length() < 0.01, "Shooter holds a useful firing position")
	var goal: Vector3 = enemies[2]._tactical_goal
	for i in range(90): await physics_frame
	assert(is_instance_valid(enemies[2]))
	room.queue_free()
	await process_frame
	print("PASS spacing: four frontline melee, reserve ring, ranged outer goals, stable firing hold and live group navigation")
	quit()
