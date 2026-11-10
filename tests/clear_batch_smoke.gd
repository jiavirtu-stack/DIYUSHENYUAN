extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud._choose(Callable(room.rogue, "_take_start").bind(3))
	room.player.set_physics_process(false)
	room.player._invulnerability_timer = 100
	assert(room.enemies_left == 32 and room._batch_alive == 8 and room._batch_queue.size() == 24)
	await create_timer(1.2).timeout
	var first: Array = []
	for enemy in get_nodes_in_group("minions"):
		assert(enemy.visible)
		first.append(enemy)
	assert(first.size() == 8)
	for i in range(7): first[i].receive_hit(999, Vector3.ZERO, first[i].position)
	await create_timer(3.0).timeout
	assert(room._batch_number == 1 and room._batch_alive == 1 and room._batch_queue.size() == 24, "Time alone cannot trigger next batch")
	first[7].receive_hit(999, Vector3.ZERO, first[7].position)
	await process_frame
	assert(room._batch_number == 2 and room._batch_alive == 8 and room.enemies_left == 24)
	assert(not room.rogue.pending_reward)
	for batch in range(2, 5):
		await create_timer(1.2).timeout
		var active := 0
		for enemy in get_nodes_in_group("minions"):
			if not enemy._dead:
				active += 1
				enemy.receive_hit(999, Vector3.ZERO, enemy.position)
		assert(active == 8)
		await process_frame
	await process_frame
	assert(room.enemies_left == 0 and room.rogue.pending_reward)
	room.hud.close_dialog()
	room.queue_free()
	await process_frame
	print("PASS batches: only eight instantiated, hold while one survives, next batch on final death, reward only after four batches")
	quit()
