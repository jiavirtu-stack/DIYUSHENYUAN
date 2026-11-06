extends StaticBody3D

signal defeated
signal phase_changed(value: int)

var max_health := 260.0
var health := 260.0
var phase := 1
var dead := false
var exposed := false
var status := "合并：迟交 = 患病 = 被辞退 = 无用"
var _clock := 1.8
var _step := 0
var _state := "idle"
var _impact := Vector3.ZERO
var _visual: Node3D
var _head: Node3D
var _warning: MeshInstance3D
var _core: MeshInstance3D
var _shells: Array[Node3D] = []
var _art_sprite: Sprite3D

func _ready() -> void:
	collision_layer = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.5, 4.0, 2.2)
	collision.shape = shape
	collision.position.y = 2.0
	add_child(collision)
	_build_visual()

func _physics_process(delta: float) -> void:
	if dead:
		return
	_clock -= delta
	_head.position.y = 3.7 + sin(Time.get_ticks_msec() * 0.002) * 0.12
	if _clock > 0.0:
		return
	var room := get_parent().get_parent()
	if _state == "warning":
		if is_instance_valid(_warning):
			_warning.queue_free()
		room.call("stamp_impact", _impact, Vector2(4.0, 4.0))
		exposed = true
		_state = "recovery"
		status = "纸芯暴露 · 攻击印章柄 / 白色纸芯"
		_clock = 2.4 if phase == 1 else 1.8
		_art_sprite.scale = Vector3(1.04, 0.95, 1.0)
	elif _state == "recovery":
		exposed = false
		_visual.position.y = 0.0
		_art_sprite.scale = Vector3.ONE
		_state = "idle"
		room.call("send_paper_wall", _step)
		status = "纸墙推进 · 攻击纸墙可撕开通路"
		_clock = 2.0
	else:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return
		_impact = Vector3(snappedf(player.position.x, 2.0), 0.0, snappedf(player.position.z, 2.0))
		_clock = 1.05 if phase == 1 else 0.8
		_warning = room.call("warning_rect", _impact, Vector2(4.0, 4.0), _clock) as MeshInstance3D
		_state = "warning"
		_art_sprite.scale = Vector3(0.98, 1.04, 1.0)
		status = "矩形落印预警 · 离开红框"
		_step += 1

func receive_hit(damage: float, _knockback: Vector3, _at: Vector3) -> void:
	if dead:
		return
	# Shell can be chipped; recovery windows expose the vulnerable paper core.
	health = maxf(0.0, health - damage * (1.0 if exposed or phase == 2 else 0.3))
	if phase == 1 and health <= max_health * 0.5:
		phase = 2
		for shell in _shells:
			shell.visible = false
		_core.scale = Vector3(1.5, 1.0, 1.5)
		_art_sprite.frame = 1
		phase_changed.emit(phase)
	if health <= 0.0:
		dead = true
		collision_layer = 0
		if is_instance_valid(_warning):
			_warning.queue_free()
		defeated.emit()
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3(0.1, 0.1, 0.1), 0.6)

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_core = _box(Vector3(1.1, 3.2, 1.1), Vector3(0, 1.9, 0), Color(0.9, 0.86, 0.72), _visual)
	for i in range(6):
		var book := _box(Vector3(2.3, 0.45, 1.8), Vector3(sin(i * 2.1) * 0.35, 0.5 + i * 0.45, 0), Color(0.26, 0.17, 0.16), _visual)
		book.rotation.y = i * 0.4
		_shells.append(book)
		var paper := _box(Vector3(2.05, 0.23, 1.82), Vector3(0, 0, 0), Color(0.65, 0.59, 0.48), book)
		paper.position.y = 0.02
	_box(Vector3(3.2, 0.55, 2.4), Vector3(0, 0.4, 0), Color(0.45, 0.07, 0.08), _visual)
	_head = Node3D.new()
	_visual.add_child(_head)
	var mist := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.5
	mist.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.025, 0.04)
	mist.material_override = material
	_head.add_child(mist)
	for i in range(5):
		var wire := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.85
		ring.outer_radius = 0.9
		wire.mesh = ring
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.33, 0.36, 0.37)
		metal.metallic = 0.7
		wire.material_override = metal
		wire.rotation = Vector3(i * 0.63, i * 0.87, i * 0.43)
		_head.add_child(wire)
	for i in range(4):
		var label := Label3D.new()
		label.text = ["迟交", "患病", "被辞退", "无用？"][i]
		label.position = Vector3(-1.0 + (i % 2) * 2.0, 1.3 + floori(i / 2.0) * 1.4, 1.25)
		label.font_size = 40
		label.pixel_size = 0.012
		label.modulate = Color(0.95, 0.75, 0.65)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_visual.add_child(label)
	for child in _visual.get_children():
		(child as Node3D).visible = false
	_art_sprite = Sprite3D.new()
	_art_sprite.name = "StamperArt"
	_art_sprite.texture = load("res://assets/chapter01/stamper_forms.png")
	_art_sprite.hframes = 2
	_art_sprite.centered = false
	_art_sprite.offset = Vector2(-_art_sprite.texture.get_width() * 0.25, 0)
	_art_sprite.pixel_size = 9.0 / _art_sprite.texture.get_height()
	_art_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_art_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_art_sprite)

func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node
