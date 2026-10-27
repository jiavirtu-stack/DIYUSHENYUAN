extends CanvasLayer
class_name BattleHUD

var player: FairytalePlayer
var boss: RitualBriarBoss
var player_bar: ProgressBar
var boss_bar: ProgressBar
var dodge_bar: ProgressBar
var boss_state_label: Label
var pause_panel: PanelContainer
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var reward_row: HBoxContainer
var replay_button: Button
var _result_shown := false
var _reward_selected := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent().get_node_or_null("Player") as FairytalePlayer
	boss = get_parent().get_node_or_null("Boss") as RitualBriarBoss
	_build_ui()
	player.health_changed.connect(_on_player_health)
	boss.health_changed.connect(_on_boss_health)
	boss.state_changed.connect(_on_boss_state)
	player_bar.max_value = player.max_health
	player_bar.value = player.health
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.health


func _process(_delta: float) -> void:
	pause_panel.visible = get_tree().paused and not _result_shown
	if is_instance_valid(player):
		dodge_bar.max_value = player.dodge_cooldown
		dodge_bar.value = player.dodge_cooldown - player.get("_dodge_cooldown_timer")
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
	var boss_box := _card(); boss_box.custom_minimum_size = Vector2(470,0); header.add_child(boss_box)
	var bv := VBoxContainer.new(); boss_box.add_child(bv)
	var boss_title := _label("仪式荆棘 · 第一阶段", 18, Color(0.89,0.69,0.4)); boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; bv.add_child(boss_title)
	boss_state_label = _label("显形", 14, Color(0.75,0.69,0.57)); boss_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; bv.add_child(boss_state_label)
	boss_bar = _bar(Color(0.56,0.23,0.16)); bv.add_child(boss_bar)
	var hint := _label("WASD 移动 · Shift/Space 闪避 · 左键/J 攻击 · Esc 暂停", 15, Color(0.82,0.75,0.65))
	hint.anchor_left=0.5; hint.anchor_right=0.5; hint.anchor_top=1; hint.anchor_bottom=1; hint.offset_left=-340; hint.offset_right=340; hint.offset_top=-38; hint.offset_bottom=-12; hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root.add_child(hint)
	pause_panel = _make_modal(root)
	_pause_content()
	result_panel = _make_modal(root)
	_result_content()


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
	boss_bar.max_value=maximum; boss_bar.value=current


func _on_boss_state(state_name: String) -> void:
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
