extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/melee_test.tscn") as PackedScene
	if scene == null:
		push_error("Could not load melee test scene")
		quit(1)
		return
	var root_scene := scene.instantiate()
	root.add_child(root_scene)
	await physics_frame
	await physics_frame
	var player := root_scene.get_node("Player") as FairytalePlayer
	var target := root_scene.get_node("TrainingTarget") as TestSandbag
	player.set_facing_direction(Vector3(0, 0, -1))
	player.call("_start_attack", 0)
	for _frame in range(60):
		await physics_frame
	if target.hit_count != 1 or not is_equal_approx(target.health, 288.0):
		push_error("First attack should hit once for 12 damage; hits=%d health=%f" % [target.hit_count, target.health])
		quit(1)
		return
	if target.last_knockback.z >= 0.0:
		push_error("Knockback did not follow facing direction")
		quit(1)
		return
	player.call("_start_attack", 0)
	player.set("_combo_buffered", true)
	for _frame in range(60):
		await physics_frame
	if target.hit_count < 3:
		push_error("Buffered combo did not produce subsequent swings")
		quit(1)
		return
	player.call("_start_attack", 0)
	player.set("_attack_elapsed", 0.0)
	player.call("_cancel_attack")
	if player.get("_attack_stage") != -1:
		push_error("Attack cancellation did not clear attack state")
		quit(1)
		return
	print("STAGE3_MELEE_OK: three attack resources, hit once per swing, damage, directional knockback, buffered chain, cancellable state")
	quit()
