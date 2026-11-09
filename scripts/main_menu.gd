extends Control

## 阶段 0 菜单入口；战斗场景目前为空白基线。

@onready var start_button: Button = $StartButton
@onready var settings_button: Button = $SettingsButton
@onready var exit_button: Button = $ExitButton
var _entries: Array[Button] = []
var _selected := 0
var _diamond: Label
var _dust: Control
var _pixel_labels: Array[Label] = []
var _pixel_views: Array[SubViewport] = []


func _ready() -> void:
	for child_name in ["Background", "Title", "Subtitle", "Hint"]:
		get_node(child_name).hide()
	var art := Control.new()
	art.set_script(load("res://scripts/title_fall.gd"))
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.z_index = -10
	add_child(art)
	_dust = Control.new()
	_dust.set_script(load("res://scripts/title_dust.gd"))
	_dust.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dust.z_index = -1
	add_child(_dust)
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_show_settings)
	exit_button.pressed.connect(get_tree().quit)
	var practice := Button.new()
	practice.text = "卡牌练习 · 五技能"
	practice.position = Vector2(1550, 1008)
	practice.size = Vector2(290, 42)
	practice.add_theme_font_size_override("font_size", 20)
	practice.flat = true
	practice.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/chapter01/card_practice.tscn"))
	add_child(practice)
	_entries = [start_button, settings_button, exit_button]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimHei", "Microsoft YaHei"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var heavy := FontVariation.new()
	heavy.base_font = font
	heavy.variation_embolden = 0.7
	for i in range(3):
		var button := _entries[i]
		button.text = ["开始游戏", "设置", "退出游戏"][i]
		button.position = Vector2(150, 740 + i * 75)
		button.size = Vector2(320, 66)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 48)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_hover_color", Color(0.98, 0.98, 0.94))
		button.add_theme_color_override("font_focus_color", Color(0.98, 0.98, 0.94))
		button.mouse_entered.connect(_select.bind(i))
		button.focus_entered.connect(_select.bind(i))
		# Render at a real 16px grid, then scale with nearest filtering. This
		# keeps stepped pixel strokes and the thick outline at every resolution.
		for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			button.add_theme_color_override(color_name, Color.TRANSPARENT)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(84, 24)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		button.add_child(viewport)
		var glyph := Label.new()
		glyph.text = button.text
		glyph.position = Vector2(3, 2)
		glyph.add_theme_font_override("font", heavy)
		glyph.add_theme_font_size_override("font_size", 16)
		glyph.add_theme_constant_override("outline_size", 2)
		glyph.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.025))
		viewport.add_child(glyph)
		_pixel_labels.append(glyph)
		_pixel_views.append(viewport)
		var pixels := TextureRect.new()
		pixels.texture = viewport.get_texture()
		pixels.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pixels.position = Vector2(-9, -3)
		pixels.size = Vector2(252, 72)
		pixels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(pixels)
	_diamond = Label.new()
	_diamond.text = "◆"
	_diamond.add_theme_font_size_override("font_size", 40)
	_diamond.add_theme_constant_override("outline_size", 5)
	_diamond.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025))
	_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_diamond)
	_select(0)

func _select(index: int) -> void:
	_selected = posmod(index, 3)
	_dust.set("selected", _selected)
	for i in range(3):
		_pixel_labels[i].add_theme_color_override("font_color", Color(0.98, 0.98, 0.98) if i == _selected else Color(0.57, 0.79, 0.91))
		_pixel_views[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	_diamond.position = Vector2(94, 751 + _selected * 75)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_down") or event.is_action("ui_up"):
		_select(_selected + (1 if event.is_action("ui_down") else -1))
		_entries[_selected].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_accept"):
		_entries[_selected].pressed.emit()
		get_viewport().set_input_as_handled()


func _show_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "声音设置"
	dialog.dialog_text = "调整音量后关闭此窗口。"
	var content := VBoxContainer.new()
	for bus_name in ["Master", "SFX", "Ambience", "Music", "UI"]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0: continue
		var row := HBoxContainer.new()
		var label := Label.new(); label.text = bus_name; label.custom_minimum_size.x = 110; row.add_child(label)
		var slider := HSlider.new(); slider.min_value = -36.0; slider.max_value = 6.0; slider.value = AudioServer.get_bus_volume_db(bus_index); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(slider)
		slider.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(bus_index, value))
		content.add_child(row)
	dialog.add_child(content)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,360))


func _on_start_pressed() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.carried_health = -1.0
		run_state.cleared_rooms = 0
	get_tree().change_scene_to_file("res://scenes/chapter01/revoked_day.tscn")
