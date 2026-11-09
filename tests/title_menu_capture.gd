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
	var falling: Node = null
	for child in menu.get_children():
		if child.get_script() == load("res://scripts/title_fall.gd"):
			falling = child
	var hero_image: Image = falling.hero.texture.get_image()
	assert(falling != null and hero_image.get_pixel(0, 0).a < 0.1, "Falling character must be a separate transparent layer")
	var logo_position: Vector2 = falling.logo.position
	var old_travel: float = falling.far_material.get_shader_parameter("travel")
	await create_timer(1.2).timeout
	assert(falling.far_material.get_shader_parameter("travel") != old_travel, "Abyss background must scroll")
	assert(falling.logo.position == logo_position, "Title must remain stationary")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/title_menu_falling.png")
	menu.queue_free()
	await process_frame
	print("PASS title menu load and selection")
	quit()
