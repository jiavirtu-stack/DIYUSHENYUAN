extends Node3D
var direction := Vector3.FORWARD
var damage := 3.0
var age := 0.0
func _ready() -> void:
	add_to_group("deflectable_projectile")
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.13
	ball.height = 0.26
	mesh.mesh = ball
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.5, 0.1)
	mesh.material_override = material
	add_child(mesh)
func _physics_process(delta: float) -> void:
	age += delta
	var next := position + direction * delta * 7.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var ignored: Array[RID] = []
	if player is CollisionObject3D: ignored.append(player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(position, next, 1, ignored)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	position = next
	if player != null and position.distance_to(player.position + Vector3.UP * 0.65) < 0.55:
		player.apply_hit(damage)
		queue_free()
	if age > 4: queue_free()
