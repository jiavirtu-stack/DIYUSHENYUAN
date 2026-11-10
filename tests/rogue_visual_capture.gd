extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var chapter: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	root.add_child(chapter)
	await process_frame
	chapter.hud._choose(Callable(chapter.rogue, "start"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/rogue_start.png")
	chapter.queue_free()
	await process_frame
	quit()
