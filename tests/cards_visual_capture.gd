extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chapter: Node = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(chapter)
	await process_frame
	chapter.hud.close_dialog()
	for i in range(5):
		chapter.reset_practice()
		await physics_frame
		await physics_frame
		chapter.hud.set("_selected", i)
		chapter.hud.set("_locked", i)
		assert(chapter.skills.cast_at(i, Vector3(0, 0, 1.5), 1.0))
		await create_timer([0.04, 0.65, 1.75, 0.1, 0.9][i], true, false, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/card_skill_%d.png" % (i + 1))
	chapter.reset_practice()
	await physics_frame
	await physics_frame
	chapter.hud.set("_selected", 1)
	chapter.hud.set("_locked", 1)
	assert(chapter.skills.begin_aim(1))
	chapter.skills.set_physics_process(false)
	chapter.skills.aim_point = Vector3(0, 0, 1.5)
	chapter.skills._update_preview()
	var count: int = chapter.skills.get("_preview").get_child_count()
	for i in range(50):
		chapter.skills._update_preview()
	assert(chapter.skills.get("_preview").get_child_count() == count, "Aim preview must reuse its nodes")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/card_skill_aim.png")
	chapter.skills.cancel_aim()
	chapter.queue_free()
	await process_frame
	print("PASS visual capture: five effects, cooldown cards and pooled aim preview")
	quit()
