extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room: Node = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.hud.close_dialog()
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	for target in get_nodes_in_group("card_targets"): target.queue_free()
	await process_frame
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/chapter01/office_echo.gd"))
	enemy.role = 1
	enemy.position = Vector3(0, 0, 1)
	room.world.add_child(enemy)
	enemy.set_physics_process(false)
	room.player.position = Vector3(0, 0, 3)
	await physics_frame
	await physics_frame
	enemy._physics_process(0.016)
	assert(enemy.decision == "后撤保持距离")
	enemy.position = Vector3(0, 0, -1)
	room.player.position = Vector3(0, 0, 5)
	enemy._attack_cooldown = 0
	await physics_frame
	await physics_frame
	enemy._physics_process(0.016)
	assert(enemy._windup_timer > 0)
	var locked: Vector3 = enemy._attack_direction
	room.player.position.x = 3
	enemy._physics_process(0.6)
	assert(enemy._attack_direction == locked and enemy._recover > 0, "Shot direction stays locked through windup")
	enemy.role = 2
	enemy._begin_role_attack(Vector3.FORWARD)
	var locked_point: Vector3 = enemy._cast_point
	assert(is_instance_valid(enemy._magic_mark))
	room.player.position = locked_point + Vector3(3, 0, 0)
	room.player._invulnerability_timer = 0
	var hp: float = room.player.health
	enemy._perform_attack()
	assert(room.player.health == hp, "Walking out of the fixed spell warning avoids damage")
	enemy._begin_role_attack(Vector3.FORWARD)
	enemy._die()
	assert(enemy._magic_mark.is_queued_for_deletion(), "Death cancels pending spell warning")
	room.queue_free()
	await process_frame
	print("PASS enemy decisions: retreat, ranged locked aim and recovery, fixed magic warning, dodge and death cleanup")
	quit()
