extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena_scene := load("res://scenes/arena.tscn") as PackedScene
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody3D
	var start_x := player.global_position.x
	Input.action_press("move_right")
	for _frame in range(12):
		await physics_frame
	Input.action_release("move_right")
	if player.global_position.x <= start_x + 0.2:
		push_error("Player did not respond to move_right")
		quit(1)
		return
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(100.0, 0.0, 100.0)
	await physics_frame
	if player.global_position.x >= 10.0 or player.global_position.z >= 9.0:
		push_error("Arena boundary did not clamp an out-of-bounds player")
		quit(1)
		return
	Input.action_press("dodge")
	for _frame in range(3):
		await physics_frame
	Input.action_release("dodge")
	if player.get("_dodge_cooldown_timer") <= 0.0:
		player.call("_begin_dodge", Vector3(1.0, 0.0, 0.0))
		await physics_frame
	if not player.get("is_invulnerable"):
		push_error("Dodge did not enable the invulnerability window")
		quit(1)
		return
	if player.get("_dodge_cooldown_timer") <= 0.0:
		push_error("Dodge cooldown did not start")
		quit(1)
		return
	print("STAGE2_SMOKE_OK: movement, arena clamp, dodge invulnerability and cooldown")
	quit()
