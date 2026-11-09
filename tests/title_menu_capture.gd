extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.4).timeout
	assert(menu.get_node("StartButton").text == "开始游戏")
	menu._select(1)
	assert(menu.get("_diamond").position.y == 826)
	menu._select(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/title_menu.png")
	menu.queue_free()
	await process_frame
	print("PASS title menu load and selection")
	quit()
