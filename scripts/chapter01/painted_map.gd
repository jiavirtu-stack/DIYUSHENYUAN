extends Node3D

const WIDTH := 48.0
const DEPTH := 39.064
const SOURCE_SIZE := Vector2(1536, 1024)
const MAP_FILES := ["office_clean.png", "street_clean.png", "apartment_clean.png"]
var material: ShaderMaterial
var stage := 0
var _blocks: Array[Rect2] = []
var navigation := AStarGrid2D.new()

func build(value: int) -> void:
	stage = value
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH, DEPTH)
	floor.mesh = plane
	floor.position.y = -0.035
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/chapter_map.gdshader")
	material.set_shader_parameter("artwork", load("res://assets/chapter01/" + MAP_FILES[stage]))
	floor.material_override = material
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)
	if stage == 0:
		_office_collision()
	elif stage == 1:
		_street_collision()
	else:
		_apartment_collision()
	_build_navigation()

func to_world(pixel: Vector2) -> Vector3:
	return Vector3((pixel.x / SOURCE_SIZE.x - 0.5) * WIDTH, 0, (pixel.y / SOURCE_SIZE.y - 0.5) * DEPTH)

func to_pixel(point: Vector3) -> Vector2:
	return Vector2((point.x / WIDTH + 0.5) * SOURCE_SIZE.x, (point.z / DEPTH + 0.5) * SOURCE_SIZE.y)

func _block(rect: Rect2, name_hint: String) -> void:
	_blocks.append(rect)
	var body := StaticBody3D.new()
	body.name = name_hint
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x / SOURCE_SIZE.x * WIDTH, 1.8, rect.size.y / SOURCE_SIZE.y * DEPTH)
	shape.shape = box
	body.position = to_world(rect.get_center()) + Vector3.UP * 0.9
	body.add_child(shape)
	add_child(body)

func _build_navigation() -> void:
	navigation.region = Rect2i(0, 0, 48, 32)
	navigation.cell_size = Vector2(32, 32)
	navigation.offset = Vector2(16, 16)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(32):
		for x in range(48):
			var pixel := Vector2(16 + x * 32, 16 + y * 32)
			var blocked := not is_walkable(to_world(pixel))
			for rect in _blocks:
				if rect.grow(10).has_point(pixel):
					blocked = true
					break
			navigation.set_point_solid(Vector2i(x, y), blocked)

func _nearest_cell(pixel: Vector2) -> Vector2i:
	var initial := Vector2i(clampi(floori(pixel.x / 32), 0, 47), clampi(floori(pixel.y / 32), 0, 31))
	for radius in range(5):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := initial + Vector2i(x, y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate):
					return candidate
	return initial

func path_direction(from: Vector3, target: Vector3) -> Vector3:
	var ids := navigation.get_id_path(_nearest_cell(to_pixel(from)), _nearest_cell(to_pixel(target)), true)
	if ids.size() < 2:
		return (target - from).normalized()
	var next: Vector2 = navigation.get_point_position(ids[1])
	return (to_world(next) - from).normalized()

func _office_collision() -> void:
	# Coordinates refer to the supplied 1536 x 1024 artwork; low footprints
	# leave the floor immediately behind tall props reachable.
	for rect in [Rect2(238, 310, 112, 112), Rect2(365, 310, 115, 112), Rect2(238, 530, 112, 102), Rect2(365, 530, 115, 102), Rect2(943, 305, 132, 127), Rect2(943, 535, 132, 104), Rect2(675, 410, 178, 107)]:
		_block(rect, "Desk")
	for rect in [Rect2(145, 125, 182, 90), Rect2(888, 190, 159, 56), Rect2(93, 401, 55, 84), Rect2(1037, 700, 162, 68), Rect2(1208, 650, 160, 129)]:
		_block(rect, "Cabinet")
	_block(Rect2(1190, 231, 174, 155), "MeetingTableAndChairs")
	_block(Rect2(1105, 115, 20, 359), "MeetingWestWall")
	_block(Rect2(1110, 470, 124, 16), "MeetingSouthWallLeft")
	_block(Rect2(1312, 470, 100, 16), "MeetingSouthWallRight")
	_block(Rect2(150, 660, 452, 24), "ArchiveNorthWall")
	_block(Rect2(580, 680, 22, 55), "ArchiveEastWallTop")
	_block(Rect2(580, 810, 22, 55), "ArchiveEastWallBottom")
	_block(Rect2(111, 678, 213, 87), "ArchiveShelves")
	_block(Rect2(344, 752, 172, 63), "ArchiveDesk")
	_block(Rect2(818, 673, 19, 202), "StoreWestWall")
	# Outer walls leave only the bottom central corridor open.
	_block(Rect2(100, 207, 38, 660), "WestWall")
	_block(Rect2(1408, 120, 35, 747), "EastWall")
	_block(Rect2(140, 178, 967, 35), "NorthFurnitureRow")
	_block(Rect2(140, 867, 510, 32), "SouthWallLeft")
	_block(Rect2(832, 867, 579, 32), "SouthWallRight")

func _street_collision() -> void:
	for rect in [Rect2(100, 45, 596, 387), Rect2(837, 36, 600, 236), Rect2(841, 275, 66, 149), Rect2(1100, 383, 336, 56), Rect2(100, 745, 591, 179), Rect2(838, 742, 595, 180), Rect2(1080, 520, 237, 123), Rect2(282, 665, 85, 91), Rect2(913, 355, 58, 94)]:
		_block(rect, "BuildingOrStreetProp")

func _apartment_collision() -> void:
	for rect in [Rect2(139, 273, 123, 295), Rect2(267, 319, 65, 69), Rect2(635, 169, 155, 97), Rect2(861, 159, 179, 94), Rect2(1135, 230, 280, 59), Rect2(1250, 485, 171, 111), Rect2(1209, 744, 172, 66)]:
		_block(rect, "ApartmentFurniture")
	_block(Rect2(80, 225, 41, 598), "WestWall")
	_block(Rect2(1427, 140, 32, 682), "EastWall")
	_block(Rect2(134, 803, 525, 32), "SouthWallLeft")
	_block(Rect2(882, 803, 555, 32), "SouthWallRight")
	_block(Rect2(330, 80, 785, 64), "NorthWall")

func is_walkable(point: Vector3) -> bool:
	var pixel := to_pixel(point)
	if stage == 0:
		return Rect2(140, 215, 1260, 650).has_point(pixel) or Rect2(660, 820, 158, 174).has_point(pixel)
	if stage == 1:
		return Rect2(693, 28, 143, 972).has_point(pixel) or Rect2(90, 438, 1345, 308).has_point(pixel) or Rect2(903, 272, 523, 111).has_point(pixel) or Rect2(905, 360, 190, 100).has_point(pixel)
	return Rect2(122, 255, 1305, 548).has_point(pixel) or Rect2(660, 801, 219, 99).has_point(pixel)

func clamp_player(point: Vector3, previous: Vector3) -> Vector3:
	if is_walkable(point):
		return point
	var x_only := Vector3(point.x, point.y, previous.z)
	if is_walkable(x_only):
		return x_only
	var z_only := Vector3(previous.x, point.y, point.z)
	if is_walkable(z_only):
		return z_only
	return previous
