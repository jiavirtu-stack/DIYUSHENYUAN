extends Control

var particles: Array[Dictionary] = []
var elapsed := 0.0
var selected := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 4682
	for i in range(48):
		particles.append({"at":Vector2(random.randf(), random.randf()), "speed":random.randf_range(0.006, 0.020), "phase":random.randf_range(0, TAU), "size":random.randf_range(1, 3), "red":i % 7 == 0})

func _process(delta: float) -> void:
	elapsed += delta
	for particle in particles:
		particle.at.y -= particle.speed * delta
		particle.at.x += sin(elapsed * 0.25 + particle.phase) * delta * 0.002
		if particle.at.y < -0.02:
			particle.at.y = 1.02
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		var alpha := (0.12 + 0.12 * sin(elapsed * 0.55 + particle.phase)) * (0.55 if particle.red else 1.0)
		var color := Color(0.65, 0.22, 0.31, alpha) if particle.red else Color(0.47, 0.76, 0.95, alpha)
		draw_rect(Rect2(particle.at * size, Vector2.ONE * particle.size), color)
	# Sparse local specks form the selected entry's pixel halo.
	var menu_y := 773.0 + selected * 75.0
	for i in range(42):
		var phase := i * 2.399
		var at := Vector2(255 + cos(phase) * (70 + i % 13 * 5), menu_y + sin(phase) * (15 + i % 7 * 3))
		at.x += sin(elapsed * 0.7 + i) * 3.0
		draw_rect(Rect2(at, Vector2(2 + i % 3, 1 + i % 2)), Color(0.64, 0.76, 0.9, 0.12 + 0.06 * sin(elapsed + i)))
