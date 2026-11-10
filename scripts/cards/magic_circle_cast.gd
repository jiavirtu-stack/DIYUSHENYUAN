extends Node3D
## Pure presentation: no hitboxes, damage, target selection or cooldown handling.
var tint := Color(0.65, 0.35, 1)
var age := 0.0
var duration := 0.68
var material: ShaderMaterial
func _ready() -> void:
	name = "MagicCircleCast"
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.8, 2.8)
	surface.mesh = plane
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/magic_circle_cast.gdshader")
	material.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 0.9))
	surface.material_override = material
	add_child(surface)
func _physics_process(delta: float) -> void:
	age += delta
	material.set_shader_parameter("age", age)
	if age >= duration: queue_free()
