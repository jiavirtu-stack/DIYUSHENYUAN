extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chapter: Node = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	chapter.rogue_enabled = false
	chapter.combat_only = false
	root.add_child(chapter)
	await process_frame
	chapter.hud.close_dialog()
	for stage in range(3):
		chapter._load_stage(stage)
		if stage == 2:
			for child in chapter.world.get_children():
				if child.get_script() == load("res://scripts/chapter01/paper_body.gd"):
					child.queue_free()
		await physics_frame
		await physics_frame
		var art: Node = chapter.get("_art")
		var start: Vector2i = art._nearest_cell(art.to_pixel(chapter.player.position))
		for item in chapter.get("_interactions"):
			if not is_instance_valid(item.node):
				continue
			var goal: Vector2i = art._nearest_cell(art.to_pixel(item.node.position))
			var route: Array = art.navigation.get_id_path(start, goal)
			assert(not route.is_empty(), "Unreachable interaction: " + str(item.hint))
			for index in range(route.size() - 1):
				var a: Vector3 = art.to_world(art.navigation.get_point_position(route[index])) + Vector3.UP * 0.6
				var b: Vector3 = art.to_world(art.navigation.get_point_position(route[index + 1])) + Vector3.UP * 0.6
				var query := PhysicsRayQueryParameters3D.create(a, b, 1, [chapter.player.get_rid()])
				assert(chapter.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Navigation crosses a real collision: " + str(item.hint))
	# At both extremes the viewport's ground footprint must remain on the painted map.
	for extreme in [Vector3(-24, 0, -19), Vector3(24, 0, 19)]:
		chapter.set_camera_target(extreme)
		chapter._update_camera(100.0)
		var viewport_size := root.get_visible_rect().size
		for corner in [Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]:
			var point: Vector3 = Plane(Vector3.UP, 0).intersects_ray(chapter.camera.project_ray_origin(corner), chapter.camera.project_ray_normal(corner))
			assert(absf(point.x) <= 24.1 and absf(point.z) <= 19.65, "Camera exposes beyond background")
	chapter.queue_free()
	await process_frame
	print("PASS chapter01 navigation: office, street and apartment interaction paths respect real colliders; camera stays inside art")
	quit()
