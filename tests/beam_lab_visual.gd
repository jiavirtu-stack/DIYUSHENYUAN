extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/beam_rule_lab.tscn").instantiate()
	root.add_child(room)
	await process_frame
	for check in room._checks: check.button_pressed = true
	await physics_frame
	await physics_frame
	assert(room.skills.begin_aim(0))
	room.skills.aim_point = room.player.position + Vector3(0, 0, -12)
	room.skills._update_preview()
	var count: int = room.skills._preview_arc.size()
	for i in range(20): room.skills._update_preview()
	assert(room.skills._preview_arc.size() == count, "Preview must reuse geometry")
	room.skills.cancel_aim()
	assert(room.skills.cast_at(0, room.player.position + Vector3(0, 0, -12), 1))
	await create_timer(0.18, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/beam_rule_lab.png")
	await create_timer(0.3, true, false, true).timeout
	room.queue_free()
	await process_frame
	print("PASS rendered lab: stacked rules, pooled preview, impact shader and screenshot")
	quit()
