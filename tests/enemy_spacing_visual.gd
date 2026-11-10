extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud._choose(Callable(room.rogue, "_take_start").bind(0))
	room.player._invulnerability_timer = 100
	room.player.set_physics_process(false)
	await create_timer(11, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/enemy_spacing.png")
	var close_melee := 0
	var ranged_close := 0
	for enemy in get_nodes_in_group("minions"):
		if not enemy.visible: continue
		var distance: float = enemy.position.distance_to(room.player.position)
		if enemy.role == 0 and distance < 2: close_melee += 1
		if enemy.role > 0 and distance < 3: ranged_close += 1
	print("Rendered live spacing: close melee=", close_melee, ", ranged inside 3 units=", ranged_close)
	room.queue_free()
	await process_frame
	quit()
