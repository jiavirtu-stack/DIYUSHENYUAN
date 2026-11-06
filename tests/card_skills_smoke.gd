extends SceneTree

var chapter: Node
var skills: Node

func _initialize() -> void:
	call_deferred("_run")

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _ready_to_cast() -> void:
	skills.clear_effects()
	skills.reset_cooldowns()
	await physics_frame
	await physics_frame

func _run() -> void:
	chapter = load("res://scenes/chapter01/card_practice.tscn").instantiate()
	root.add_child(chapter)
	await process_frame
	chapter.hud.close_dialog()
	skills = chapter.skills
	for target in get_nodes_in_group("card_targets"):
		target.queue_free()
	await process_frame
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/chapter01/office_echo.gd"))
	enemy.set("max_health", 38.0)
	enemy.set("move_speed", 0.0)
	enemy.position = Vector3(0, 0, 2)
	chapter.world.add_child(enemy)
	enemy.set("health", 1000.0)
	chapter.player.position = Vector3(0, 0, 7)
	await _wait(0.08)
	await physics_frame
	await physics_frame
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	chapter.hud._unhandled_input(middle)
	assert(chapter.hud._locked == 0 and skills.aim_index == -1, "First middle click only locks a card")
	middle.pressed = false
	chapter.hud._unhandled_input(middle)
	middle.pressed = true
	chapter.hud._unhandled_input(middle)
	assert(skills.aim_index == 0, "Second press must begin aiming")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	chapter.hud._unhandled_input(right)
	middle.pressed = false
	chapter.hud._unhandled_input(middle)
	assert(chapter.hud._locked == -1 and skills.cooldowns[0] == 0.0, "Right cancel followed by middle release must not cast")
	assert(skills.begin_aim(0))
	skills.cancel_aim()
	assert(skills.cooldowns[0] == 0.0, "Canceled aim must not consume cooldown")
	var before: float = enemy.get("health")
	assert(skills.cast_at(0, enemy.position, 1.0))
	assert(is_equal_approx(before - float(enemy.get("health")), 36.0), "Charged beam actual damage: %s" % (before - float(enemy.get("health"))))
	assert(not skills.cast_at(0, enemy.position, 1.0), "Repeat use must be blocked by cooldown")
	assert(skills.cooldowns[0] > 5.9 and skills.cooldowns[1] == 0.0, "Cooldowns are independent")
	await _ready_to_cast()
	before = enemy.get("health")
	assert(skills.cast_at(1, enemy.position))
	await _wait(0.6)
	assert(float(enemy.get("health")) <= before - 18.0, "Letter must land and explode")
	before = enemy.get("health")
	await _wait(1.1)
	assert(float(enemy.get("health")) <= before - 4.0, "Fire zone must deal periodic damage")
	await _ready_to_cast()
	assert(skills.cast_at(2, enemy.position))
	await _wait(0.2)
	assert(float(enemy.get("_card_speed_factor")) < 1.0, "Frost must slow enemies")
	var remaining: float = skills.cooldowns[2]
	before = enemy.get("health")
	chapter.hud.show_notebook()
	await _wait(0.4)
	assert(is_equal_approx(remaining, skills.cooldowns[2]) and is_equal_approx(before, enemy.get("health")), "Reading must pause cooldown and damage")
	chapter.hud.close_dialog()
	await _wait(1.55)
	assert(bool(enemy.get("_card_frozen")), "Continuous frost dwell must freeze normal enemies")
	await _wait(0.9)
	assert(not bool(enemy.get("_card_frozen")), "Freeze must expire")
	await _ready_to_cast()
	before = enemy.get("health")
	assert(skills.cast_at(3, enemy.position))
	await _wait(1.5)
	assert(float(enemy.get("health")) <= before - 30.0, "Three seeking embers must hit")
	await _ready_to_cast()
	enemy.position = Vector3(1.7, 0, 2)
	before = enemy.get("health")
	assert(skills.cast_at(4, Vector3(0, 0, 2)))
	await _wait(0.15)
	assert((enemy.get("_card_forced_velocity") as Vector3).x < -0.1, "Vortex must pull toward center")
	await _wait(2.4)
	assert(float(enemy.get("health")) <= before - 20.0, "Vortex ticks and final pressure must hit")
	await _ready_to_cast()
	enemy.position = Vector3(0, 0, 1)
	var paper := StaticBody3D.new()
	paper.set_script(load("res://scripts/chapter01/paper_body.gd"))
	paper.position = Vector3(0, 0.8, 4)
	paper.set("extent", Vector3(3, 1.6, 0.5))
	chapter.world.add_child(paper)
	await physics_frame
	before = enemy.get("health")
	assert(skills.cast_at(0, enemy.position, 1.0))
	assert(paper.get("durability") <= 0.0, "Beam must tear destructible paper")
	assert(float(enemy.get("health")) < before, "Beam must continue after tearing paper")
	await _ready_to_cast()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 2, 0.6)
	collision.shape = shape
	wall.position = Vector3(0, 1, 4)
	wall.add_child(collision)
	chapter.world.add_child(wall)
	await physics_frame
	before = enemy.get("health")
	assert(skills.cast_at(0, enemy.position, 1.0))
	assert(is_equal_approx(before, enemy.get("health")), "Beam must stop at solid walls")
	wall.queue_free()
	await _ready_to_cast()
	assert(skills.cast_at(2, enemy.position))
	var first: float = enemy.get("health")
	await _wait(0.3)
	assert(skills.cast_at(1, enemy.position))
	await _wait(0.6)
	assert(first - float(enemy.get("health")) > 18.0, "Internal element interaction must change damage")
	var left: float = skills.cooldowns[1]
	chapter._load_stage(1)
	assert(skills._effects.is_empty() and skills.aim_index == -1, "Stage transition must clear old effects")
	assert(is_equal_approx(left, skills.cooldowns[1]), "Stage transition preserves cooldowns")
	chapter._load_stage(2)
	chapter._start_boss()
	chapter.hud.close_dialog()
	chapter.stamper.set("_clock", 100.0)
	chapter.stamper.exposed = true
	chapter.player.position = Vector3(0, 0, 8)
	await _ready_to_cast()
	assert(skills.cast_at(2, chapter.stamper.position))
	await _wait(1.75)
	var boss_status: Dictionary = skills._statuses[chapter.stamper.get_instance_id()]
	assert(boss_status.freeze_left == 0.0, "Boss must remain immune to freeze")
	chapter.stamper.receive_hit(9999.0, Vector3.ZERO, chapter.stamper.position)
	assert(chapter.won and skills._effects.is_empty(), "Victory must clear effects")
	chapter.hud.close_dialog()
	await _wait(0.1)
	chapter.queue_free()
	await process_frame
	print("PASS five cards: actual hits, cooldowns, cancel, paused reading, freeze, tracking, pull, paper, walls, internal interaction, transitions and Boss immunity")
	quit()
