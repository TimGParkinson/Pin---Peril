extends PhysicsTestCase
## Collision geometry visibly matches the playable boundaries: for a dense grid of points, the
## physics engine's own point query agrees with what the level data (and so the drawing) says is
## solid. Points within a hair of an edge are skipped because the answer there is a rounding
## matter, not a geometry one.

const GRID_STEP: float = 6.0
const EDGE_BAND: float = 0.75


## Distance from `point` to the nearest boundary of anything solid (walls and pins).
func _edge_distance(def: LevelDefinition, point: Vector2) -> float:
	var best: float = INF
	for wall: LevelDefinition.Wall in def.walls:
		if wall.kind == LevelSchema.WALL_KIND_POLYGON:
			best = minf(best, LevelGeometry.distance_to_outline(point, wall.points, true))
		else:
			best = minf(best, absf(LevelGeometry.distance_to_outline(point, wall.points, false) - wall.thickness * 0.5))
	for pin: LevelDefinition.Pin in def.pins:
		var knob: float = pin.thickness * SimConfig.PIN_KNOB_RADIUS_FACTOR
		best = minf(best, absf(point.distance_to(pin.handle) - knob))
		best = minf(best, _distance_to_rectangle_outline(pin, point))
	return best


func _distance_to_rectangle_outline(pin: LevelDefinition.Pin, point: Vector2) -> float:
	var axis: Vector2 = (pin.handle - pin.tip).normalized()
	var side: Vector2 = axis.orthogonal() * pin.thickness * 0.5
	var corners: PackedVector2Array = PackedVector2Array([pin.tip + side, pin.handle + side, pin.handle - side, pin.tip - side])
	return LevelGeometry.distance_to_outline(point, corners, true)


## True if the drawing shows `point` as inside a wall, pin shaft or pin knob.
func _drawn_solid(def: LevelDefinition, point: Vector2) -> bool:
	for wall: LevelDefinition.Wall in def.walls:
		if wall.kind == LevelSchema.WALL_KIND_POLYGON:
			if Geometry2D.is_point_in_polygon(point, wall.points):
				return true
		elif LevelGeometry.distance_to_outline(point, wall.points, false) <= wall.thickness * 0.5:
			return true
	for pin: LevelDefinition.Pin in def.pins:
		if point.distance_to(pin.handle) <= pin.thickness * SimConfig.PIN_KNOB_RADIUS_FACTOR:
			return true
		var axis: Vector2 = (pin.handle - pin.tip).normalized()
		var along: float = (point - pin.tip).dot(axis)
		var across: float = absf((point - pin.tip).dot(axis.orthogonal()))
		if along >= 0.0 and along <= pin.tip.distance_to(pin.handle) and across <= pin.thickness * 0.5:
			return true
	return false


func _engine_solid(point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = SimConfig.LAYER_WALL | SimConfig.LAYER_PIN
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var space: PhysicsDirectSpaceState2D = tree.root.get_world_2d().direct_space_state
	return not space.intersect_point(query, 1).is_empty()


func _compare(definition: LevelDefinition, label: String) -> void:
	var world: SimWorld = make_world(definition)
	await step(2)  # let the physics server register the new shapes
	var agreed_solid: int = 0
	var agreed_empty: int = 0
	var skipped: int = 0
	var size: Vector2 = definition.design_size
	var y: float = 0.0
	while y <= size.y:
		var x: float = 0.0
		while x <= size.x:
			var point: Vector2 = Vector2(x, y)
			if _edge_distance(definition, point) < EDGE_BAND:
				skipped += 1
			else:
				var drawn: bool = _drawn_solid(definition, point)
				if _engine_solid(point) != drawn:
					fail("%s: at %s the drawing says solid=%s but the physics engine says the opposite" % [label, point, str(drawn)])
					return
				if drawn:
					agreed_solid += 1
				else:
					agreed_empty += 1
			x += GRID_STEP
		y += GRID_STEP
	# Both outcomes must have been sampled, or "no disagreement" would prove nothing.
	assert_true(agreed_solid > 300, "%s: %d solid points checked" % [label, agreed_solid])
	assert_true(agreed_empty > 1000, "%s: %d empty points checked" % [label, agreed_empty])
	assert_true(skipped < (agreed_solid + agreed_empty) / 10, "%s: only a thin band was skipped (%d)" % [label, skipped])
	await discard_world(world)


func test_physics_matches_the_drawing_on_the_three_pin_level() -> void:
	await _compare(LevelLibrary.load_builtin("workshop.three_pins").definition, "three pins")


func test_physics_matches_the_drawing_on_the_lab_level() -> void:
	await _compare(LevelLibrary.load_builtin("dev.physics_lab").definition, "physics lab")


func test_physics_matches_the_drawing_with_polygon_walls_and_pins_at_angles() -> void:
	# The fixture has a polygon block and pins; add a diagonal pin and a concave L polygon.
	var data: Dictionary = LevelFixtures.minimal()
	(data["walls"] as Array).append(PhysicsScenarios.polygon("wall.ell", [
		Vector2(600.0, 420.0), Vector2(800.0, 420.0), Vector2(800.0, 470.0), Vector2(650.0, 470.0), Vector2(650.0, 600.0), Vector2(600.0, 600.0),
	]))
	(data["pins"] as Array).append({
		"id": "pin.diagonal", "tip": [300.0, 450.0], "handle": [180.0, 330.0], "thickness": 16,
		"pull_direction": [-0.7071067811865476, -0.7071067811865476], "pull_distance": 200,
	})
	var result: LevelLoader.LoadResult = LevelFixtures.check(data)
	assert_true(result.is_ok(), result.report.summary())
	await _compare(result.definition, "polygons and angled pins")


func test_the_checker_itself_notices_a_wrong_shape() -> void:
	# Mutation check on the test: a wall whose collision is one unit thinner than its drawing.
	var definition: LevelDefinition = LevelLibrary.load_builtin("workshop.three_pins").definition
	var world: SimWorld = make_world(definition)
	var outer: StaticPartBody = world.static_part("wall.outer")
	for child: Node in outer.get_children():
		var capsule: CapsuleShape2D = (child as CollisionShape2D).shape as CapsuleShape2D
		capsule.radius -= 3.0
	await step(2)
	var disagreements: int = 0
	# Scan a strip across the left wall (x = 160, 24 thick: solid from 148 to 172).
	for offset: int in range(-12, 13):
		var point: Vector2 = Vector2(160.0 + float(offset), 400.0)
		if _edge_distance(definition, point) < EDGE_BAND:
			continue
		if _engine_solid(point) != _drawn_solid(definition, point):
			disagreements += 1
	assert_true(disagreements >= 4, "a 3 unit error in a wall was noticed at %d points" % disagreements)
