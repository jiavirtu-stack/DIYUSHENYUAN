extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := TextureRect.new()
	sprite.texture = load("res://assets/menu/falling_hero.png")
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.size = Vector2(256, 256)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/falling_hero_motion.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image()
	material.set_shader_parameter("animation_time", 1.7)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var second := viewport.get_texture().get_image()
	var regions := {"scarf":Rect2(0.03, 0.07, 0.40, 0.62), "hands":Rect2(0.43, 0.14, 0.25, 0.53), "feet":Rect2(0.65, 0.20, 0.30, 0.43), "bell":Rect2(0.325, 0.695, 0.15, 0.185)}
	for name in regions:
		var region: Rect2 = regions[name]
		var changed := 0
		for y in range(int(region.position.y * 256), int(region.end.y * 256)):
			for x in range(int(region.position.x * 256), int(region.end.x * 256)):
				var difference := first.get_pixel(x, y) - second.get_pixel(x, y)
				if absf(difference.r) + absf(difference.g) + absf(difference.b) + absf(difference.a) > 0.08:
					changed += 1
		assert(changed > 8, "Local animation absent: " + str(name))
		print(name, " changed pixels: ", changed)
	viewport.queue_free()
	await process_frame
	print("PASS independent scarf, hands, feet and bell animation")
	quit()
