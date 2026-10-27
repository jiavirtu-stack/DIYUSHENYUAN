extends Control

## 阶段 0 菜单入口；战斗场景目前为空白基线。

@onready var start_button: Button = $StartButton
@onready var settings_button: Button = $SettingsButton
@onready var exit_button: Button = $ExitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_show_settings)
	exit_button.pressed.connect(get_tree().quit)
	for button in [start_button, settings_button, exit_button]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16,0.105,0.075)
		style.border_color = Color(0.56,0.36,0.21)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("normal",style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.29,0.17,0.105)
		button.add_theme_stylebox_override("hover",hover)


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
	get_tree().change_scene_to_file("res://scenes/arena.tscn")
