extends StaticBody3D

signal torn(body: Node)

var durability := 24.0
var travel := Vector3.ZERO
var lifetime := 0.0
var extent := Vector3(3.0, 2.0, 0.5)
var moving := false

func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = extent
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.72, 0.61)
	material.roughness = 1.0
	mesh.material_override = material
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not moving:
		return
	position += travel * delta
	lifetime += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var offset := player.global_position - global_position
		if absf(offset.x) < extent.x * 0.5 + 0.55 and absf(offset.z) < extent.z * 0.5 + 0.55:
			player.call("apply_hit", 10.0, travel.normalized() * 2.0)
	if lifetime > 6.0:
		queue_free()

func receive_hit(damage: float, _knockback: Vector3, _at: Vector3) -> void:
	if durability <= 0.0:
		return
	durability -= damage
	if durability <= 0.0:
		collision_layer = 0
		torn.emit(self)
		queue_free()
