extends PhysicsTestCase
## The world is built from the level exactly as documented, and the real physics step obeys the
## documented gravity, speed limit and tick rate.


func test_world_has_one_body_per_part_with_the_documented_settings() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var world: SimWorld = make_world(definition)
	assert_eq(world.static_parts().size(), 6, "4 walls + 2 pins")
	assert_eq(world.token_count(), 3, "scrap and cores are not simulated yet")
	assert_null(world.token_body("scrap.1"))
	assert_null(world.token_body("core.1"))

	var radius: float = LevelSchema.MATERIAL_RADIUS[LevelSchema.MATERIAL_TOKEN] as float
	for index: int in world.token_count():
		var body: TokenBody = world.tokens()[index]
		var spawn: LevelDefinition.Spawn = definition.spawns[index]
		assert_eq(body.material_id, spawn.id, "tokens are in spawn order with stable ids")
		assert_eq(body.position, spawn.position, "starts exactly at the authored position")
		assert_eq(body.collision_layer, SimConfig.LAYER_TOKEN)
		assert_eq(body.collision_mask, SimConfig.LAYER_WALL | SimConfig.LAYER_PIN | SimConfig.LAYER_TOKEN)
		# The engine stores 32-bit floats, so compare with a tolerance far below any real change.
		assert_almost_eq(body.mass, SimConfig.TOKEN_MASS, 0.000001)
		assert_eq(body.linear_damp_mode, RigidBody2D.DAMP_MODE_REPLACE, "project damping defaults cannot change the feel")
		assert_eq(body.angular_damp_mode, RigidBody2D.DAMP_MODE_REPLACE)
		assert_almost_eq(body.linear_damp, SimConfig.TOKEN_LINEAR_DAMP, 0.000001)
		assert_almost_eq(body.angular_damp, SimConfig.TOKEN_ANGULAR_DAMP, 0.000001)
		assert_almost_eq(body.physics_material_override.friction, SimConfig.TOKEN_FRICTION, 0.000001)
		assert_almost_eq(body.physics_material_override.bounce, SimConfig.TOKEN_BOUNCE, 0.000001)
		assert_eq(body.continuous_cd, RigidBody2D.CCD_MODE_CAST_RAY, "ray CCD on tokens, justified by observed tunnelling")
		assert_eq(body.max_speed, SimConfig.MAX_TOKEN_SPEED)
		assert_true(body.can_sleep)
		assert_eq(body.get_child_count(), 1)
		var circle: CircleShape2D = (body.get_child(0) as CollisionShape2D).shape as CircleShape2D
		assert_not_null(circle)
		assert_almost_eq(circle.radius, radius, 0.000001)

	for part: StaticPartBody in world.static_parts():
		assert_eq(part.collision_mask, 0)
		assert_eq(part.collision_layer, SimConfig.LAYER_WALL if part.part_kind == StaticPartBody.KIND_WALL else SimConfig.LAYER_PIN)
		assert_almost_eq(part.physics_material_override.friction, SimConfig.WALL_FRICTION, 0.000001)
		assert_almost_eq(part.physics_material_override.bounce, SimConfig.WALL_BOUNCE, 0.000001)
	assert_eq(world.static_part("wall.block").part_kind, StaticPartBody.KIND_WALL)
	assert_eq(world.static_part("pin.two").part_kind, StaticPartBody.KIND_PIN)
	assert_null(world.static_part("wall.nope"))
	assert_eq(world.static_part("wall.floor").get_child_count(), 1, "a single segment is one capsule")


func test_world_refuses_to_build_a_partial_or_unsafe_world() -> void:
	var instance: LevelInstance = LevelInstance.create(LevelFixtures.minimal_definition())

	var no_instance: SimWorld = SimWorld.new()
	assert_false(no_instance.build(null))
	assert_true(no_instance.build_problems[0].contains("no level instance"))
	no_instance.free()

	var too_many: SimWorld = SimWorld.new()
	var tight: SimTuning = SimTuning.new()
	tight.max_dynamic_bodies = 2  # the level has 3 tokens
	assert_false(too_many.build(instance, tight))
	assert_true(too_many.build_problems[0].contains("exceed"), too_many.build_problems[0])
	assert_eq(too_many.get_child_count(), 0, "no bodies were created")
	too_many.free()

	var twice: SimWorld = SimWorld.new()
	assert_true(twice.build(instance))
	assert_false(twice.build(instance))
	assert_true(twice.build_problems[0].contains("already built"))
	twice.free()

	var original: Variant = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 2000.0)
	var wrong_gravity: SimWorld = SimWorld.new()
	var built: bool = wrong_gravity.build(instance)
	ProjectSettings.set_setting("physics/2d/default_gravity", original)
	assert_false(built, "a changed project setting stops the world from building")
	assert_true(wrong_gravity.build_problems[0].contains("default_gravity"), wrong_gravity.build_problems[0])
	wrong_gravity.free()


func test_gravity_is_the_documented_acceleration() -> void:
	# One token in a tall empty shaft. Measure how its speed changes between two later ticks;
	# comparing two samples cancels any one-tick offset in when the first step happens.
	var world: SimWorld = make_world(PhysicsScenarios.flat_floor_shaft(8.0, 1))
	var body: TokenBody = world.tokens()[0]
	await step(10)
	var first_tick: int = world.tick_count
	var first_speed: Vector2 = body.linear_velocity
	await step(30)
	var second_tick: int = world.tick_count
	var second_speed: Vector2 = body.linear_velocity
	var elapsed: float = float(second_tick - first_tick) * SimConfig.TICK_DELTA
	var measured: float = (second_speed.y - first_speed.y) / elapsed
	# Linear damping removes damp * speed from the acceleration (about 2 percent at these
	# speeds), so the expected figure is g - damp * mean speed, not g itself.
	var expected: float = SimConfig.GRAVITY - SimConfig.TOKEN_LINEAR_DAMP * (first_speed.y + second_speed.y) * 0.5
	assert_almost_eq(measured, expected, SimConfig.GRAVITY * 0.005, "measured acceleration %.1f vs expected %.1f (gravity %.1f less damping)" % [measured, expected, SimConfig.GRAVITY])
	assert_true(measured < SimConfig.GRAVITY and measured > SimConfig.GRAVITY * 0.95, "close to, and just under, the configured gravity")
	assert_almost_eq(second_speed.x, 0.0, 0.01, "gravity points straight down")
	assert_true(second_speed.y < SimConfig.MAX_TOKEN_SPEED, "still below the limit, so the limit did not distort this")


func test_speed_limit_holds_during_a_long_fall_and_is_really_reached() -> void:
	var world: SimWorld = make_world(PhysicsScenarios.flat_floor_shaft(8.0, 1))
	await step(150)  # about 2.5 s: falls well past the point where the limit applies
	var limit: float = SimConfig.MAX_TOKEN_SPEED
	var one_tick_of_gravity: float = SimConfig.GRAVITY * SimConfig.TICK_DELTA
	assert_true(world.peak_token_speed() >= limit * 0.99, "the limit was reached (peak %.1f)" % world.peak_token_speed())
	assert_true(world.peak_token_speed() <= limit + one_tick_of_gravity, "never above limit plus one tick of gravity (peak %.1f)" % world.peak_token_speed())
	assert_true(world.fastest_token_speed() <= limit + one_tick_of_gravity)


func test_without_the_speed_limit_a_long_fall_is_much_faster() -> void:
	# Proves the test above would notice if the limit stopped working.
	var tuning: SimTuning = SimTuning.new()
	tuning.max_token_speed = 0.0
	var world: SimWorld = make_world(PhysicsScenarios.flat_floor_shaft(8.0, 1), tuning)
	await step(150)
	assert_true(world.peak_token_speed() > SimConfig.MAX_TOKEN_SPEED * 1.4, "peak %.1f" % world.peak_token_speed())


func test_the_world_advances_exactly_one_tick_per_physics_frame() -> void:
	var world: SimWorld = make_world(LevelFixtures.minimal_definition())
	await step(2)
	var before: int = world.tick_count
	await step(25)
	assert_eq(world.tick_count - before, 25)
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") as int, SimConfig.TICK_RATE)
	assert_eq(Engine.physics_ticks_per_second, SimConfig.TICK_RATE)


func test_static_geometry_never_moves() -> void:
	var definition: LevelDefinition = LevelLibrary.load_builtin("dev.physics_lab").definition
	var world: SimWorld = make_world(definition)
	var before: String = _static_signature(world)
	await step(400)
	assert_eq(_static_signature(world), before, "walls and pins are exactly where they were built")


func test_token_records_follow_their_bodies() -> void:
	var world: SimWorld = make_world(PhysicsScenarios.flat_floor_shaft(8.0, 3))
	await step(30)
	var moved: int = 0
	for index: int in world.token_count():
		var body: TokenBody = world.tokens()[index]
		var record: LevelInstance.MaterialState = world.instance.find_material(body.material_id)
		# The record is copied once per tick, so it may trail the body by one tick of travel.
		var tolerance: float = body.linear_velocity.length() * SimConfig.TICK_DELTA + 0.01
		assert_true(record.position.distance_to(body.position) <= tolerance, "%s record %s body %s" % [body.material_id, record.position, body.position])
		if record.position.distance_to(definition_position(world, body.material_id)) > 10.0:
			moved += 1
	assert_eq(moved, 3, "all three tokens have fallen, so the records really changed")


func definition_position(world: SimWorld, material_id: String) -> Vector2:
	for spawn: LevelDefinition.Spawn in world.instance.definition.spawns:
		if spawn.id == material_id:
			return spawn.position
	return Vector2.ZERO


func _static_signature(world: SimWorld) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for part: StaticPartBody in world.static_parts():
		lines.append("%s %s" % [part.part_id, str(part.global_transform)])
		for child: Node in part.get_children():
			var shape_node: CollisionShape2D = child as CollisionShape2D
			lines.append("  %s %s" % [str(shape_node.global_transform), shape_node.shape.get_rect()])
	return "\n".join(lines)
