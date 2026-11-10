extends SceneTree

var chapter: Node
var run: Node
var skills: Node

func _initialize() -> void:
	call_deferred("_run")

func _frames() -> void:
	await physics_frame
	await physics_frame

func _run() -> void:
	chapter = load("res://scenes/chapter01/revoked_day.tscn").instantiate()
	chapter.combat_only = false
	root.add_child(chapter)
	await process_frame
	run = chapter.rogue
	skills = chapter.skills
	assert(not run.enabled.has(true))
	chapter.hud._choose(Callable(run, "start"))
	assert(chapter.hud.choice_required)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	chapter.hud._unhandled_input(esc)
	assert(chapter.hud.modal_open and chapter.hud.choice_required, "Cannot skip a mandatory choice")
	chapter.hud._choose(Callable(run, "_take_start").bind(0))
	assert(run.enabled[0] and not run.enabled[1])
	assert(not skills.begin_aim(1), "Unowned card cannot cast")
	chapter._start_wave()
	for enemy in get_nodes_in_group("minions"):
		enemy.receive_hit(999, Vector3.ZERO, enemy.position)
	await process_frame
	assert(run.pending_reward and run.coins == 15)
	assert(run.picks.size() == 3 and chapter.hud.choice_required)
	var reward: Dictionary = run.picks[0]
	chapter.hud._choose(Callable(run, "take_reward").bind(reward))
	var count: int = run.history.size()
	run.take_reward(reward)
	assert(run.history.size() == count, "Same reward cannot be claimed twice")
	chapter._office_exit()
	assert(chapter.stage == 1)
	chapter._enter_apartment()
	assert(chapter.stage == 1 and chapter.hud.choice_required, "Boss route is gated by branch nodes")
	chapter.hud.close_dialog()
	run.enter_node("精英战")
	chapter.hud.close_dialog()
	assert(run.in_combat and run.remaining >= 5)
	chapter._enter_apartment()
	assert(chapter.stage == 1 and run.in_combat)
	for enemy in get_nodes_in_group("minions"):
		if not enemy.is_queued_for_deletion() and enemy.health > 0:
			enemy.receive_hit(999, Vector3.ZERO, enemy.position)
	await process_frame
	assert(not run.in_combat and run.pending_reward)
	chapter.hud._choose(Callable(run, "take_reward").bind(run.picks[0]))
	await process_frame
	assert(chapter.hud.choice_required, "Elite grants an extra relic choice")
	chapter.hud._choose(Callable(run, "_finish_relic").bind(0 if not run.relics.has(0) else 2))
	assert(run.relics.size() >= 1)
	# Complete two non-combat branches and a final battle.
	run.enter_node("休息")
	chapter.hud.close_dialog()
	run.enter_node("事件")
	chapter.hud.close_dialog()
	run._event(false)
	chapter.hud.close_dialog()
	run.enter_node("普通战")
	chapter.hud.close_dialog()
	for enemy in get_nodes_in_group("minions"):
		if not enemy.is_queued_for_deletion() and enemy.health > 0:
			enemy.receive_hit(999, Vector3.ZERO, enemy.position)
	await process_frame
	chapter.hud._choose(Callable(run, "take_reward").bind(run.picks[0]))
	run.route()
	chapter.hud.close_dialog()
	assert(chapter.stage == 2 and run.depth == 5, "Four branch nodes lead to the story Boss")
	# Isolate all ten mutation branches in the same real physics world.
	run.enabled = [true, true, true, true, true]
	chapter.player.position = Vector3(0, 0, 7)
	await _frames()
	for card in range(5):
		for branch in range(2):
			skills.clear_effects()
			skills.reset_cooldowns()
			run.mutations = [-1, -1, -1, -1, -1]
			run.mutations[card] = branch
			assert(skills.begin_aim(card))
			skills.aim_point = Vector3(0, 0, 2)
			skills._update_preview()
			skills.cancel_aim()
			assert(skills.cast_at(card, Vector3(0, 0, 2), 1.0))
			if card == 3:
				assert(skills._effects[0].birds.size() == (5 if branch == 0 else 3))
			if card == 2 and branch == 0:
				assert(skills._effects.size() == 3)
			await create_timer(0.65).timeout
	# Relic ownership is capped, nonduplicating; modifiers reach the actual cooldown.
	skills.clear_effects()
	skills.reset_cooldowns()
	run.relics.clear()
	run.cooldown_scale = 1.0
	run.take_relic(6)
	assert(is_equal_approx(skills.cooldown_duration(0), 5.1))
	run.take_relic(6)
	assert(is_equal_approx(skills.cooldown_duration(0), 5.1))
	for id in range(8): run.take_relic(id)
	assert(run.relics.size() == 4)
	chapter.queue_free()
	await process_frame
	print("PASS rogue: start draft, mandatory choice, one-shot rewards, gated branches, elite relic, ten mutation casts, cooldown relics and ownership cap")
	quit()
