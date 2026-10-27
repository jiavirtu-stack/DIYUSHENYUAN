extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	if run_state == null:
		run_state = load("res://scripts/run_state.gd").new()
		run_state.name = "RunState"
		root.add_child(run_state)
	run_state.selected_buff = -1
	var packed := load("res://scenes/arena.tscn") as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	await process_frame
	var boss := arena.get_node("Boss") as RitualBriarBoss
	var hud := arena.get_node("BattleHUD") as BattleHUD
	boss.receive_hit(100.0,Vector3.ZERO,Vector3.ZERO)
	if not paused or not hud.result_panel.visible or not hud.reward_row.visible:
		push_error("Victory did not pause and reveal reward selection")
		quit(1); return
	hud._select_reward(0,"攻击力 +20%")
	if run_state.selected_buff != 0 or not hud.replay_button.visible:
		push_error("Reward selection did not set persistent run buff and enable replay")
		quit(1); return
	paused=false
	arena.queue_free()
	await process_frame
	var next_arena := packed.instantiate()
	root.add_child(next_arena)
	await process_frame
	var new_player := next_arena.get_node("Player") as FairytalePlayer
	if not is_equal_approx(new_player.get("_attack_data")[0].damage,14.4):
		push_error("Attack reward was not applied on a new challenge")
		quit(1); return
	new_player.apply_hit(100.0)
	var next_hud := next_arena.get_node("BattleHUD") as BattleHUD
	if new_player.health > 0.0 or not next_hud.result_panel.visible or next_hud.result_title.text != "旅人倒下":
		push_error("Defeat did not enter the retry screen")
		quit(1); return
	paused=false
	run_state.selected_buff=2
	var vital_arena:=packed.instantiate()
	root.add_child(vital_arena)
	await process_frame
	var vital_player:=vital_arena.get_node("Player") as FairytalePlayer
	if not is_equal_approx(vital_player.max_health,125.0):
		push_error("Maximum health reward was not applied")
		quit(1); return
	run_state.selected_buff=-1
	print("STAGE7_LOOP_OK: victory/reward, persistent buff, defeat/retry screen, health upgrade")
	quit()
