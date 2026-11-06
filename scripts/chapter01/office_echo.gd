extends "res://scripts/corrupted_villager.gd"

func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	_body_material = _material(Color(0.18, 0.24, 0.28), 0.95)
	_add_box("EmptySuit", Vector3(0.8, 0.95, 0.42), Vector3(0, 0.95, 0), _body_material)
	_add_box("LeftLeg", Vector3(0.23, 0.55, 0.25), Vector3(-0.23, 0.28, 0), _body_material)
	_add_box("RightLeg", Vector3(0.23, 0.55, 0.25), Vector3(0.23, 0.28, 0), _body_material)
	_add_box("LabelFace", Vector3(0.54, 0.5, 0.45), Vector3(0, 1.65, 0), _material(Color(0.69, 0.65, 0.54), 1.0))
	var label := Label3D.new()
	label.text = "必须完美" if max_health > 60 else "迟交"
	label.position = Vector3(0, 2.3, 0)
	label.font_size = 32
	label.pixel_size = 0.014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_root.add_child(label)
	_telegraph = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.5, 0.035, 2.5)
	_telegraph.mesh = mesh
	var material := _material(Color(0.8, 0.12, 0.08, 0.5), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph.material_override = material
	_telegraph.position.y = 0.05
	_telegraph.visible = false
	_visual_root.add_child(_telegraph)
