extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/arena.tscn") as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	await process_frame
	await physics_frame
	var player := arena.get_node("Player") as FairytalePlayer
	var boss := arena.get_node("Boss") as RitualBriarBoss
	var controller := arena.get_node("BossAttackController") as BossAttackController
	controller.debug_force_skill = 0
	player.global_position = Vector3(0,0,-0.65)
	for _frame in 10: await physics_frame
	controller.trigger_skill(0)
	await create_timer(1.5).timeout
	if player.health >= 100.0:
		push_error("Ground spike did not damage a stationary player in its marked lane")
		quit(1); return
	var health_after_spike := player.health
	player._invulnerability_timer = 0.0
	player.global_position = Vector3(0,0,-0.2)
	controller.trigger_skill(1)
	await create_timer(1.4).timeout
	if player.health >= health_after_spike:
		push_error("Fan attack did not hit inside its telegraphed sector")
		quit(1); return
	controller.trigger_skill(2)
	await create_timer(1.7).timeout
	if controller.get("_busy"):
		push_error("Ring barrage did not finish and clear its active state")
		quit(1); return
	if controller.last_ring_projectile_count >= controller.ring_projectile_count:
		push_error("Ring volley did not leave a safety gap")
		quit(1); return
	print("STAGE5_SKILLS_OK: spikes and fan damage within marked regions; ring gap/barrage resolves and clears")
	quit()
