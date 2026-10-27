extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/boss.tscn") as PackedScene
	var boss := packed.instantiate() as RitualBriarBoss
	root.add_child(boss)
	await physics_frame
	if boss.state != RitualBriarBoss.State.INTRO:
		push_error("Boss did not enter INTRO")
		quit(1)
		return
	boss.receive_hit(50.0, Vector3.ZERO, Vector3.ZERO)
	if boss.phase != 2 or boss.state != RitualBriarBoss.State.PHASE_TRANSITION:
		push_error("50% threshold did not trigger phase transition")
		quit(1)
		return
	# The transition is deliberately invulnerable; move into the new phase before testing lethal damage.
	boss.state = RitualBriarBoss.State.IDLE
	boss.receive_hit(100.0, Vector3.ZERO, Vector3.ZERO)
	if boss.state != RitualBriarBoss.State.DEATH:
		push_error("Boss did not enter DEATH at zero health")
		quit(1)
		return
	print("STAGE4_BOSS_OK: INTRO, 50% phase transition, DEATH")
	quit()
