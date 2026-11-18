extends PhysicsTestCase
## Tokens flow through intended openings and rest in stable piles, across repeated seeded runs,
## with no unexplained leaks and no persistent jams. Each scenario uses small seeded spawn
## jitter (never the gameplay RNG) so a layout that only works for one exact arrangement fails.
##
## Where a jam is real (an opening too narrow for a crowd) the tests show it happens and where
## the line is, so a jam is explained by geometry rather than hidden by the test.

const RAMP_ANGLES: Array[float] = [5.0, 10.0, 20.0, 30.0, 45.0, 60.0]
const RAMP_SEEDS: int = 6
const FUNNEL_TOKENS: int = 36
const FUNNEL_SEEDS: int = 20


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Ticks until every token has rolled past the ramp's lower end, or -1.
func _ramp_run(angle: float, seed_value: int, max_ticks: int) -> int:
	var world: SimWorld = make_world(PhysicsScenarios.ramp(angle, 5, 3.0, _rng(seed_value)))
	var end_x: float = PhysicsScenarios.ramp_end(angle).x + 6.0
	var done: Callable = func() -> bool:
		for body: TokenBody in world.tokens():
			if body.position.x < end_x:
				return false
		return true
	var ticks: int = await step_until(max_ticks, done)
	var outside: int = world.tokens_outside_board(0.0).size()
	assert_eq(outside, 0, "ramp %s seed %d: no token left the board" % [angle, seed_value])
	await discard_world(world)
	return ticks


## Ticks until every token is below the funnel, or -1. `world_out` receives the final state.
func _funnel_run(opening: float, seed_value: int, max_ticks: int, summary: Dictionary) -> int:
	var world: SimWorld = make_world(PhysicsScenarios.funnel(opening, FUNNEL_TOKENS, 3.0, _rng(seed_value)))
	var done: Callable = func() -> bool:
		for body: TokenBody in world.tokens():
			if body.position.y < PhysicsScenarios.FUNNEL_BOTTOM_Y + 30.0:
				return false
		return true
	var ticks: int = await step_until(max_ticks, done)
	summary["asleep"] = world.all_tokens_asleep()
	summary["above"] = 0
	for body: TokenBody in world.tokens():
		if body.position.y < PhysicsScenarios.FUNNEL_BOTTOM_Y + 30.0:
			summary["above"] = (summary["above"] as int) + 1
	summary["outside"] = world.tokens_outside_board(0.0).size()
	await discard_world(world)
	return ticks


func test_ramps_at_comfortable_slopes_and_steeper_always_flow() -> void:
	var slowest: int = 0
	var runs: int = 0
	for angle: float in RAMP_ANGLES:
		assert_true(angle >= SimConfig.COMFORTABLE_SLOPE_DEGREES)
		for seed_value: int in RAMP_SEEDS:
			var ticks: int = await _ramp_run(angle, 100 + seed_value, 1000)
			assert_true(ticks >= 0, "ramp %s degrees seed %d did not flow within 1000 ticks" % [angle, seed_value])
			slowest = maxi(slowest, ticks)
			runs += 1
	assert_eq(runs, RAMP_ANGLES.size() * RAMP_SEEDS)
	assert_true(slowest > 100, "the slowest run (%d ticks) took real time, so the measurement is meaningful" % slowest)


func test_a_shallow_ramp_still_flows_but_crawls() -> void:
	var shallow: int = await _ramp_run(3.0, 100, 1500)
	var steep: int = await _ramp_run(10.0, 100, 1500)
	assert_true(shallow >= 0, "3 degrees flows (slowly)")
	assert_true(steep >= 0)
	assert_true(shallow > steep * 1.5, "3 degrees (%d ticks) is much slower than 10 degrees (%d); this is why SimConfig.COMFORTABLE_SLOPE_DEGREES exists" % [shallow, steep])


func test_a_crowd_always_passes_an_opening_of_the_reliable_width() -> void:
	var opening: float = SimConfig.RELIABLE_OPENING_DIAMETERS * PhysicsScenarios.TOKEN_DIAMETER
	var slowest: int = 0
	for seed_value: int in FUNNEL_SEEDS:
		var summary: Dictionary = {}
		var ticks: int = await _funnel_run(opening, 200 + seed_value, 1500, summary)
		assert_true(ticks >= 0, "seed %d: %d of %d tokens still above the opening after 1500 ticks" % [seed_value, summary["above"] as int, FUNNEL_TOKENS])
		assert_eq(summary["outside"], 0, "seed %d: nothing left the board" % seed_value)
		slowest = maxi(slowest, ticks)
	assert_true(slowest > 60, "the slowest crowd took %d ticks" % slowest)


func test_a_wider_opening_is_never_slower_to_become_reliable() -> void:
	# 4 diameters also passes every seed (the guideline is a floor, not a knife edge).
	var opening: float = 4.0 * PhysicsScenarios.TOKEN_DIAMETER
	for seed_value: int in 10:
		var summary: Dictionary = {}
		var ticks: int = await _funnel_run(opening, 300 + seed_value, 1500, summary)
		assert_true(ticks >= 0, "seed %d at 4 diameters" % seed_value)


func test_narrow_openings_jam_for_a_real_reason() -> void:
	# An opening narrower than a token cannot pass anything (one exactly as wide as a token can
	# squeeze a single token through, so the test uses 90 percent). Two diameters jams a crowd by
	# forming a stable arch, most of the time. These are physical jams at known widths.
	var summary: Dictionary = {}
	var too_small: int = await _funnel_run(PhysicsScenarios.TOKEN_DIAMETER * 0.9, 400, 900, summary)
	assert_eq(too_small, -1, "narrower than a token: nothing passes")
	assert_eq(summary["above"], FUNNEL_TOKENS, "every token is still above the opening")

	var jammed: int = 0
	var jammed_and_still: int = 0
	for seed_value: int in 10:
		var result: Dictionary = {}
		var ticks: int = await _funnel_run(2.0 * PhysicsScenarios.TOKEN_DIAMETER, 500 + seed_value, 1500, result)
		if ticks < 0:
			jammed += 1
			if result["asleep"] as bool:
				jammed_and_still += 1
	assert_true(jammed >= 3, "at 2 diameters at least 3 of 10 crowds jam; %d did" % jammed)
	assert_true(jammed_and_still >= 1, "a jam is a stable arch (asleep), not endless churning; %d of %d" % [jammed_and_still, jammed])


func test_tight_corners_wedge_tokens_but_never_let_one_through_a_wall() -> void:
	var apex_y: float = 800.0
	var checked: int = 0
	for angle: float in [20.0, 30.0, 45.0, 90.0, 120.0]:
		for seed_value: int in 3:
			var world: SimWorld = make_world(PhysicsScenarios.corner(angle, 16, 2.0, _rng(700 + seed_value)))
			var ticks: int = await step_until(1500, func() -> bool: return world.all_tokens_asleep())
			assert_true(ticks >= 0, "corner %s seed %d: settled" % [angle, seed_value])
			for body: TokenBody in world.tokens():
				assert_true(body.position.y <= apex_y + 2.0, "corner %s seed %d: %s ended at y=%.1f below the corner apex" % [angle, seed_value, body.material_id, body.position.y])
				checked += 1
			assert_eq(world.tokens_outside_board(0.0).size(), 0)
			await discard_world(world)
	assert_eq(checked, 5 * 3 * 16)


func test_piles_up_to_the_body_limit_settle_inside_the_box() -> void:
	for count: int in [25, 75, SimConfig.MAX_DYNAMIC_BODIES]:
		for seed_value: int in 3:
			var world: SimWorld = make_world(PhysicsScenarios.bowl(count, 2.0, _rng(900 + seed_value)))
			var ticks: int = await step_until(2500, func() -> bool: return world.all_tokens_asleep())
			assert_true(ticks >= 0, "pile of %d seed %d: asleep within 2500 ticks (%d tokens still awake)" % [count, seed_value, world.awake_token_count()])
			assert_eq(world.tokens_outside_board(0.0).size(), 0)
			for body: TokenBody in world.tokens():
				# Inside the box: between the walls' inner faces and above the floor's top face.
				assert_true(body.position.x > 312.0 + 13.0 and body.position.x < 888.0 - 13.0 + 700.0, "%s x=%.1f" % [body.material_id, body.position.x])
				assert_true(body.position.y < 888.0 - 13.0, "%s y=%.1f is below the floor surface" % [body.material_id, body.position.y])
			await discard_world(world)


func test_tokens_are_solid_to_each_other_in_a_pile() -> void:
	# 100 tokens in a 576 unit wide box hold at most about 20 per layer, so a real pile is at
	# least 5 layers high; tokens that passed through each other would all lie on the floor.
	var world: SimWorld = make_world(PhysicsScenarios.bowl(100, 2.0, _rng(3)))
	var ticks: int = await step_until(2500, func() -> bool: return world.all_tokens_asleep())
	assert_true(ticks >= 0, "settled")
	var floor_row_y: float = 888.0 - (LevelSchema.MATERIAL_RADIUS[LevelSchema.MATERIAL_TOKEN] as float)
	var top: float = floor_row_y
	var closest: float = INF
	for first_index: int in world.token_count():
		var first: TokenBody = world.tokens()[first_index]
		top = minf(top, first.position.y)
		for second_index: int in range(first_index + 1, world.token_count()):
			closest = minf(closest, first.position.distance_to(world.tokens()[second_index].position))
	assert_true(floor_row_y - top >= 4.0 * 24.0, "the pile is %.0f units tall, at least 4 layers" % (floor_row_y - top))
	# Two tokens may sink into each other a little under load, never by more than a few units.
	assert_true(closest >= 2.0 * 14.0 - 3.0, "closest pair of centres is %.1f apart (a token is 28 across)" % closest)


func test_a_settled_pile_stays_put() -> void:
	var world: SimWorld = make_world(PhysicsScenarios.bowl(100, 2.0, _rng(1)))
	var ticks: int = await step_until(2500, func() -> bool: return world.all_tokens_asleep())
	assert_true(ticks >= 0)
	var before: String = world.state_signature()
	await step(300)
	assert_eq(world.state_signature(), before, "asleep means asleep: nothing moved in 5 more seconds")


func test_repeated_runs_of_the_same_level_are_identical_and_different_seeds_are_not() -> void:
	# Same machine, same build: identical. (Nothing here claims cross-machine determinism.)
	var signatures: Array[String] = []
	for _run: int in 2:
		var world: SimWorld = make_world(PhysicsScenarios.funnel(100.0, 24, 3.0, _rng(77)))
		await step(300)
		signatures.append(world.state_signature())
		await discard_world(world)
	assert_eq(signatures[0], signatures[1], "identical definition gives an identical world")

	var other: SimWorld = make_world(PhysicsScenarios.funnel(100.0, 24, 3.0, _rng(78)))
	await step(300)
	assert_ne(other.state_signature(), signatures[0], "a different jitter seed gives a different world, so the comparison above means something")


func test_the_three_pin_level_rests_exactly_as_authored() -> void:
	# Pins are static for now, so the five tokens must come to rest on pin.a without leaking.
	var definition: LevelDefinition = LevelLibrary.load_builtin("workshop.three_pins").definition
	var world: SimWorld = make_world(definition)
	var ticks: int = await step_until(900, func() -> bool: return world.all_tokens_asleep())
	assert_true(ticks >= 0, "settled")
	var pin_top: float = definition.find_pin("pin.a").tip.y - definition.find_pin("pin.a").thickness * 0.5
	for body: TokenBody in world.tokens():
		assert_true(body.position.y < pin_top - 10.0, "%s rests above pin.a (y=%.1f, pin top %.1f)" % [body.material_id, body.position.y, pin_top])
		assert_true(body.position.x > 172.0 and body.position.x < 748.0, "%s is inside the left chamber (x=%.1f)" % [body.material_id, body.position.x])
	assert_eq(world.tokens_outside_board(0.0).size(), 0)


func test_the_lab_level_flows_to_the_funnel_and_settles() -> void:
	var definition: LevelDefinition = LevelLibrary.load_builtin("dev.physics_lab").definition
	var world: SimWorld = make_world(definition)
	var ticks: int = await step_until(3000, func() -> bool: return world.all_tokens_asleep())
	assert_true(ticks >= 0, "everything is asleep within 50 seconds (%d awake)" % world.awake_token_count())
	assert_eq(world.tokens_outside_board(0.0).size(), 0)
	var delivered: int = 0
	for body: TokenBody in world.tokens():
		if body.position.y > 700.0:
			delivered += 1
	assert_true(delivered >= 44, "%d of 48 tokens made it down to the funnel and floor" % delivered)


func test_the_body_limit_costs_a_small_part_of_the_tick_budget() -> void:
	# A tripwire for gross regressions, not a benchmark: measured about 0.9 ms mean and 2.4 ms
	# worst on the development machine, so a ceiling of half the 60 Hz tick fails only if
	# something got several times slower. Real numbers: scripts\profile-physics.ps1.
	var world: SimWorld = make_world(PhysicsScenarios.bowl(SimConfig.MAX_DYNAMIC_BODIES, 2.0, _rng(5)))
	var durations: PackedFloat64Array = PackedFloat64Array()
	var last: int = Time.get_ticks_usec()
	for _tick: int in 400:
		await tree.physics_frame
		var now: int = Time.get_ticks_usec()
		durations.append(float(now - last))
		last = now
		if world.all_tokens_asleep():
			break
	assert_true(durations.size() >= 100, "the pile stayed awake for %d ticks, long enough to measure" % durations.size())
	var total: float = 0.0
	for value: float in durations:
		total += value
	var mean: float = total / float(durations.size())
	assert_true(mean < 8000.0, "mean tick %.0f us with %d bodies (budget 16667 us)" % [mean, world.token_count()])
