extends CanvasLayer

var room: Node
var title: Label
var objective: Label
var hint: Label
var hp: ProgressBar
var boss_panel: VBoxContainer
var boss_hp: ProgressBar
var boss_status: Label
var panel: PanelContainer
var panel_content: VBoxContainer
var backdrop: ColorRect
var modal_open := false
var choice_required := false
var _selected := 0
var _middle_held := false
var _cards: Array[Button] = []
var _skill_hint: Label
var _loss_shown := false
var _cooldown_masks: Array[ColorRect] = []
var _cooldown_labels: Array[Label] = []
var _message := ""
var _message_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	room = get_parent()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := PanelContainer.new()
	header.position = Vector2(30, 24)
	header.custom_minimum_size = Vector2(620, 134)
	header.add_theme_stylebox_override("panel", _style(Color(0.045, 0.075, 0.09, 0.95)))
	root.add_child(header)
	var column := VBoxContainer.new()
	header.add_child(column)
	title = _label("第一关 · 连续清场" if room.combat_only and not room.card_practice else "第一关 · 被撤销的一天", 26)
	column.add_child(title)
	objective = _label("", 20)
	column.add_child(objective)
	hp = ProgressBar.new()
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 12)
	column.add_child(hp)
	var notebook := Button.new()
	notebook.text = "本局构筑 [Tab]" if room.combat_only and not room.card_practice else "调查记录 [Tab]"
	notebook.position = Vector2(1650, 26)
	notebook.size = Vector2(230, 55)
	notebook.pressed.connect(show_notebook)
	root.add_child(notebook)
	hint = _label("WASD 移动 · E 查看 / 交互 · 左键攻击 · Shift / Space 闪避", 20)
	hint.position = Vector2(380, 820)
	hint.size.x = 1160
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var hand := Control.new()
	hand.position = Vector2(520, 905)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hand)
	for i in range(5):
		var card := Button.new()
		card.text = ["Ⅰ  雷贯光波", "Ⅱ  余烬回信", "Ⅲ  霜封档案", "Ⅳ  暗影骷髅", "Ⅴ  逆风回廊"][i]
		card.custom_minimum_size = Vector2(180, 70)
		card.size = Vector2(180, 85)
		card.position = Vector2(i * 174, absf(i - 2.0) * 10.0)
		card.pivot_offset = Vector2(90, 42)
		card.rotation_degrees = (i - 2) * 4.0
		card.set_meta("base_y", card.position.y)
		card.add_theme_font_size_override("font_size", 18)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand.add_child(card)
		_cards.append(card)
		var mask := ColorRect.new()
		mask.color = Color(0.015, 0.025, 0.05, 0.65)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.z_index = 1
		card.add_child(mask)
		_cooldown_masks.append(mask)
		var timer := _label("就绪", 16)
		timer.position = Vector2(0, 60)
		timer.size = Vector2(180, 22)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timer.z_index = 2
		card.add_child(timer)
		_cooldown_labels.append(timer)
	_skill_hint = _label("滚轮选牌 · 按住中键瞄准，松开施放", 18)
	_skill_hint.position = Vector2(480, 1006)
	root.add_child(_skill_hint)
	boss_panel = VBoxContainer.new()
	boss_panel.position = Vector2(690, 24)
	boss_panel.custom_minimum_size = Vector2(570, 0)
	root.add_child(boss_panel)
	boss_panel.add_child(_label("盖章者", 26))
	boss_hp = ProgressBar.new()
	boss_hp.custom_minimum_size = Vector2(570, 20)
	boss_hp.show_percentage = false
	boss_panel.add_child(boss_hp)
	boss_status = _label("", 18)
	boss_panel.add_child(boss_status)
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.02, 0.025, 0.78)
	backdrop.visible = false
	root.add_child(backdrop)
	panel = PanelContainer.new()
	panel.position = Vector2(440, 220)
	panel.size = Vector2(1040, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.095, 1)))
	backdrop.add_child(panel)
	panel_content = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 18)
	panel.add_child(panel_content)
	room.get("skills").connect("cast_denied", _skill_denied)
	if bool(room.get("card_practice")):
		var reset := Button.new()
		reset.text = "重置练习目标与 CD"
		reset.position = Vector2(1650, 96)
		reset.size = Vector2(230, 55)
		reset.pressed.connect(room.reset_practice)
		root.add_child(reset)
	if room.get("rogue") != null:
		var build_button := Button.new()
		build_button.text = "本局构筑 · 技能 / 遗物"
		build_button.position = Vector2(1590, 96)
		build_button.size = Vector2(290, 55)
		build_button.pressed.connect(_inspect_build)
		root.add_child(build_button)
	_update_cards()

func _inspect_build() -> void:
	if choice_required:
		return
	dialog("本局构筑", room.rogue.summary(), ["返回"], [Callable()])

func _process(delta: float) -> void:
	if not get_tree().paused:
		_message_left = maxf(0.0, _message_left - delta)
	_update_cards()
	objective.text = room.call("get_hud_status")
	hint.text = room.call("get_interaction_hint")
	var player: Node = room.get("player")
	if is_instance_valid(player):
		hp.max_value = player.max_health
		hp.value = player.health
		if player.health <= 0.0 and not _loss_shown:
			_loss_shown = true
			dialog("本局结束", "重新选技能，再来一局。", ["再来一局", "返回标题"], [restart, to_menu])
	var boss: Node = room.get("stamper")
	boss_panel.visible = is_instance_valid(boss) and not boss.dead
	if boss_panel.visible:
		boss_hp.max_value = boss.max_health
		boss_hp.value = boss.health
		boss_status.text = boss.status

func dialog(heading: String, body: String, options: Array, callbacks: Array) -> void:
	choice_required = false
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	panel_content.add_child(_label(heading, 30))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(970, 260)
	panel_content.add_child(scroll)
	var text := _label(body, 22)
	text.custom_minimum_size.x = 930
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(text)
	for i in range(options.size()):
		var button := Button.new()
		button.text = options[i]
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_choose.bind(callbacks[i]))
		panel_content.add_child(button)
	modal_open = true
	backdrop.visible = true
	var player: Node = room.get("player")
	if is_instance_valid(player):
		player.call("cancel_beam_charge")
	room.get("skills").call("cancel_aim")
	_middle_held = false
	get_tree().paused = true

func _choose(callback: Callable) -> void:
	close_dialog()
	if callback.is_valid():
		callback.call()

func close_dialog() -> void:
	choice_required = false
	modal_open = false
	backdrop.visible = false
	get_tree().paused = false

func show_notebook() -> void:
	if choice_required:
		return
	if modal_open:
		return
	if room.combat_only and room.get("rogue") != null:
		dialog("本局构筑", room.rogue.summary(), ["继续战斗"], [Callable()])
		return
	dialog("调查记录 · 方框内为可核对资料", room.call("notebook_text"), ["返回调查"], [Callable()])

func _unhandled_input(event: InputEvent) -> void:
	if choice_required:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if modal_open:
				close_dialog()
			else:
				show_notebook()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if modal_open and not _loss_shown:
				close_dialog()
			elif not modal_open:
				dialog("暂停", "战斗已暂停。", ["继续", "重新开始", "返回标题"], [Callable(), restart, to_menu])
			get_viewport().set_input_as_handled()
	if modal_open or get_tree().paused or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	var player: Node = room.get("player")
	var skills: Node = room.get("skills")
	if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var step := -1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		for attempt in range(5):
			_selected = posmod(_selected + step, 5)
			if (is_instance_valid(skills.rule_beam) and _selected == 0) or (not is_instance_valid(skills.rule_beam) and (room.get("rogue") == null or room.rogue.enabled[_selected])):
				break
		player.call("set_selected_card", _selected)
		if _middle_held:
			skills.call("cancel_aim")
			skills.call("begin_aim", _selected)
	elif mouse.button_index == MOUSE_BUTTON_MIDDLE:
		if mouse.pressed:
			_middle_held = true
			skills.call("begin_aim", _selected)
		elif _middle_held:
			_middle_held = false
			skills.call("release_aim")
	if mouse.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
	_update_cards()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_middle_held = false

func _update_cards() -> void:
	var skills: Node = room.get("skills")
	var names := ["雷贯光波", "余烬回信", "霜封档案", "暗影骷髅", "逆风回廊"]
	var colors := [Color(0.65, 0.58, 1), Color(1, 0.48, 0.25), Color(0.5, 0.91, 1), Color(0.62, 0.95, 0.76), Color(0.4, 0.88, 0.71)]
	for i in range(_cards.size()):
		_cards[i].modulate = colors[i] if i == _selected else colors[i] * Color(0.75, 0.75, 0.75, 1)
		_cards[i].position.y = float(_cards[i].get_meta("base_y")) - (18.0 if i == _selected else 0.0)
		var owned: bool = (i == 0) if is_instance_valid(skills.rule_beam) else (room.get("rogue") == null or room.rogue.enabled[i])
		_cards[i].visible = owned
		var left: float = skills.cooldowns[i]
		_cooldown_masks[i].size = Vector2(180, 85.0 * left / skills.cooldown_duration(i))
		_cooldown_labels[i].text = ("%.1f 秒" % left if left < 3.0 else "%d 秒" % ceili(left)) if left > 0.0 else ("瞄准中" if skills.aim_index == i else "就绪")
	_skill_hint.text = "「%s」· 滚轮选牌 · 按住中键瞄准，松开施放" % names[_selected]
	if _message_left > 0.0:
		_skill_hint.text = _message

func _skill_denied(reason: String) -> void:
	_message = reason
	_message_left = 1.2

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _label(value: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color(0.86, 0.85, 0.76))
	return node

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.49, 0.64, 0.65)
	style.set_border_width_all(2)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style
