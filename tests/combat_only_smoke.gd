extends SceneTree
var room: Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	room = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	root.add_child(room)
	await process_frame
	assert(room.combat_only and room._interactions.is_empty() and room._subjective.is_empty())
	assert(room.hud.choice_required and not room.wave_started)
	room.hud._choose(Callable(room.rogue, "_take_start").bind(0))
	room.player._invulnerability_timer = 100
	for wave in range(1, 6):
		assert(room.battle_wave == wave and room.stage == 0)
		assert(room._interactions.is_empty(), "Combat arena has no exploration interactions")
		assert(room.enemies_left == 32 + (wave - 1) * 8, "Wave population ramps to 64")
		for batch in range(room._batch_total):
			assert(room._batch_number == batch + 1)
			for enemy in get_nodes_in_group("minions"):
				if not enemy._dead: enemy.receive_hit(999, Vector3.ZERO, enemy.position)
			await process_frame
		await process_frame
		assert(room.rogue.pending_reward and room.hud.choice_required)
		room.hud._choose(Callable(room.rogue, "take_reward").bind(room.rogue.picks[0]))
		await process_frame
		if room.hud.choice_required:
			var available: Array = []
			for id in range(8):
				if not room.rogue.relics.has(id): available.append(id)
			room.hud._choose(Callable(room.rogue, "_finish_relic").bind(available[0]))
		assert(not paused and room._battle_transition_pending)
		await create_timer(1.0, true, false, true).timeout
	assert(is_instance_valid(room.stamper) and not room.hud.modal_open, "Boss starts automatically without dialogue or bills")
	assert(room.bills_done.is_empty())
	room.stamper.receive_hit(450, Vector3.ZERO, room.stamper.position)
	assert(room.stamper.phase == 2 and not paused and not room.hud.modal_open, "Phase transition does not interrupt combat")
	room.stamper.receive_hit(999, Vector3.ZERO, room.stamper.position)
	assert(room.won and room.hud.modal_open, "Boss defeat ends the run")
	room.hud.close_dialog()
	room.queue_free()
	await process_frame
	print("PASS combat-only: zero exploration, 32/40/48/56/64 enemies, automatic wave transitions, elite rewards, direct Boss, uninterrupted phase and victory")
	quit()
