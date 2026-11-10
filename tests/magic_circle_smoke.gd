extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud.close_dialog()
	assert(room.skills.cast_at(3, room.player.position + Vector3.FORWARD * 4))
	var circle: Node = room.skills.get_node("MagicCircleCast")
	assert(circle != null and circle.get_child_count() == 1)
	var left: float = room.skills.cooldowns[3]
	assert(not room.skills.cast_at(3, room.player.position))
	assert(room.skills.get_children().filter(func(n: Node): return n.get_script() == load("res://scripts/cards/magic_circle_cast.gd")).size() == 1)
	await create_timer(0.2, true, false, true).timeout
	room.hud.show_notebook()
	var age: float = circle.age
	await create_timer(0.2, true, false, true).timeout
	assert(is_equal_approx(circle.age, age), "Effect freezes when paused")
	room.hud.close_dialog()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/magic_circle_cast.png")
	await create_timer(0.8, true, false, true).timeout
	assert(not is_instance_valid(circle), "Circle finishes and releases itself")
	room.skills.clear_effects()
	room.queue_free()
	await process_frame
	print("PASS cast circle: success-only, no duplicate on cooldown denial, pause and lifecycle cleanup")
	quit()
