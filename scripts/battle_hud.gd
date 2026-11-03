extends CanvasLayer
class_name BattleHUD

var player: FairytalePlayer
var boss: RitualBriarBoss
var player_bar: ProgressBar
var boss_bar: ProgressBar
var dodge_bar: ProgressBar
var boss_state_label: Label
var _room_status_label: Label
var pause_panel: PanelContainer
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var reward_row: HBoxContainer
var replay_button: Button
var _result_shown := false
var _reward_selected := false
var _card_hand: Control
var _card_panels: Array[PanelContainer] = []
var _card_status_labels: Array[Label] = []
var _card_hint: Label
var _selected_card := 0
var _locked_card := -1
var _lock_click_release_pending := false
var _card_titles := ["直线光波", "灼热新星", "裂地冲击", "追踪灵弹", "暗影牢笼"]
var _card_symbols := ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"]
var _debug_panel: PanelContainer
var _layout_status: Label
var _layout_controls: Dictionary = {}
var _layout_values: Dictionary = {
	"offset_x": 0.0,
	"offset_y": 0.0,
	"spacing": 207.0,
	"fan_angle": 14.0,
	"fan_lift": 25.0,
	"card_width": 220.0,
	"card_height": 270.0,
}
const CARD_LAYOUT_FILE := "user://card_layout.cfg"
const CARD_LAYOUT_DEFAULTS := {
	"offset_x": 0.0,
	"offset_y": 0.0,
	"spacing": 207.0,
	"fan_angle": 14.0,
	"fan_lift": 25.0,
	"card_width": 220.0,
	"card_height": 270.0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_card_layout()
	player = get_parent().get_node_or_null("Player") as FairytalePlayer
	boss = get_parent().get_node_or_null("Boss") as RitualBriarBoss
	_build_ui()
	player.health_changed.connect(_on_player_health)
	if boss != null:
		boss.health_changed.connect(_on_boss_health)
		boss.state_changed.connect(_on_boss_state)
	player_bar.max_value = player.max_health
	player_bar.value = player.health
	if boss != null:
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health


func _process(_delta: float) -> void:
	pause_panel.visible = get_tree().paused and not _result_shown
	if is_instance_valid(player):
		dodge_bar.max_value = player.dodge_cooldown
		dodge_bar.value = player.dodge_cooldown - player.get("_dodge_cooldown_timer")
	if boss == null and _room_status_label != null:
		var room := get_parent()
		if room.has_method("get_hud_status"):
			_room_status_label.text = room.call("get_hud_status")
	if is_instance_valid(player) and player.health <= 0.0 and not _result_shown:
		_show_result(false)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 32; header.offset_top = 22; header.offset_right = -32; header.offset_bottom = 124
	root.add_child(header)
	var player_box := _card(); header.add_child(player_box)
	var pv := VBoxContainer.new(); player_box.add_child(pv)
	pv.add_child(_label("灰铃旅人", 18, Color(0.92,0.79,0.58)))
	player_bar = _bar(Color(0.58,0.12,0.13)); pv.add_child(player_bar)
	dodge_bar = _bar(Color(0.79,0.55,0.22)); pv.add_child(dodge_bar)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
	var encounter_box := _card(); encounter_box.custom_minimum_size = Vector2(470,0); header.add_child(encounter_box)
	var encounter_content := VBoxContainer.new(); encounter_box.add_child(encounter_content)
	if boss != null:
		var boss_title := _label("仪式荆棘 · Boss 房", 18, Color(0.89,0.69,0.4)); boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; encounter_content.add_child(boss_title)
		boss_state_label = _label("显形", 14, Color(0.75,0.69,0.57)); boss_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; encounter_content.add_child(boss_state_label)
		boss_bar = _bar(Color(0.56,0.23,0.16)); encounter_content.add_child(boss_bar)
	else:
		var room_title := _label("沉没村落 · 清剿区域", 18, Color(0.89,0.69,0.4)); room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; encounter_content.add_child(room_title)
		_room_status_label = _label("正在搜索区域…", 15, Color(0.75,0.69,0.57)); _room_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; encounter_content.add_child(_room_status_label)
	_card_hand = Control.new()
	_card_hand.name = "CardHand"
	_card_hand.anchor_left = 0.5
	_card_hand.anchor_right = 0.5
	_card_hand.anchor_top = 1.0
	_card_hand.anchor_bottom = 1.0
	_card_hand.offset_left = -560
	_card_hand.offset_right = 560
	_card_hand.offset_top = -445
	_card_hand.offset_bottom = -128
	_card_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card_hand)
	_build_card_hand()
	_card_hint = _label("滚轮选择 · 中键单击锁定 · 再按住中键瞄准、松开发射 · 右键解除 · F1 布局调试", 15, Color(0.82,0.75,0.65))
	_card_hint.anchor_left=0.5; _card_hint.anchor_right=0.5; _card_hint.anchor_top=1; _card_hint.anchor_bottom=1; _card_hint.offset_left=-560; _card_hint.offset_right=560; _card_hint.offset_top=-40; _card_hint.offset_bottom=-12; _card_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _card_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(_card_hint)
	_build_card_layout_tool(root)
	pause_panel = _make_modal(root)
	_pause_content()
	result_panel = _make_modal(root)
	_result_content()
	_update_card_selection()


func _build_card_hand() -> void:
	var subtitles := ["蓄力后射出贯穿光束", "范围爆发 · 效果待制作", "地面冲击 · 效果待制作", "追踪弹 · 效果待制作", "束缚区域 · 效果待制作"]
	for index in range(_card_titles.size()):
		var card := PanelContainer.new()
		card.name = "TestCard_%d" % (index + 1)
		card.position = Vector2(20.0 + index * 207.0, 25.0 if index in [0, 4] else (10.0 if index in [1, 3] else 0.0))
		card.size = Vector2(220.0, 270.0)
		card.pivot_offset = card.size * 0.5
		card.rotation_degrees = [-14.0, -7.0, 0.0, 7.0, 14.0][index]
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _card_style(index == _selected_card))
		_card_hand.add_child(card)
		_card_panels.append(card)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		var number := _label("测试卡牌  %02d" % (index + 1), 14, Color(0.72, 0.61, 0.46))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(number)
		var symbol := _label(_card_symbols[index], 54, Color(0.94, 0.76, 0.42) if index == 0 else Color(0.62, 0.55, 0.48))
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(symbol)
		var title := _label(_card_titles[index], 20, Color(0.94, 0.82, 0.63))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)
		var subtitle := _label(subtitles[index], 13, Color(0.66, 0.61, 0.55))
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(subtitle)
		var status := _label("", 13, Color(0.96, 0.72, 0.35))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(status)
		_card_status_labels.append(status)


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.049, 0.96)
	style.border_color = Color(0.96, 0.68, 0.29, 1.0) if selected else Color(0.37, 0.26, 0.19, 0.96)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 13
	style.content_margin_bottom = 12
	return style


func _update_card_selection() -> void:
	_apply_card_layout()
	for index in range(_card_panels.size()):
		var card := _card_panels[index]
		var is_locked := index == _locked_card
		var is_selected := index == _selected_card and _locked_card < 0
		card.add_theme_stylebox_override("panel", _card_style(is_locked or is_selected))
		card.z_index = 20 if is_locked or is_selected else index
		var arc_position := absf(float(index) - 2.0) / 2.0
		var base_y := float(_layout_values["fan_lift"]) * arc_position
		if is_locked:
			card.position.y = base_y - 52.0
			card.scale = Vector2.ONE * 1.12
			card.modulate = Color.WHITE
		elif _locked_card >= 0:
			card.position.y = base_y + 48.0
			card.scale = Vector2.ONE * 0.92
			card.modulate = Color(0.58, 0.55, 0.52, 0.78)
		else:
			card.position.y = base_y - (24.0 if is_selected else 0.0)
			card.scale = Vector2.ONE * (1.06 if is_selected else 1.0)
			card.modulate = Color.WHITE
		if index < _card_status_labels.size():
			if is_locked:
				_card_status_labels[index].text = "已锁定"
			elif is_selected:
				_card_status_labels[index].text = "当前选择"
			else:
				_card_status_labels[index].text = "待选择" if _locked_card < 0 else "收起"
	var player_node := get_parent().get_node_or_null("Player")
	if player_node != null and player_node.has_method("set_selected_card"):
		player_node.call("set_selected_card", _selected_card)


func _apply_card_layout() -> void:
	if not is_instance_valid(_card_hand):
		return
	var spacing := float(_layout_values["spacing"])
	var card_width := float(_layout_values["card_width"])
	var group_width := card_width + spacing * 4.0 + 40.0
	var x_offset := float(_layout_values["offset_x"])
	var y_offset := float(_layout_values["offset_y"])
	_card_hand.offset_left = -group_width * 0.5 + x_offset
	_card_hand.offset_right = group_width * 0.5 + x_offset
	_card_hand.offset_top = -445.0 + y_offset
	_card_hand.offset_bottom = -128.0 + y_offset
	for index in range(_card_panels.size()):
		var card := _card_panels[index]
		card.position.x = 20.0 + index * spacing
		card.size = Vector2(card_width, float(_layout_values["card_height"]))
		card.pivot_offset = card.size * 0.5
		card.rotation_degrees = (float(index) - 2.0) * 0.5 * float(_layout_values["fan_angle"])


func _build_card_layout_tool(root: Control) -> void:
	var toggle := Button.new()
	toggle.name = "CardLayoutToggle"
	toggle.text = "卡牌布局工具 · F1"
	toggle.position = Vector2(32.0, 138.0)
	toggle.size = Vector2(210.0, 38.0)
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.add_theme_stylebox_override("normal", _panel_style(0.96))
	toggle.add_theme_color_override("font_color", Color(0.91, 0.76, 0.54))
	root.add_child(toggle)
	toggle.pressed.connect(_toggle_layout_tool)

	_debug_panel = PanelContainer.new()
	_debug_panel.name = "CardLayoutDebugPanel"
	_debug_panel.position = Vector2(32.0, 184.0)
	_debug_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_debug_panel.add_theme_stylebox_override("panel", _panel_style(0.97))
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_panel.visible = false
	root.add_child(_debug_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_debug_panel.add_child(content)
	var heading := _label("卡牌扇形布局", 20, Color(0.94, 0.76, 0.46))
	content.add_child(heading)
	var description := _label("未锁定时滚轮切牌；中键锁定，右键解除。", 13, Color(0.68, 0.62, 0.55))
	content.add_child(description)
	_add_layout_slider(content, "水平位置", "offset_x", -400.0, 400.0, 5.0, " px")
	_add_layout_slider(content, "垂直位置", "offset_y", -250.0, 70.0, 5.0, " px")
	_add_layout_slider(content, "卡牌间距", "spacing", 120.0, 280.0, 1.0, " px")
	_add_layout_slider(content, "扇形角度", "fan_angle", 0.0, 36.0, 1.0, "°")
	_add_layout_slider(content, "扇形弧度", "fan_lift", 0.0, 120.0, 1.0, " px")
	_add_layout_slider(content, "卡牌宽度", "card_width", 160.0, 300.0, 1.0, " px")
	_add_layout_slider(content, "卡牌高度", "card_height", 190.0, 360.0, 1.0, " px")
	_layout_status = _label("当前布局尚未保存", 13, Color(0.69, 0.63, 0.55))
	content.add_child(_layout_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)
	var save_button := _button("保存布局")
	save_button.custom_minimum_size = Vector2(145.0, 36.0)
	buttons.add_child(save_button)
	save_button.pressed.connect(_save_card_layout)
	var reset_button := _button("恢复默认")
	reset_button.custom_minimum_size = Vector2(145.0, 36.0)
	buttons.add_child(reset_button)
	reset_button.pressed.connect(_reset_card_layout)


func _add_layout_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float, step: float, suffix: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 0)
	parent.add_child(group)
	var header := HBoxContainer.new()
	group.add_child(header)
	var title_label := _label(title, 14, Color(0.84, 0.77, 0.67))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var value_label := _label("", 14, Color(0.94, 0.73, 0.43))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = clampf(float(_layout_values[key]), minimum, maximum)
	slider.custom_minimum_size = Vector2(300.0, 20.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(slider)
	_layout_controls[key] = slider
	_update_layout_value_label(value_label, slider.value, suffix)
	slider.value_changed.connect(_on_layout_slider_changed.bind(key, value_label, suffix))


func _on_layout_slider_changed(value: float, key: String, value_label: Label, suffix: String) -> void:
	_layout_values[key] = value
	_update_layout_value_label(value_label, value, suffix)
	_apply_card_layout()
	_update_card_selection()
	_layout_status.text = "布局已更新，点击保存后下次启动保留。"


func _update_layout_value_label(label: Label, value: float, suffix: String) -> void:
	var shown_value := int(round(value))
	label.text = "%d%s" % [shown_value, suffix]


func _toggle_layout_tool() -> void:
	_debug_panel.visible = not _debug_panel.visible


func _load_card_layout() -> void:
	var config := ConfigFile.new()
	if config.load(CARD_LAYOUT_FILE) != OK:
		return
	for key in CARD_LAYOUT_DEFAULTS:
		_layout_values[key] = config.get_value("card_layout", key, CARD_LAYOUT_DEFAULTS[key])
	_layout_values["offset_y"] = clampf(float(_layout_values["offset_y"]), -250.0, 70.0)


func _save_card_layout() -> void:
	var config := ConfigFile.new()
	for key in _layout_values:
		config.set_value("card_layout", key, _layout_values[key])
	var error := config.save(CARD_LAYOUT_FILE)
	_layout_status.text = "布局已保存" if error == OK else "保存失败：%s" % error_string(error)


func _reset_card_layout() -> void:
	for key in CARD_LAYOUT_DEFAULTS:
		_layout_values[key] = CARD_LAYOUT_DEFAULTS[key]
		var slider := _layout_controls.get(key) as HSlider
		if slider != null:
			slider.value = float(_layout_values[key])
	_apply_card_layout()
	_update_card_selection()
	_layout_status.text = "已恢复默认值；需要保留请点击保存。"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			_debug_panel.visible = not _debug_panel.visible
			get_viewport().set_input_as_handled()
			return
	if get_tree().paused or _result_shown:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			if _locked_card < 0:
				_selected_card = posmod(_selected_card - 1, _card_titles.size())
				_update_card_selection()
			else:
				_card_hint.text = "「%s」已锁定：右键取消后才能切换卡牌" % _card_titles[_locked_card]
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			if _locked_card < 0:
				_selected_card = posmod(_selected_card + 1, _card_titles.size())
				_update_card_selection()
			else:
				_card_hint.text = "「%s」已锁定：右键取消后才能切换卡牌" % _card_titles[_locked_card]
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and _locked_card >= 0:
			var player_node := get_parent().get_node_or_null("Player")
			if player_node != null and player_node.has_method("cancel_beam_charge"):
				player_node.call("cancel_beam_charge")
			_locked_card = -1
			_lock_click_release_pending = false
			_update_card_selection()
			_card_hint.text = "滚轮选择 · 中键单击锁定 · 再按住中键瞄准、松开发射 · 右键解除 · F1 布局调试"
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			var player_node := get_parent().get_node_or_null("Player")
			if mouse_event.pressed:
				if _locked_card < 0:
					_locked_card = _selected_card
					_lock_click_release_pending = true
					_update_card_selection()
					_card_hint.text = "已锁定「%s」；松开后再按住中键瞄准、松开发射 · 右键解除" % _card_titles[_locked_card]
				else:
					if _locked_card == 0 and player_node != null:
						player_node.call("begin_beam_charge")
					else:
						_card_hint.text = "「%s」已锁定，但该卡效果尚未制作 · 右键解除" % _card_titles[_locked_card]
				get_viewport().set_input_as_handled()
			elif _lock_click_release_pending:
				_lock_click_release_pending = false
				get_viewport().set_input_as_handled()
			elif _locked_card >= 0 and player_node != null and player_node.has_method("release_beam"):
				player_node.call("release_beam")
				get_viewport().set_input_as_handled()


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.88))
	panel.custom_minimum_size = Vector2(350,0)
	return panel


func _make_modal(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-310; panel.offset_top=-185; panel.offset_right=310; panel.offset_bottom=185
	panel.add_theme_stylebox_override("panel", _panel_style(0.97))
	panel.visible=false
	parent.add_child(panel)
	return panel


func _panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=Color(0.075,0.052,0.049,alpha); style.border_color=Color(0.48,0.31,0.19,0.95); style.set_border_width_all(2); style.set_corner_radius_all(7); style.content_margin_left=22; style.content_margin_right=22; style.content_margin_top=17; style.content_margin_bottom=17
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",color); label.add_theme_color_override("font_shadow_color",Color(0.02,0.01,0.01,0.8)); label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)
	return label


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new(); bar.custom_minimum_size=Vector2(310,18); bar.show_percentage=false
	var bg := StyleBoxFlat.new(); bg.bg_color=Color(0.12,0.09,0.085); bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new(); fill.bg_color=color; fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background",bg); bar.add_theme_stylebox_override("fill",fill)
	return bar


func _pause_content() -> void:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",14); pause_panel.add_child(box)
	box.add_child(_label("仪式暂停",28,Color(0.88,0.73,0.51)))
	var resume := _button("继续战斗"); box.add_child(resume); resume.pressed.connect(func(): get_tree().paused=false)
	var restart := _button("重新挑战"); box.add_child(restart); restart.pressed.connect(_restart)
	var menu := _button("返回标题"); box.add_child(menu); menu.pressed.connect(_to_menu)


func _result_content() -> void:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); result_panel.add_child(box)
	result_title=_label("",30,Color(0.9,0.74,0.49)); result_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(result_title)
	result_text=_label("",17,Color(0.8,0.73,0.62)); result_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(result_text)
	reward_row=HBoxContainer.new(); reward_row.alignment=BoxContainer.ALIGNMENT_CENTER; reward_row.add_theme_constant_override("separation",10); box.add_child(reward_row)
	for i in range(3):
		var labels=["攻击力 +20%","闪避冷却 -20%","生命上限 +25"]
		var button:=_button(labels[i]); button.custom_minimum_size=Vector2(160,62); reward_row.add_child(button); button.pressed.connect(_select_reward.bind(i,labels[i]))
	replay_button=_button("再战一局"); box.add_child(replay_button); replay_button.pressed.connect(_restart)
	var menu:=_button("返回标题"); box.add_child(menu); menu.pressed.connect(_to_menu)


func _button(text: String) -> Button:
	var button:=Button.new(); button.text=text; button.custom_minimum_size=Vector2(230,44); button.add_theme_font_size_override("font_size",17)
	var normal:=_panel_style(1.0); normal.bg_color=Color(0.18,0.12,0.09); button.add_theme_stylebox_override("normal",normal)
	var hover:=_panel_style(1.0); hover.bg_color=Color(0.30,0.18,0.11); button.add_theme_stylebox_override("hover",hover); button.add_theme_stylebox_override("pressed",hover)
	return button


func _on_player_health(current: float, maximum: float) -> void:
	player_bar.max_value=maximum; player_bar.value=current
	if current <= 0.0: _show_result(false)


func _on_boss_health(current: float, maximum: float) -> void:
	if boss_bar == null:
		return
	boss_bar.max_value=maximum; boss_bar.value=current


func _on_boss_state(state_name: String) -> void:
	if boss_state_label == null:
		return
	boss_state_label.text=state_name.replace("_"," ")
	if state_name == "PHASE_TRANSITION": boss_state_label.text="第二阶段 · 腐化苏醒"
	if state_name == "DEATH": _show_result(true)


func _show_result(won: bool) -> void:
	if _result_shown: return
	_result_shown=true
	get_tree().paused=true
	result_panel.visible=true
	reward_row.visible=won
	replay_button.visible=not won
	result_title.text="仪式终结" if won else "旅人倒下"
	result_text.text="选择一项仪式遗物，再次挑战。" if won else "调整步伐，再试一次。"


func _select_reward(index: int, label: String) -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.selected_buff=index
		run_state.last_buff_label=label
	_reward_selected=true
	result_text.text="已获得："+label+"。点击再战开始新的仪式。"
	reward_row.visible=false
	replay_button.visible=true


func _restart() -> void:
	get_tree().paused=false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused=false
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null: run_state.selected_buff=-1
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
