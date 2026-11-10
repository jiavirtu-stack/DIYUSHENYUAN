extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	room.combat_only = false
	root.add_child(room)
	await process_frame
	assert(room.hud.modal_open and room.hud.choice_required and not room.wave_started)
	assert(get_nodes_in_group("minions").is_empty(), "No enemies before skill confirmation")
	assert(room.player.position.distance_to(room._at(Vector2(768, 565))) < 0.01)
	assert(room._art.is_walkable(room.player.position))
	for rect in room._art._blocks:
		assert(not rect.grow(16).has_point(room._art.to_pixel(room.player.position)), "Spawn is outside furniture collision")
	var attack: Resource = room.player._attack_data[0]
	assert(is_equal_approx(attack.total_duration(), 0.52 / 2.0))
	assert(is_equal_approx(attack.reach, 1.18 * 1.35))
	assert(is_equal_approx(attack.hit_radius, 0.58 * 1.35))
	room.hud._choose(Callable(room.rogue, "_take_start").bind(0))
	assert(room.wave_started and room.enemies_left == 32 and not paused)
	var sides := [0, 0, 0, 0]
	var enemies := get_nodes_in_group("minions")
	for enemy in enemies:
		sides[enemy.get_meta("spawn_side")] += 1
		assert(enemy.health == 18 and enemy.attack_damage == 3)
		assert(enemy._health_bar.visible and enemy._health_fill.scale.x == 1)
		assert(enemy.position.distance_to(room.player.position) >= 7)
		for rect in room._art._blocks:
			assert(not rect.grow(10).has_point(room._art.to_pixel(enemy.position)))
	assert(sides == [8, 8, 8, 8], "Eight enemies spawn on each side")
	enemies[0].receive_hit(6, Vector3.ZERO, enemies[0].position)
	assert(is_equal_approx(enemies[0]._health_fill.scale.x, 2.0 / 3.0), "Healthbar follows actual health")
	room.rogue._take_start(1)
	assert(room.enemies_left == 32 and not room.rogue.enabled[1], "Skill confirmation cannot spawn twice")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/opening_crowd.png")
	for enemy in enemies: enemy.receive_hit(999, Vector3.ZERO, enemy.position)
	await process_frame
	assert(room.office_fought and room.rogue.pending_reward and room.rogue.coins == 15)
	assert(room.hud.choice_required, "Clearing opening wave opens one reward draft")
	room.hud.close_dialog()
	room.queue_free()
	await process_frame
	print("PASS opening: center spawn, direct draft, 32 enemies from four sides, fast wide melee, healthbars, no duplicate wave and victory reward")
	quit()
