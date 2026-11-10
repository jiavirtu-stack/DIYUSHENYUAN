extends SceneTree

var chapter: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	chapter = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	chapter.rogue_enabled = false
	chapter.combat_only = false
	root.add_child(chapter)
	await process_frame
	chapter.hud.close_dialog()
	assert(chapter.stage == 0)
	assert(chapter._interactions.size() == 8, "Office evidence, desk and exit must be reachable interactions")
	for id in range(6):
		chapter._read_evidence(id)
		chapter.hud.close_dialog()
	assert(chapter.records.size() == 6)
	chapter._read_evidence(0)
	chapter.hud.close_dialog()
	assert(chapter.records.size() == 6, "Re-reading cannot duplicate records")
	chapter._start_wave()
	assert(chapter.enemies_left == 5)
	for enemy in get_nodes_in_group("minions"):
		enemy.receive_hit(999.0, Vector3.ZERO, enemy.position)
	assert(chapter.office_fought, "Defeating all enemies must open the exit")
	chapter.hud.close_dialog()
	chapter._office_exit()
	assert(chapter.stage == 1)
	assert(chapter.records.size() == 6, "Records survive stage transitions")
	chapter._enter_apartment()
	chapter.hud.close_dialog()
	assert(chapter.stage == 2)
	var papers: Array = []
	for child in chapter.world.get_children():
		if child.get_script() == load("res://scripts/chapter01/paper_body.gd"):
			papers.append(child)
	assert(papers.size() == 5)
	chapter.player.position = Vector3(0, 0, papers[2].position.z + 1.8)
	chapter.player.set("_attack_direction", Vector3(0, 0, -1))
	await physics_frame
	chapter.player.call("_query_attack_hits", chapter.player.get("_attack_data")[0])
	assert(papers[2].durability < 24.0, "Real player melee query must damage the center bill collision body")
	for body in papers:
		body.receive_hit(34.0, Vector3.ZERO, body.position)
	await process_frame
	await process_frame
	assert(chapter.bills_done.size() == 5)
	assert(is_instance_valid(chapter.stamper), "All five bills must summon the Boss")
	chapter.hud.close_dialog()
	chapter.player.position = Vector3(5, 0, 5)
	chapter.stamper._clock = 0.0
	chapter.stamper._physics_process(0.01)
	assert(chapter.stamper._state == "warning" and is_instance_valid(chapter.stamper._warning))
	chapter.stamper._clock = 0.0
	chapter.stamper._physics_process(0.01)
	assert(chapter.stamper.exposed, "Boss must actually advance from warning to impact and recovery")
	chapter.stamper._clock = 0.0
	chapter.stamper._physics_process(0.01)
	chapter.player.position = Vector3.ZERO
	chapter.player.set("_invulnerability_timer", 0.0)
	var before: float = chapter.player.health
	chapter.stamp_impact(Vector3.ZERO, Vector2(4, 4))
	assert(chapter.player.health == before - 18.0, "Stamp visual rectangle must match damage")
	chapter.player.position = Vector3(5, 0, 5)
	chapter.player.set("_invulnerability_timer", 0.0)
	before = chapter.player.health
	chapter.stamp_impact(Vector3.ZERO, Vector2(4, 4))
	assert(chapter.player.health == before, "Outside stamp rectangle must be safe")
	chapter.stamper.exposed = true
	chapter.stamper.receive_hit(135, Vector3.ZERO, chapter.stamper.position)
	assert(chapter.stamper.phase == 2)
	chapter.hud.close_dialog()
	chapter._time_to_shrink = 0.0
	chapter._physics_process(0.01)
	assert(chapter._shrink_step == 1)
	chapter.send_paper_wall(2)
	await process_frame
	var moving_count := 0
	for child in chapter.world.get_children():
		if child.get_script() == load("res://scripts/chapter01/paper_body.gd") and child.moving:
			moving_count += 1
			child.receive_hit(34, Vector3.ZERO, child.position)
	assert(moving_count == 10, "Five segments from Boss recovery and five from explicit wall spawn")
	chapter.stamper.receive_hit(999, Vector3.ZERO, chapter.stamper.position)
	assert(chapter.won)
	assert(chapter.hud.modal_open, "Victory must show causal record card")
	chapter.hud.close_dialog()
	await create_timer(1.1, true, false, true).timeout
	chapter.queue_free()
	await process_frame
	print("PASS chapter01: evidence, combat gate, transitions, bills, stamp damage, phase two, torn walls and victory")
	quit()
