extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud.close_dialog()
	room.set_physics_process(false)
	for target in get_nodes_in_group("card_targets"): target.queue_free()
	await process_frame
	var player: Node = room.player
	player.set_physics_process(false)
	player.position = Vector3(0, 0, 3)
	player._facing = Vector3.FORWARD
	var enemies: Array[Node] = []
	for i in range(3):
		var enemy := CharacterBody3D.new()
		enemy.set_script(load("res://scripts/chapter01/office_echo.gd"))
		enemy.position = Vector3((i - 0.5) * 0.4, 0, 1.82) if i < 2 else Vector3(5, 0, 0)
		enemy.set("max_health", 1000)
		enemy.set("move_speed", 0.0)
		room.world.add_child(enemy)
		enemy.set_physics_process(false)
		enemy._attack_cooldown = 1.0
		enemies.append(enemy)
	await physics_frame
	await physics_frame
	player._start_attack(0)
	player._query_attack_hits(player._attack_data[0])
	assert(enemies[0].health == 988 and enemies[1].health == 988)
	assert(is_equal_approx(player._hit_pause_left, 0.05) and player.sprite.speed_scale == 0, "Blade animation freezes on real hit")
	assert(enemies[0]._hit_pause_left > 0 and enemies[1]._hit_pause_left > 0 and enemies[2]._hit_pause_left == 0)
	var elapsed: float = player._attack_elapsed
	var clock: float = enemies[0]._attack_cooldown
	player._physics_process(0.016)
	enemies[0]._physics_process(0.016)
	enemies[2]._physics_process(0.016)
	assert(player._attack_elapsed == elapsed and enemies[0]._attack_cooldown == clock, "Attacker and victim clocks freeze")
	assert(enemies[2]._attack_cooldown < 1.0 and Engine.time_scale == 1, "Other actors and global time continue normally")
	player._query_attack_hits(player._attack_data[0])
	assert(enemies[0].health == 988 and player._hit_pause_left < 0.05, "Same swing cannot duplicate damage or extend hitstop")
	paused = true
	var left: float = player._hit_pause_left
	player._physics_process(0.1)
	assert(player._hit_pause_left == left, "Menu pause preserves remaining local hitstop")
	paused = false
	player._physics_process(0.06)
	assert(player._hit_pause_left == 0 and player.sprite.speed_scale == 1)
	player._physics_process(0.016)
	assert(player._attack_elapsed > elapsed, "Attack resumes after hitstop")
	player._cancel_attack()
	player._start_attack(2)
	player._query_attack_hits(player._attack_data[2])
	assert(is_equal_approx(player._hit_pause_left, 0.083), "Finisher hitstop is stronger")
	player._cancel_attack()
	player.position = Vector3(-8, 0, 7)
	await physics_frame
	await physics_frame
	player._start_attack(0)
	player._query_attack_hits(player._attack_data[0])
	assert(player._hit_pause_left == 0 and player.sprite.speed_scale == 1, "Whiff never hitstops")
	player._melee_pause_used = false
	player._begin_melee_hit_pause(0.05)
	player._invulnerability_timer = 0
	player.health = 1
	player.apply_hit(10)
	assert(player._dead and player.sprite.speed_scale == 1 and player._hit_pause_left == 0, "Death interrupts freeze and restores animation")
	await create_timer(1.15, true, false, true).timeout
	paused = false
	room.queue_free()
	await process_frame
	print("PASS melee hitstop: blade and victims freeze, other actors continue, single-swing cap, resume, pause, heavy, whiff and death recovery")
	quit()
