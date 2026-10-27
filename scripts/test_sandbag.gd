extends StaticBody3D
class_name TestSandbag

signal health_changed(current: float, maximum: float)

@export var max_health := 300.0
var health := 300.0
var last_knockback := Vector3.ZERO
var hit_count := 0


func _ready() -> void:
	health = max_health


func receive_hit(damage: float, knockback: Vector3, _hit_position: Vector3) -> void:
	health = maxf(0.0, health - damage)
	last_knockback = knockback
	hit_count += 1
	var visual := get_node_or_null("TrainingLog") as MeshInstance3D
	if visual != null:
		var mat := visual.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.72, 0.25, 0.12)
			var tween := create_tween()
			tween.tween_property(mat, "albedo_color", Color(0.28, 0.12, 0.065), 0.18)
	health_changed.emit(health, max_health)
