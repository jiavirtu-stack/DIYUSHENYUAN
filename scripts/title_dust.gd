extends Control

var particles: Array[Dictionary] = []
var elapsed := 0.0
var selected := 0
var halo_y := 773.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 4682
	for i in range(48):
		particles.append({"at":Vector2(random.randf(), random.randf()), "speed":random.randf_range(0.006, 0.020), "phase":random.randf_range(0, TAU), "size":random.randf_range(1, 3), "red":i % 7 == 0})

func _process(delta: float) -> void:
	elapsed += delta
	halo_y = lerpf(halo_y, 773.0 + selected * 75.0, 1.0 - exp(-16.0 * delta))
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
	for i in range(220):
		var phase := i * 2.399
		var cycle := fposmod(elapsed * (0.17 + (i % 5) * 0.025) + i * 0.137, 1.0)
		var envelope := sin(cycle * PI)
		var spread := 0.65 + cycle * 0.65
		var at := Vector2(255 + cos(phase) * (84 + i % 17 * 3) * spread, halo_y + sin(phase) * (24 + i % 9 * 3) * spread)
		at += Vector2(sin(elapsed + phase) * 4.0, -cycle * 12.0)
		at = at.snapped(Vector2(2, 2))
		var edge := float(i % 7) / 7.0
		var color := Color(0.38 + edge * 0.4, 0.44 + edge * 0.37, 0.52 + edge * 0.34, envelope * (0.12 if i < 110 else 0.65))
		var pixel_size := Vector2(2 + i % 5, 2 + (i * 3) % 5)
		draw_rect(Rect2(at, pixel_size), color)
