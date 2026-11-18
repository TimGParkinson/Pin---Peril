extends TestCase
## Collision shapes are built exactly from the level geometry (pure shape math, no stepping).


func _wall(kind: String, points: Array, thickness: float = 24.0) -> LevelDefinition.Wall:
	var wall: LevelDefinition.Wall = LevelDefinition.Wall.new()
	wall.id = "wall.t"
	wall.kind = kind
	wall.thickness = thickness
	wall.points = PackedVector2Array(points)
	return wall


func _ends_of(collider: BoardColliders.Collider) -> Array[Vector2]:
	var capsule: CapsuleShape2D = collider.shape as CapsuleShape2D
	var half_axis: float = capsule.height * 0.5 - capsule.radius
	return [collider.transform * Vector2(0.0, -half_axis), collider.transform * Vector2(0.0, half_axis)]


func test_polyline_is_one_capsule_per_segment_ending_exactly_on_its_points() -> void:
	var points: Array = [Vector2(100.0, 100.0), Vector2(300.0, 140.0), Vector2(320.0, 400.0), Vector2(90.0, 380.0)]
	var wall: LevelDefinition.Wall = _wall(LevelSchema.WALL_KIND_POLYLINE, points, 20.0)
	var colliders: Array[BoardColliders.Collider] = BoardColliders.for_wall(wall)
	assert_eq(colliders.size(), 3, "one capsule per segment")
	for index: int in colliders.size():
		var capsule: CapsuleShape2D = colliders[index].shape as CapsuleShape2D
		assert_not_null(capsule)
		assert_almost_eq(capsule.radius, 10.0, 0.0001, "radius is half the thickness")
		var start: Vector2 = points[index] as Vector2
		var end: Vector2 = points[index + 1] as Vector2
		assert_almost_eq(capsule.height, start.distance_to(end) + 20.0, 0.001, "height includes both round ends")
		var ends: Array[Vector2] = _ends_of(colliders[index])
		var forward: bool = ends[0].distance_to(start) < 0.01 and ends[1].distance_to(end) < 0.01
		var backward: bool = ends[1].distance_to(start) < 0.01 and ends[0].distance_to(end) < 0.01
		assert_true(forward or backward, "capsule %d axis runs exactly from %s to %s, got %s" % [index, start, end, ends])


func test_capsules_cover_exactly_the_thick_line_and_no_more() -> void:
	# A capsule contains a point iff the point is within `radius` of its axis segment. Check the
	# transform actually places that region around the segment (catches a wrong rotation).
	var wall: LevelDefinition.Wall = _wall(LevelSchema.WALL_KIND_POLYLINE, [Vector2(200.0, 200.0), Vector2(500.0, 320.0)], 30.0)
	var collider: BoardColliders.Collider = BoardColliders.for_wall(wall)[0]
	var capsule: CapsuleShape2D = collider.shape as CapsuleShape2D
	var inverse: Transform2D = collider.transform.affine_inverse()
	var inside_hits: int = 0
	var outside_hits: int = 0
	for step_x: int in range(150, 560, 7):
		for step_y: int in range(150, 380, 7):
			var point: Vector2 = Vector2(float(step_x), float(step_y))
			var distance: float = LevelGeometry.distance_point_segment(point, wall.points[0], wall.points[1])
			if absf(distance - 15.0) < 0.5:
				continue  # too close to the edge to judge
			var local: Vector2 = inverse * point
			var half_axis: float = capsule.height * 0.5 - capsule.radius
			var in_capsule: bool = LevelGeometry.distance_point_segment(local, Vector2(0.0, -half_axis), Vector2(0.0, half_axis)) <= capsule.radius
			assert_eq(in_capsule, distance <= 15.0, "point %s" % point)
			if in_capsule:
				inside_hits += 1
			else:
				outside_hits += 1
	assert_true(inside_hits > 100 and outside_hits > 100, "sampled both inside (%d) and outside (%d)" % [inside_hits, outside_hits])


func test_convex_polygon_stays_one_piece_and_concave_splits_with_exact_total_area() -> void:
	var square: LevelDefinition.Wall = _wall(LevelSchema.WALL_KIND_POLYGON, [Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(100.0, 80.0), Vector2(0.0, 80.0)])
	assert_eq(BoardColliders.for_wall(square).size(), 1)
	# An L shape and a U shape, each in both windings (clockwise and counter-clockwise).
	var shapes: Array = [
		[Vector2(0.0, 0.0), Vector2(200.0, 0.0), Vector2(200.0, 50.0), Vector2(50.0, 50.0), Vector2(50.0, 200.0), Vector2(0.0, 200.0)],
		[Vector2(0.0, 0.0), Vector2(60.0, 0.0), Vector2(60.0, 140.0), Vector2(140.0, 140.0), Vector2(140.0, 0.0), Vector2(200.0, 0.0), Vector2(200.0, 200.0), Vector2(0.0, 200.0)],
	]
	for points: Array in shapes:
		for reversed: bool in [false, true]:
			var ordered: Array = points.duplicate()
			if reversed:
				ordered.reverse()
			var wall: LevelDefinition.Wall = _wall(LevelSchema.WALL_KIND_POLYGON, ordered)
			var colliders: Array[BoardColliders.Collider] = BoardColliders.for_wall(wall)
			assert_true(colliders.size() >= 2, "a concave polygon needs several convex pieces")
			var total: float = 0.0
			for collider: BoardColliders.Collider in colliders:
				var piece: ConvexPolygonShape2D = collider.shape as ConvexPolygonShape2D
				assert_not_null(piece)
				total += LevelGeometry.polygon_area(piece.points)
			assert_almost_eq(total, LevelGeometry.polygon_area(wall.points), 0.5, "pieces cover exactly the polygon (reversed=%s)" % str(reversed))


func test_pin_is_a_shaft_rectangle_from_tip_to_handle_plus_a_knob() -> void:
	var pin: LevelDefinition.Pin = LevelDefinition.Pin.new()
	pin.id = "pin.t"
	pin.tip = Vector2(700.0, 300.0)
	pin.handle = Vector2(100.0, 420.0)
	pin.thickness = 16.0
	var colliders: Array[BoardColliders.Collider] = BoardColliders.for_pin(pin)
	assert_eq(colliders.size(), 2)
	var shaft: RectangleShape2D = colliders[0].shape as RectangleShape2D
	assert_not_null(shaft)
	assert_almost_eq(shaft.size.x, pin.tip.distance_to(pin.handle), 0.001)
	assert_almost_eq(shaft.size.y, 16.0, 0.0001)
	assert_true((colliders[0].transform * Vector2(-shaft.size.x * 0.5, 0.0)).distance_to(pin.tip) < 0.01, "one end of the shaft is the tip")
	assert_true((colliders[0].transform * Vector2(shaft.size.x * 0.5, 0.0)).distance_to(pin.handle) < 0.01, "the other end is the handle")
	var knob: CircleShape2D = colliders[1].shape as CircleShape2D
	assert_not_null(knob)
	assert_almost_eq(knob.radius, 16.0 * SimConfig.PIN_KNOB_RADIUS_FACTOR, 0.0001)
	assert_eq(colliders[1].transform.origin, pin.handle)


func test_every_wall_and_pin_of_the_built_in_levels_gets_shapes() -> void:
	var checked: int = 0
	for level_id: String in LevelLibrary.list_builtin_ids():
		var definition: LevelDefinition = LevelLibrary.load_builtin(level_id).definition
		assert_not_null(definition, level_id)
		for wall: LevelDefinition.Wall in definition.walls:
			assert_false(BoardColliders.for_wall(wall).is_empty(), "%s %s" % [level_id, wall.id])
			checked += 1
		for pin: LevelDefinition.Pin in definition.pins:
			assert_eq(BoardColliders.for_pin(pin).size(), 2)
			checked += 1
	assert_true(checked >= 10, "checked %d parts" % checked)
