extends SceneTree
var room: Node
func _initialize() -> void:
	call_deferred("run")
func wait_for(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
func frames() -> void:
	await physics_frame
	await physics_frame
func dummy(at: Vector3, hp: float = 500.0) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/chapter01/office_echo.gd"))
	enemy.position = at
	enemy.set("max_health", hp)
	enemy.set("move_speed", 0.0)
	room.world.add_child(enemy)
	return enemy
func run() -> void:
	room = load("res://scenes/chapter01/beam_rule_lab.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.auto_wave = false
	assert(room.alive >= 18, "Lab must provide a real crowd")
	for enemy in get_nodes_in_group("card_targets"): enemy.queue_free()
	await process_frame
	room.player.position = Vector3(0, 0, 7)
	var beam: Node = room.lab_beam
	for key in beam.rules.keys(): beam.rules[key] = false
	var first := dummy(Vector3(0, 0, 3))
	var second := dummy(Vector3(0, 0, 0))
	await frames()
	beam.cast(Vector3(0, 0, -5), 1)
	await wait_for(0.5)
	assert(first.health < 500 and second.health == 500, "Base shot stops at first enemy")
	beam.clear()
	Engine.time_scale = 1
	first.position = Vector3(0, 0, 3)
	second.position = Vector3(0, 0, 0)
	first.health = 500
	second.health = 500
	first.set("_knockback_velocity", Vector3.ZERO)
	second.set("_knockback_velocity", Vector3.ZERO)
	beam.rules.pierce = true
	beam.rules["return"] = true
	await frames()
	beam.cast(Vector3(0, 0, -5), 1)
	await wait_for(2.2)
	assert(first.health <= 424 and second.health <= 424, "Piercing return must hit on both legs")
	assert(beam.return_hits >= 2 and beam.rays.is_empty(), "Return is bounded and cleans up")
	beam.clear()
	first.position = Vector3(0, 0, 3)
	var neighbor := dummy(Vector3(1.1, 0, 3))
	beam.rules.blast = true
	beam.rules.split = true
	beam.rules.bounce = true
	await frames()
	beam.cast(Vector3(0, 0, -5), 1)
	assert(beam.rays.size() == 3, "Split coexists with all other rules")
	await wait_for(1.0)
	assert(beam.blasts > 0 and neighbor.health < 500, "Explosion applies real splash damage")
	# Fixed wall explicitly verifies reflection.
	beam.clear()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 2, 0.3)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 0.7, 5)
	room.world.add_child(wall)
	await frames()
	var old_bounces: int = beam.bounces
	beam.cast(Vector3(0, 0, -5), 0.2)
	await wait_for(0.4)
	assert(beam.bounces > old_bounces, "Walls reflect shots")
	beam.clear()
	assert(beam.rays.is_empty())
	room.get_node("CombatFeedback")._trigger_hit_stop(0.045)
	assert(Engine.time_scale < 1)
	room.queue_free()
	await process_frame
	assert(is_equal_approx(Engine.time_scale, 1), "Exiting during hitstop restores global time")
	print("PASS beam rules: crowd, base collision, pierce, reflected path return, split stack, real splash, fixed-wall bounce, cleanup and hitstop exit")
	quit()
