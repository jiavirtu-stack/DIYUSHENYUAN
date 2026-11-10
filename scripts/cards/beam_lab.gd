extends "res://scripts/chapter01/revoked_day.gd"

var lab_beam: Node3D
var wave := 0
var alive := 0
var auto_wave := true
var _wave_delay := -1.0
var _lab_status: Label
var _shake_left := 0.0
var _shake_power := 0.0
var shake_strength := 0.4
var _checks: Array[CheckBox] = []

func _ready() -> void:
	card_practice = true
	super._ready()
	hud.close_dialog()
	lab_beam = load("res://scripts/cards/beam_rules.gd").new()
	add_child(lab_beam)
	skills.rule_beam = lab_beam
	for i in range(1, 5): hud._cards[i].hide()
	_build_lab_ui()
	hud.title.text = "规则实验室 · 雷贯光波"
	for check in _checks: check.button_pressed = true
	reset_practice()

func _build_lab_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 180)
	panel.custom_minimum_size.x = 430
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.07, 0.94)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "规则实验室 · 可以全部叠加"
	heading.add_theme_font_size_override("font_size", 23)
	column.add_child(heading)
	var names := ["分叉：三束扇射，每束72%伤害", "反弹：遇固定墙最多反射三次", "贯穿：去程/回程各最多八个目标", "回旋：沿真实反弹路线返回", "爆裂：命中产生小范围伤害"]
	var keys := ["split", "bounce", "pierce", "return", "blast"]
	for i in range(5):
		var check := CheckBox.new()
		check.text = names[i]
		check.add_theme_font_size_override("font_size", 18)
		check.toggled.connect(func(value: bool): lab_beam.rules[keys[i]] = value)
		column.add_child(check)
		_checks.append(check)
	var all_rules := Button.new()
	all_rules.text = "全部叠加 / 全部清空"
	all_rules.pressed.connect(func():
		var value := not _checks[0].button_pressed
		for check in _checks: check.button_pressed = value
	)
	column.add_child(all_rules)
	var wave_button := Button.new()
	wave_button.text = "重新生成群怪"
	wave_button.pressed.connect(reset_practice)
	column.add_child(wave_button)
	var auto := CheckBox.new()
	auto.text = "清场后自动刷新下一波"
	auto.button_pressed = true
	auto.toggled.connect(func(value: bool): auto_wave = value)
	column.add_child(auto)
	var shake_label := Label.new()
	shake_label.text = "镜头冲击强度（0 可关闭）"
	column.add_child(shake_label)
	var shake := HSlider.new()
	shake.min_value = 0
	shake.max_value = 1
	shake.step = 0.05
	shake.value = shake_strength
	shake.value_changed.connect(func(value: float): shake_strength = value)
	column.add_child(shake)
	_lab_status = Label.new()
	_lab_status.add_theme_font_size_override("font_size", 17)
	column.add_child(_lab_status)
	var back := Button.new()
	back.text = "返回标题"
	back.pressed.connect(hud.to_menu)
	column.add_child(back)

func reset_practice() -> void:
	if lab_beam == null:
		super.reset_practice()
		return
	skills.clear_effects()
	skills.reset_cooldowns()
	for target in get_tree().get_nodes_in_group("card_targets"):
		if world.is_ancestor_of(target): target.queue_free()
	_interactions.clear()
	wave += 1
	alive = 0
	_wave_delay = -1.0
	player.health = player.max_health
	player.position = _at(Vector2(770, 750))
	_last_player_position = player.position
	for y in range(4):
		for x in range(7):
			var at: Vector3 = _at(Vector2(400 + x * 120, 350 + y * 88))
			var blocked := false
			for rect in _art._blocks:
				if rect.grow(16).has_point(_art.to_pixel(at)): blocked = true
			if blocked or not _art.is_walkable(at): continue
			var enemy := CharacterBody3D.new()
			enemy.set_script(ECHO)
			enemy.set("max_health", 24.0 if y % 2 == 0 else 38.0)
			enemy.set("move_speed", 0.7 + minf(wave * 0.06, 0.6))
			enemy.position = at
			enemy.defeated.connect(_lab_kill)
			world.add_child(enemy)
			alive += 1

func _lab_kill(_enemy: Node) -> void:
	alive -= 1
	if alive == 0: _wave_delay = 1.4

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_shake_left = maxf(0, _shake_left - delta)
	if _wave_delay >= 0 and auto_wave:
		_wave_delay -= delta
		if _wave_delay <= 0: reset_practice()

func _process(delta: float) -> void:
	super._process(delta)
	if _lab_status != null:
		_lab_status.text = "第%d波 · 剩余%d\n命中%d · 反弹%d · 回程命中%d" % [wave, alive, lab_beam.hits, lab_beam.bounces, lab_beam.return_hits]
		for i in range(1, 5): hud._cards[i].hide()
		hud._selected = 0

func set_camera_shake(strength: float) -> void:
	_shake_power = strength * shake_strength
	_shake_left = 0.1

func _update_camera(delta: float) -> void:
	super._update_camera(delta)
	if _shake_left > 0:
		var t := float(Time.get_ticks_msec()) * 0.09
		var fade := pow(_shake_left / 0.1, 2)
		camera.position += Vector3(sin(t), cos(t * 1.3), 0) * _shake_power * fade

func get_hud_status() -> String:
	return "规则实验室 · 群怪清场 · 练习中免伤"

func get_interaction_hint() -> String:
	return "按住中键蓄力，松开发射 · 短按轻击，蓄满重击 · CD 0.65秒 · WASD移动"
