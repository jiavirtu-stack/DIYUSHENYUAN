extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var chapter: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	root.add_child(chapter)
	await process_frame
	chapter.hud.close_dialog()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chapter01_office.png")
	chapter._load_stage(1)
	chapter.player.position = chapter._at(Vector2(1000, 477))
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chapter01_street.png")
	chapter._enter_apartment()
	chapter.hud.close_dialog()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chapter01_apartment.png")
	for child in chapter.world.get_children():
		if child.get_script() == load("res://scripts/chapter01/paper_body.gd"):
			child.receive_hit(999.0, Vector3.ZERO, child.position)
	await process_frame
	await process_frame
	chapter.hud.close_dialog()
	chapter.player.position = Vector3(5, 0, 3)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chapter01_stamper.png")
	chapter.stamper.exposed = true
	chapter.stamper.receive_hit(140.0, Vector3.ZERO, chapter.stamper.position)
	chapter.hud.close_dialog()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/chapter01_stamper_phase2.png")
	chapter.queue_free()
	await process_frame
	quit()
