extends CharacterBody3D
class_name CorruptedVillager

signal defeated(enemy: CorruptedVillager)

@export var max_health := 38.0
@export var move_speed := 2.65
@export var attack_range := 1.45
@export var attack_damage := 8.0

var health := 38.0
var _target: FairytalePlayer
var _dead := false
var _windup_timer := 0.0
var _attack_cooldown := 0.8
var _attack_direction := Vector3.FORWARD
var _knockback_velocity := Vector3.ZERO
var _elapsed := 0.0
var _visual_root: Node3D
var _body_material: StandardMaterial3D
var _telegraph: MeshInstance3D


func _ready() -> void:
	add_to_group("minions")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	health = max_health
	_attack_cooldown = randf_range(0.25, 1.0)
	_build_collision()
	_build_visual()
	_target = get_tree().get_first_node_in_group("player") as FairytalePlayer


func _physics_process(delta: float) -> void:
	if _dead or get_tree().paused:
		return
	_elapsed += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 13.0 * delta)
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as FairytalePlayer
		return
	var offset := _target.global_position - global_position
	var direction := Vector3(offset.x, 0.0, offset.z)
	var distance := direction.length()
	if distance > 0.01:
		direction /= distance
		_visual_root.rotation.y = atan2(direction.x, direction.z)
	_visual_root.position.y = 0.03 + sin(_elapsed * 8.0) * 0.025
	if _windup_timer > 0.0:
		_windup_timer -= delta
		velocity = _knockback_velocity
		if _windup_timer <= 0.0:
			_perform_attack()
	elif distance <= attack_range and _attack_cooldown <= 0.0:
		_attack_direction = direction
		_windup_timer = 0.58
		_attack_cooldown = 1.65
		_telegraph.visible = true
	else:
		var move_direction := direction if distance > attack_range * 0.82 else Vector3.ZERO
		velocity = move_direction * move_speed + _knockback_velocity
	move_and_slide()


func receive_hit(damage: float, knockback: Vector3, _hit_position: Vector3) -> void:
	if _dead:
		return
	health = maxf(0.0, health - damage)
	_knockback_velocity += Vector3(knockback.x, 0.0, knockback.z) * 0.16
	_body_material.albedo_color = Color(0.82, 0.32, 0.22)
	var flash := create_tween()
	flash.tween_property(_body_material, "albedo_color", Color(0.20, 0.31, 0.23), 0.16)
	if health <= 0.0:
		_die()


func _perform_attack() -> void:
	_telegraph.visible = false
	if not is_instance_valid(_target):
		return
	var to_player := _target.global_position - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	if flat_to_player.length() <= attack_range + 0.35:
		_target.apply_hit(attack_damage, _attack_direction * 2.0)


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	_telegraph.visible = false
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self)
	var death_tween := create_tween()
	death_tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.20)
	death_tween.parallel().tween_property(self, "position:y", position.y + 0.18, 0.20)
	death_tween.tween_callback(queue_free)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.45
	collision.shape = capsule
	collision.position.y = 0.72
	add_child(collision)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_body_material = _material(Color(0.20, 0.31, 0.23), 0.95)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.40
	body_mesh.height = 1.05
	body.mesh = body_mesh
	body.material_override = _body_material
	body.position.y = 0.80
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_visual_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.30
	head_mesh.height = 0.56
	head.mesh = head_mesh
	head.material_override = _material(Color(0.45, 0.52, 0.38), 0.9)
	head.position = Vector3(0.0, 1.48, 0.02)
	_visual_root.add_child(head)
	_add_box("TornMantle", Vector3(0.76, 0.46, 0.34), Vector3(0.0, 0.78, 0.30), _material(Color(0.16, 0.20, 0.16), 1.0))
	_add_box("LeftArm", Vector3(0.20, 0.66, 0.22), Vector3(-0.43, 0.77, 0.08), _material(Color(0.29, 0.34, 0.25), 0.95))
	_add_box("RightArm", Vector3(0.20, 0.66, 0.22), Vector3(0.43, 0.77, 0.08), _material(Color(0.29, 0.34, 0.25), 0.95))
	var eye_material := _material(Color(1.0, 0.20, 0.035), 0.5)
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.09, 0.015)
	eye_material.emission_energy_multiplier = 1.7
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye_mesh.height = 0.09
		eye.mesh = eye_mesh
		eye.material_override = eye_material
		eye.position = Vector3(side * 0.11, 1.50, 0.275)
		_visual_root.add_child(eye)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.44
	shadow_mesh.bottom_radius = 0.50
	shadow_mesh.height = 0.025
	shadow.mesh = shadow_mesh
	var shadow_material := _material(Color(0.025, 0.018, 0.016, 0.56), 1.0)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_material
	shadow.position.y = 0.025
	_visual_root.add_child(shadow)
	_telegraph = MeshInstance3D.new()
	_telegraph.name = "AttackTelegraph"
	var warning_mesh := CylinderMesh.new()
	warning_mesh.top_radius = 1.25
	warning_mesh.bottom_radius = 1.25
	warning_mesh.height = 0.025
	_telegraph.mesh = warning_mesh
	var warning_material := _material(Color(0.90, 0.20, 0.045, 0.44), 0.8)
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.emission_enabled = true
	warning_material.emission = Color(0.78, 0.08, 0.01)
	_telegraph.material_override = warning_material
	_telegraph.position.y = 0.045
	_telegraph.visible = false
	_visual_root.add_child(_telegraph)


func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	item.position = at
	_visual_root.add_child(item)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
