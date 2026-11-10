extends Node3D
## Presentation only: contains no collision queries, damage or cooldown state.
var age := 0.0
var duration := 0.36
var charging := false
var looping := false
var material: ShaderMaterial
var surface: MeshInstance3D
static var atlas_texture: Texture2D

func _ready() -> void:
	if atlas_texture == null:
		atlas_texture = load("res://assets/fx/thunder_user_sheet.png")
	surface = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	surface.mesh = plane
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/thunder_sheet.gdshader")
	material.set_shader_parameter("atlas", atlas_texture)
	surface.material_override = material
	add_child(surface)
	_update_frame()

func span(from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	direction.y = 0
	if direction.length_squared() < 0.001: direction = Vector3.FORWARD * 0.05
	position = (from + to) * 0.5
	var z := -direction.normalized()
	basis = Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z)
	surface.scale = Vector3(width, 1, maxf(0.05, direction.length()))

func _physics_process(delta: float) -> void:
	age += delta
	if looping: age = fmod(age, duration)
	_update_frame()
	if not charging and not looping and age >= duration: queue_free()

func _update_frame() -> void:
	if material == null: return
	if charging:
		material.set_shader_parameter("frame_index", minf(24.0, 2.0 + floor(age * 28.0)))
		material.set_shader_parameter("opacity", 0.75)
	else:
		var progress := clampf(age / duration, 0, 1)
		var frame := lerpf(46, 71, progress / 0.7) if progress < 0.7 else lerpf(72, 95, (progress - 0.7) / 0.3)
		material.set_shader_parameter("frame_index", frame)
		material.set_shader_parameter("opacity", 1.0 - smoothstep(0.65, 1.0, progress))
