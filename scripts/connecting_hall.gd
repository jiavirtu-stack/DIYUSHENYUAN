extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ROOM_SCENE := preload("res://scenes/infantry_room.tscn")

var _player: FairytalePlayer
var _camera: Camera3D
var _transitioning := false
var _environment: WorldEnvironment

func _ready() -> void:
	_build_hall()
	_player = PLAYER_SCENE.instantiate() as FairytalePlayer
	_player.position = Vector3(0, 0, 7)
	add_child(_player)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 15.0
	add_child(_camera)
	_camera.current = true
	_update_camera()
	var hud := CanvasLayer.new()
	hud.name = "BattleHUD"
	hud.set_script(load("res://scripts/battle_hud.gd"))
	add_child(hud)

func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_update_camera()
		if not _transitioning and _player.position.z <= -10.5:
			_transitioning = true
			var state := get_node_or_null("/root/RunState")
			if state != null:
				state.carried_health = _player.health
			get_tree().change_scene_to_packed(ROOM_SCENE)

func _update_camera() -> void:
	_camera.position = _player.position + Vector3(0, 8.5, 11.5)
	_camera.look_at(_player.position + Vector3(0, 0.7, -4), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_E and _player.position.z < -9.0:
		_transitioning = true
		var state := get_node_or_null("/root/RunState")
		if state != null:
			state.carried_health = _player.health
		get_tree().change_scene_to_packed(ROOM_SCENE)

func _build_hall() -> void:
	_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.018, 0.022)
	_environment.environment = env
	add_child(_environment)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 24)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.14, 0.13)
	floor.material_override = mat
	floor.position.z = -2
	add_child(floor)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8, 0.3, 24)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(0, -0.2, -2)
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 3.0, 24.0)
		wall.mesh = box
		wall.position = Vector3(side * 4.3, 1.5, -2)
		wall.material_override = mat
		add_child(wall)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = box.size
		shape.shape = collision
		body.position = wall.position
		body.add_child(shape)
		add_child(body)
	for z in [10.0, -14.0]:
		var arch := MeshInstance3D.new()
		var arch_mesh := BoxMesh.new()
		arch_mesh.size = Vector3(5.0, 0.6, 0.8)
		arch.mesh = arch_mesh
		arch.position = Vector3(0, 2.8, z)
		arch.material_override = mat
		add_child(arch)
	var label := Label3D.new()
	label.text = "走廊 · 向北前进"
	label.position = Vector3(0, 2.0, -7)
	label.font_size = 32
	add_child(label)
