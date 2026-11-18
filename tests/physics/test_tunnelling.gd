extends PhysicsTestCase
## Tokens cannot pass through the thinnest legal walls. Measured facts behind the tuning
## (docs/PHYSICS.md): without continuous collision detection (CCD), the thinnest legal polygon
## plates and tapering wedges are tunnelled by a fraction of the tokens even at the speed limit,
## and an 8 unit polyline is tunnelled from about 1100 units/s. Ray CCD stops all of it, at any
## speed tried. Each protection is shown to be necessary (the same drops fail without it).
##
## Making these tests non-vacuous matters. The first version of this file ran every drop for a
## fixed 230 ticks, but a token needs about 265 ticks to fall the shaft at the speed limit, so no
## token had reached the floor and "0 tunnelled" proved nothing. Now every drop runs until every
## token has either gone through or come to rest (a falling token is never asleep), and the speed
## just before contact is recorded so each test can show the impact really happened at speed.
##
## Tokens start at slightly different heights (PhysicsScenarios.PHASE_STEP and the variants
## below) so they meet the wall at different points within a tick.

const SURFACE_Y: float = PhysicsScenarios.SHAFT_FLOOR_Y
const MAX_TICKS: int = 900
const VARIANTS: int = 8


## Drops every token and runs until each has gone through or is asleep. Returns
## {through, total, finished, min_impact}: finished is false if the limit of 900 ticks passed
## with a token still moving, min_impact is the slowest token's speed 40 units before the floor.
func _drop(definition: LevelDefinition, tuning: SimTuning = null) -> Dictionary:
	var world: SimWorld = make_world(definition, tuning)
	var impact: Dictionary = {}
	var finished: bool = false
	for _tick: int in MAX_TICKS:
		await tree.physics_frame
		var all_done: bool = true
		for body: TokenBody in world.tokens():
			if not impact.has(body.material_id) and body.position.y > SURFACE_Y - 40.0:
				impact[body.material_id] = body.linear_velocity.length()
			if not (body.position.y > SURFACE_Y + 14.0 or body.sleeping):
				all_done = false
		if all_done:
			finished = true
			break
	var through: int = 0
	var min_impact: float = INF
	for body: TokenBody in world.tokens():
		if body.position.y > SURFACE_Y + 14.0:
			through += 1
		if impact.has(body.material_id):
			min_impact = minf(min_impact, impact[body.material_id] as float)
	var result: Dictionary = {"through": through, "total": world.token_count(), "finished": finished, "min_impact": min_impact, "arrived": impact.size()}
	await discard_world(world)
	return result


func _tuning(speed_limit: float, ccd: int) -> SimTuning:
	var tuning: SimTuning = SimTuning.new()
	tuning.max_token_speed = speed_limit
	tuning.token_ccd_mode = ccd
	return tuning


## Eight variants of one thin shape, each with the tokens shifted a little so impacts differ.
## kind: "flat8" (thinnest legal polyline), "plate4" (thinnest legal polygon plate), "wedge5"
## (a polygon tapering to a point) or "trough8" (two thinnest polylines forming a V).
func _variants(kind: String) -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for variant: int in VARIANTS:
		var definition: LevelDefinition = null
		match kind:
			"flat8":
				definition = PhysicsScenarios.flat_floor_shaft(LevelSchema.WALL_THICKNESS_MIN, 10)
			"plate4":
				definition = PhysicsScenarios.plate_shaft(LevelSchema.SEGMENT_MIN_LENGTH, 10)
			"wedge5":
				# Six tokens 30 apart cover the first 150 of its 200 units, so none can miss it.
				definition = PhysicsScenarios.wedge_shaft(5.0, 200.0, 6, 4.0 + float(variant) * 3.0)
			_:
				definition = PhysicsScenarios.v_trough_shaft(LevelSchema.WALL_THICKNESS_MIN, 10)
		if kind != "wedge5":
			for spawn: LevelDefinition.Spawn in definition.spawns:
				spawn.position.y += float(variant) * 0.15
		result.append(definition)
	return result


## Drops all variants of a shape. Returns {through, total, finished, min_impact}, where finished
## means every drop finished.
func _drop_all(kind: String, tuning: SimTuning) -> Dictionary:
	var total: Dictionary = {"through": 0, "total": 0, "finished": true, "min_impact": INF, "arrived": 0}
	for definition: LevelDefinition in _variants(kind):
		var result: Dictionary = await _drop(definition, tuning)
		total["through"] = (total["through"] as int) + (result["through"] as int)
		total["total"] = (total["total"] as int) + (result["total"] as int)
		total["arrived"] = (total["arrived"] as int) + (result["arrived"] as int)
		total["finished"] = (total["finished"] as bool) and (result["finished"] as bool)
		total["min_impact"] = minf(total["min_impact"] as float, result["min_impact"] as float)
	return total


func test_no_token_passes_through_the_thinnest_legal_walls_with_the_shipped_tuning() -> void:
	var checked: int = 0
	for kind: String in ["flat8", "plate4", "wedge5", "trough8"]:
		var result: Dictionary = await _drop_all(kind, null)
		assert_true(result["finished"] as bool, "%s: every token landed or went through (none was still falling)" % kind)
		assert_eq(result["through"], 0, "%s: tokens through the wall" % kind)
		if kind != "trough8":
			# Straight drops: the token reaches the floor at the speed limit, so the impact was real.
			assert_eq(result["arrived"], result["total"], "%s: every token reached the floor" % kind)
			assert_true((result["min_impact"] as float) >= SimConfig.MAX_TOKEN_SPEED * 0.98, "%s: slowest impact %.0f" % [kind, result["min_impact"] as float])
		checked += result["total"] as int
	assert_eq(checked, VARIANTS * (10 + 10 + 6 + 10), "all shapes were dropped")


func test_ray_ccd_makes_even_an_unlimited_fall_safe() -> void:
	# Without the speed limit a token falling 3900 units hits at 1800 to 2700 units/s. With ray
	# CCD none passes through. The speed limit is therefore not what prevents tunnelling.
	for kind: String in ["flat8", "plate4", "wedge5", "trough8"]:
		var result: Dictionary = await _drop_all(kind, _tuning(0.0, RigidBody2D.CCD_MODE_CAST_RAY))
		assert_true(result["finished"] as bool, kind)
		assert_eq(result["through"], 0, "%s with ray CCD and no speed limit" % kind)
		if kind != "trough8":
			assert_true((result["min_impact"] as float) > 1800.0, "%s: impact speed %.0f is far beyond the limit" % [kind, result["min_impact"] as float])


func test_without_ccd_the_thin_polygons_tunnel_even_at_the_speed_limit() -> void:
	# Observed tunnelling is what justifies CCD. Measured at the limit of 1000 with CCD off:
	# about 5 percent of tokens through a 4 unit plate and 17 percent through a wedge, while an 8
	# unit polyline holds.
	var off: int = RigidBody2D.CCD_MODE_DISABLED
	var plate: Dictionary = await _drop_all("plate4", _tuning(SimConfig.MAX_TOKEN_SPEED, off))
	var wedge: Dictionary = await _drop_all("wedge5", _tuning(SimConfig.MAX_TOKEN_SPEED, off))
	var flat: Dictionary = await _drop_all("flat8", _tuning(SimConfig.MAX_TOKEN_SPEED, off))
	for result: Dictionary in [plate, wedge, flat]:
		assert_true(result["finished"] as bool)
		assert_true((result["min_impact"] as float) >= SimConfig.MAX_TOKEN_SPEED * 0.98, "the impact really was at the limit")
	assert_true((plate["through"] as int) + (wedge["through"] as int) >= 8, "plate %d of %d, wedge %d of %d tunnelled" % [plate["through"] as int, plate["total"] as int, wedge["through"] as int, wedge["total"] as int])
	assert_eq(flat["through"], 0, "an 8 unit polyline is safe at the limit even without CCD")


func test_without_the_limit_and_without_ccd_a_long_fall_tunnels_everything_thin() -> void:
	var off: int = RigidBody2D.CCD_MODE_DISABLED
	var total_through: int = 0
	for kind: String in ["flat8", "plate4", "wedge5"]:
		var result: Dictionary = await _drop_all(kind, _tuning(0.0, off))
		assert_true(result["finished"] as bool)
		total_through += result["through"] as int
		assert_true((result["through"] as int) >= (result["total"] as int) / 5, "%s: %d of %d tokens tunnelled" % [kind, result["through"] as int, result["total"] as int])
	assert_true(total_through >= 50, "%d tokens tunnelled" % total_through)


func test_shape_cast_ccd_is_not_a_fix() -> void:
	# Measured: CCD_MODE_CAST_SHAPE tunnels about as much as no CCD, so it is not an option. If
	# an engine upgrade changes this, revisit the choice in docs/PHYSICS.md.
	var shape_cast: int = RigidBody2D.CCD_MODE_CAST_SHAPE
	var plate: Dictionary = await _drop_all("plate4", _tuning(SimConfig.MAX_TOKEN_SPEED, shape_cast))
	var wedge: Dictionary = await _drop_all("wedge5", _tuning(SimConfig.MAX_TOKEN_SPEED, shape_cast))
	assert_true((plate["through"] as int) + (wedge["through"] as int) >= 8, "plate %d, wedge %d tunnelled with shape cast" % [plate["through"] as int, wedge["through"] as int])


func test_fast_tokens_landing_on_a_resting_row_stay_on_top_of_it() -> void:
	# Tokens against tokens use discrete detection only, so check them separately: ten tokens at
	# rest on a floor, ten more landing on them at full speed, with no speed limit at all. None
	# may end up inside another token or under the platform.
	for limit: float in [SimConfig.MAX_TOKEN_SPEED, 0.0]:
		var closest: float = INF
		var under: int = 0
		for variant: int in 6:
			var spawns: Array = []
			for index: int in 10:
				spawns.append(PhysicsScenarios.token("token.%d" % (index + 1), Vector2(60.0 + float(index) * 60.0, SURFACE_Y - 60.0)))
			for index: int in 10:
				spawns.append(PhysicsScenarios.token("token.%d" % (index + 11), Vector2(60.0 + float(index) * 60.0 + float(variant) * 3.0, 80.0 + float(index) * PhysicsScenarios.PHASE_STEP)))
			var walls: Array = [PhysicsScenarios.polyline("wall.floor", LevelSchema.WALL_THICKNESS_MIN, [Vector2(40.0, SURFACE_Y), Vector2(680.0, SURFACE_Y)])]
			var definition: LevelDefinition = PhysicsScenarios.level("test.stack", PhysicsScenarios.SHAFT_SIZE, walls, spawns)
			var world: SimWorld = make_world(definition, _tuning(limit, SimConfig.TOKEN_CCD_MODE))
			# Done when everything is asleep or has left the platform's width (tokens knocked off
			# the open edges fall away legitimately).
			var finished: int = await step_until(MAX_TICKS, func() -> bool:
				for body: TokenBody in world.tokens():
					var over_platform: bool = body.position.x > 40.0 and body.position.x < 680.0
					if over_platform and not body.sleeping:
						return false
				return true)
			assert_true(finished >= 0, "limit %.0f variant %d: the pile came to rest" % [limit, variant])
			assert_true(world.peak_token_speed() >= (SimConfig.MAX_TOKEN_SPEED * 0.98 if limit > 0.0 else 2000.0), "the arriving tokens really were fast (%.0f)" % world.peak_token_speed())
			for first_index: int in world.token_count():
				var first: TokenBody = world.tokens()[first_index]
				var over_platform: bool = first.position.x > 40.0 and first.position.x < 680.0
				if over_platform and first.position.y > SURFACE_Y + 2.0:
					under += 1
				for second_index: int in range(first_index + 1, world.token_count()):
					closest = minf(closest, first.position.distance_to(world.tokens()[second_index].position))
			await discard_world(world)
		assert_eq(under, 0, "limit %.0f: nothing ended up under the platform" % limit)
		assert_true(closest >= 2.0 * 14.0 - 3.0, "limit %.0f: closest pair of centres %.1f (a token is 28 across)" % [limit, closest])
