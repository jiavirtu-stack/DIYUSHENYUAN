extends Node3D
class_name BossAttackController

@export var warning_seconds := 0.76
@export var spike_count := 4
@export var ring_projectile_count := 12
@export var debug_force_skill := -1 # 0 spikes, 1 fan, 2 ring, -1 normal cycle

var boss: RitualBriarBoss
var player: FairytalePlayer
var _skill_index := 0
var _position_history: Array[Vector3] = []
var _history_timer := 0.0
var _busy := false
var _last_result := ""
var last_ring_projectile_count := 0
var last_ring_gap_angle := 0.0
var last_ring_gap_half_angle := 0.0


func _ready() -> void:
	boss = get_parent().get_node_or_null("Boss") as RitualBriarBoss
	player = get_tree().get_first_node_in_group("player") as FairytalePlayer
	if boss != null:
		boss.attack_ready.connect(_on_boss_attack_ready)


func _physics_process(delta: float) -> void:
	_history_timer += delta
	if _history_timer >= 0.1:
		_history_timer = 0.0
		if is_instance_valid(player):
			_position_history.push_back(player.global_position)
			if _position_history.size() > 10:
				_position_history.pop_front()


func trigger_skill(index: int) -> void:
	if index < 0 or index > 2 or _busy:
		return
	if boss == null:
		boss = get_parent().get_node_or_null("Boss") as RitualBriarBoss
	if player == null:
		player = get_tree().get_first_node_in_group("player") as FairytalePlayer
	if boss != null and player != null:
		_run_skill(index, boss.phase, player.global_position)


func _on_boss_attack_ready(phase: int, target_position: Vector3) -> void:
	var selected := debug_force_skill if debug_force_skill >= 0 else _skill_index
	if debug_force_skill < 0:
		_skill_index = (_skill_index + 1) % 3
	if is_instance_valid(player):
		_run_skill(selected, phase, target_position)


func _run_skill(index: int, phase: int, target_position: Vector3) -> void:
	if _busy:
		return
	_busy = true
	boss.pending_skill = index
	match index:
		0: await _ground_spikes(target_position, phase)
		1: await _fan_blast(target_position, phase)
		2: await _ring_barrage(target_position, phase)
	_busy = false


func _ground_spikes(target_position: Vector3, phase: int) -> void:
	var old_position := _position_history[maxi(0, _position_history.size() - 7)] if not _position_history.is_empty() else target_position
	var line := old_position - boss.global_position
	line.y = 0.0
	if line.length_squared() < 0.01:
		line = Vector3(0,0,1)
	var direction := line.normalized()
	var positions: Array[Vector3] = []
	for i in range(spike_count):
		var point := boss.global_position + direction * (1.0 + i * 0.72)
		point.y = 0.06
		positions.append(point)
		_spawn_warning(point, 0.55, Color(0.79, 0.28, 0.12, 0.48))
	await get_tree().create_timer(warning_seconds, false, false, true).timeout
	for point in positions:
		_spawn_spike(point, phase)
		if is_instance_valid(player) and not player.is_invulnerable and player.global_position.distance_to(point) < 0.72:
			_damage_player(phase, direction)
	await get_tree().create_timer(0.5, false, false, true).timeout


func _fan_blast(target_position: Vector3, phase: int) -> void:
	var direction := target_position - boss.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01: direction = Vector3(0,0,1)
	direction = direction.normalized()
	_spawn_wedge(boss.global_position, direction, 3.8, deg_to_rad(39), Color(0.88,0.32,0.13,0.42))
	await get_tree().create_timer(warning_seconds, false, false, true).timeout
	if is_instance_valid(player) and not player.is_invulnerable:
		var to_player := player.global_position - boss.global_position
		to_player.y = 0.0
		if to_player.length() < 3.8 and direction.dot(to_player.normalized()) >= cos(deg_to_rad(39)):
			_damage_player(phase, direction)
	_spawn_wave_ring(boss.global_position, 2.1, Color(0.94,0.48,0.22,0.5))
	await get_tree().create_timer(0.45, false, false, true).timeout


func _ring_barrage(target_position: Vector3, phase: int) -> void:
	var gap_direction := target_position - boss.global_position
	gap_direction.y = 0.0
	if gap_direction.length_squared() < 0.01: gap_direction = Vector3(1,0,0)
	gap_direction = gap_direction.normalized()
	_spawn_wave_ring(boss.global_position, 3.2, Color(0.75,0.61,0.21,0.42))
	await get_tree().create_timer(warning_seconds, false, false, true).timeout
	var count := ring_projectile_count + (4 if phase == 2 else 0)
	var gap_angle := atan2(gap_direction.z, gap_direction.x)
	var safe_angle := deg_to_rad(31)
	last_ring_projectile_count = 0
	last_ring_gap_angle = gap_angle
	last_ring_gap_half_angle = safe_angle
	var directions: Array[Vector3] = []
	for i in range(count):
		var angle := TAU * i / count
		if absf(wrapf(angle - gap_angle, -PI, PI)) < safe_angle:
			continue
		var dir := Vector3(cos(angle),0,sin(angle))
		directions.append(dir)
		last_ring_projectile_count += 1
		_spawn_projectile(boss.global_position + Vector3.UP * 0.45, dir, phase)
	for tick in range(18):
		await get_tree().create_timer(0.035, false, false, true).timeout
		if not is_instance_valid(player) or player.is_invulnerable: continue
		for dir in directions:
			var projectile_point := boss.global_position + dir * ((tick + 1) * 0.13)
			if (player.global_position + Vector3.UP * 0.55).distance_to(projectile_point) < 0.42:
				_damage_player(phase, dir)
				break
	for child in get_children():
		if child.name == "BriarOrb": child.queue_free()


func _damage_player(phase: int, direction: Vector3) -> void:
	if not is_instance_valid(player): return
	var damage := 14.0 if phase == 1 else 18.0
	player.apply_hit(damage, direction * (3.2 if phase == 1 else 4.0))
	_last_result = "hit"


func _spawn_warning(at: Vector3, radius: float, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	marker.mesh = mesh
	marker.position = at
	marker.material_override = _fx_material(color)
	marker.name = "GroundTelegraph"
	add_child(marker)
	var tw := create_tween()
	tw.tween_property(marker, "scale", Vector3(1.12,1,1.12), warning_seconds)
	tw.tween_callback(marker.queue_free)


func _spawn_spike(at: Vector3, phase: int) -> void:
	var spike := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.28
	mesh.height = 1.0
	spike.mesh = mesh
	spike.material_override = _fx_material(Color(0.42,0.31,0.21))
	spike.position = at - Vector3.UP * 0.5
	add_child(spike)
	var tw := create_tween()
	tw.tween_property(spike, "position:y", 0.52 if phase == 1 else 0.8, 0.12)
	tw.tween_interval(0.35)
	tw.tween_property(spike, "scale", Vector3(0.1,0.1,0.1), 0.18)
	tw.tween_callback(spike.queue_free)


func _spawn_wedge(origin: Vector3, direction: Vector3, reach: float, half_angle: float, color: Color) -> void:
	var points := [origin]
	var start := atan2(direction.x, direction.z) - half_angle
	for i in range(25):
		var a := start + 2.0 * half_angle * i / 24.0
		points.append(origin + Vector3(sin(a)*reach,0.035,cos(a)*reach))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			st.set_normal(Vector3.UP); st.add_vertex(p)
	var node := MeshInstance3D.new(); node.mesh = st.commit(); node.material_override = _fx_material(color); node.name="FanTelegraph"; add_child(node)
	var tw := create_tween(); tw.tween_interval(warning_seconds); tw.tween_callback(node.queue_free)


func _spawn_wave_ring(origin: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = radius - 0.08; mesh.outer_radius = radius
	ring.mesh = mesh; ring.position = origin + Vector3.UP * 0.055; ring.material_override = _fx_material(color); ring.name="RingTelegraph"; add_child(ring)
	var tw := create_tween(); tw.tween_property(ring,"scale",Vector3(1.2,1,1.2),warning_seconds); tw.tween_callback(ring.queue_free)


func _spawn_projectile(at: Vector3, direction: Vector3, phase: int) -> void:
	var orb := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius=0.16 if phase==1 else 0.19; mesh.height=mesh.radius*2
	orb.mesh=mesh; orb.position=at; orb.material_override=_fx_material(Color(0.77,0.6,0.2)); orb.name="BriarOrb"; add_child(orb)
	var tw=create_tween(); tw.tween_property(orb,"position",at+direction*2.5,0.65); tw.tween_callback(orb.queue_free)


func _fx_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color=color; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode=BaseMaterial3D.CULL_DISABLED
	if color.r > 0.7: material.emission_enabled=true; material.emission=Color(color.r*0.7,color.g*0.45,color.b*0.18); material.emission_energy_multiplier=0.75
	return material
