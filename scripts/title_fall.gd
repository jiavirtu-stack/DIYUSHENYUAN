extends Control

@export var far_speed := 0.010
@export var wall_speed := 0.027
@export var drift_amount := 7.0

var elapsed := 0.0
var far_material: ShaderMaterial
var wall_material: ShaderMaterial
var hero: TextureRect
var logo: TextureRect
var fragments: Array[Dictionary] = []
var _hero_home := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	far_material = _layer(0.0)
	wall_material = _layer(1.0)
	var source := load("res://assets/menu/title_clean.png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(source.get_width() * 0.26, source.get_height() * 0.147, source.get_width() * 0.50, source.get_height() * 0.23)
	logo = TextureRect.new()
	logo.texture = atlas
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(499, 159)
	logo.size = Vector2(960, 249)
	var key := ShaderMaterial.new()
	key.shader = load("res://shaders/title_logo.gdshader")
	logo.material = key
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = 2
	add_child(logo)
	hero = TextureRect.new()
	hero.texture = load("res://assets/menu/falling_hero.png")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size = Vector2(425, 425)
	_hero_home = Vector2(712, 442)
	hero.position = _hero_home
	hero.pivot_offset = hero.size * 0.5
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.z_index = 1
	add_child(hero)
	var random := RandomNumberGenerator.new()
	random.seed = 7341
	for i in range(36):
		fragments.append({"at":Vector2(random.randf_range(50, 1870), random.randf_range(0, 1080)), "speed":random.randf_range(32, 105), "phase":random.randf_range(0, TAU), "size":random.randf_range(3, 12), "red":i % 8 == 0})

func _layer(depth: float) -> ShaderMaterial:
	var rect := TextureRect.new()
	rect.texture = load("res://assets/menu/abyss_loop.png")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = -2 if depth < 0.5 else -1
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/title_scroll.gdshader")
	material.set_shader_parameter("depth", depth)
	rect.material = material
	add_child(rect)
	return material

func _process(delta: float) -> void:
	elapsed += delta
	far_material.set_shader_parameter("travel", fposmod(elapsed * far_speed, 1.0))
	wall_material.set_shader_parameter("travel", fposmod(elapsed * wall_speed, 1.0))
	hero.position = _hero_home + Vector2(sin(elapsed * 0.37) * drift_amount, sin(elapsed * 0.56) * drift_amount * 0.7)
	hero.rotation = sin(elapsed * 0.41) * 0.028
	for fragment in fragments:
		fragment.at.y -= fragment.speed * delta
		if fragment.at.y < -30:
			fragment.at.y += 1140
	queue_redraw()

func _draw() -> void:
	for fragment in fragments:
		var at: Vector2 = fragment.at
		# Keep fast foreground fragments away from the fixed logo and menu.
		if Rect2(450, 130, 1040, 290).has_point(at) or Rect2(60, 710, 430, 275).has_point(at):
			continue
		var color := Color(0.35, 0.13, 0.23, 0.45) if fragment.red else Color(0.25, 0.42, 0.60, 0.38)
		var s: float = fragment.size
		var skew := sin(fragment.phase + elapsed * 0.35) * s * 0.4
		draw_colored_polygon(PackedVector2Array([at + Vector2(-s, skew), at + Vector2(0, -s * 0.5), at + Vector2(s, -skew), at + Vector2(0, s * 0.5)]), color)
