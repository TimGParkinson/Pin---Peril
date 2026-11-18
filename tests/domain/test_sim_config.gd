extends TestCase


func test_tick_delta_matches_tick_rate() -> void:
	assert_almost_eq(SimConfig.TICK_DELTA * float(SimConfig.TICK_RATE), 1.0, 0.000001)


func test_ticks_for_seconds_rounds_to_nearest_tick() -> void:
	assert_eq(SimConfig.ticks_for_seconds(1.0), 60)
	assert_eq(SimConfig.ticks_for_seconds(0.5), 30)
	# 0.1 * 60 is 6.000000000000001 in floating point; it must still be 6.
	assert_eq(SimConfig.ticks_for_seconds(0.1), 6)
	assert_eq(SimConfig.ticks_for_seconds(0.0083), 0)
	assert_eq(SimConfig.ticks_for_seconds(0.0084), 1)


func test_ticks_for_seconds_rejects_non_positive_and_non_finite() -> void:
	assert_eq(SimConfig.ticks_for_seconds(0.0), 0)
	assert_eq(SimConfig.ticks_for_seconds(-3.0), 0)
	assert_eq(SimConfig.ticks_for_seconds(INF), 0)
	assert_eq(SimConfig.ticks_for_seconds(NAN), 0)


func test_seconds_for_ticks_round_trips() -> void:
	assert_almost_eq(SimConfig.seconds_for_ticks(60), 1.0, 0.000001)
	assert_almost_eq(SimConfig.seconds_for_ticks(90), 1.5, 0.000001)
	assert_eq(SimConfig.seconds_for_ticks(0), 0.0)
	assert_eq(SimConfig.seconds_for_ticks(-5), 0.0)
	assert_eq(SimConfig.ticks_for_seconds(SimConfig.seconds_for_ticks(123)), 123)


func test_project_physics_settings_match_the_documented_world() -> void:
	# Gravity, sleep and solver settings live in project.godot; SimConfig is the record.
	var mismatches: PackedStringArray = SimWorld.settings_mismatches()
	assert_true(mismatches.is_empty(), "\n".join(mismatches))


func test_the_settings_check_really_detects_a_changed_project_setting() -> void:
	# Mutation check on the safeguard itself: change one setting, expect it to be reported.
	var original: Variant = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", SimConfig.GRAVITY + 100.0)
	var mismatches: PackedStringArray = SimWorld.settings_mismatches()
	ProjectSettings.set_setting("physics/2d/default_gravity", original)
	assert_eq(mismatches.size(), 1)
	assert_true(mismatches[0].contains("default_gravity"), mismatches[0])
	assert_true(SimWorld.settings_mismatches().is_empty(), "restored")


func test_body_limit_is_one_number_in_both_places() -> void:
	assert_eq(LevelSchema.MAX_SPAWNS, SimConfig.MAX_DYNAMIC_BODIES)
	assert_eq(SimTuning.new().max_dynamic_bodies, SimConfig.MAX_DYNAMIC_BODIES)


func test_collision_layers_are_distinct_single_bits() -> void:
	var layers: Array[int] = [SimConfig.LAYER_WALL, SimConfig.LAYER_PIN, SimConfig.LAYER_TOKEN]
	var combined: int = 0
	for layer: int in layers:
		assert_true(layer > 0 and (layer & (layer - 1)) == 0, "layer %d is a single bit" % layer)
		assert_eq(combined & layer, 0, "layer %d is not reused" % layer)
		combined |= layer
	assert_eq(combined, 7)


func test_sizes_are_not_tiny() -> void:
	# Prompt 03: avoid tiny bodies and thin walls. These are the floors that tuning relies on.
	var radius: float = LevelSchema.MATERIAL_RADIUS[LevelSchema.MATERIAL_TOKEN] as float
	assert_true(radius >= 12.0, "token radius %s" % radius)
	assert_true(LevelSchema.WALL_THICKNESS_MIN >= 8.0)
	assert_true(LevelSchema.WALL_THICKNESS_MIN >= radius * 0.5, "the thinnest wall is at least a quarter of a token wide")
	assert_true(LevelSchema.SPAWN_GAP >= 2.0, "spawned bodies never start touching")


## The tuning this build records with replay results. If this fails after an intentional change:
## bump SimConfig.CONFIG_VERSION (and every level's sim_config_version), update docs/PHYSICS.md
## with the new measurements, rerun scripts\test-physics.ps1, and only then update this text.
const RECORDED_TUNING: String = "v2 mass=1.0000 friction=0.4000 bounce=0.1500 ldamp=0.0500 adamp=1.0000 ccd=1 vmax=1000.0 wfriction=0.5000 wbounce=0.1000 bodies=150"


func test_the_physics_tuning_is_the_recorded_one() -> void:
	assert_eq(SimTuning.new().signature(), RECORDED_TUNING, "tuning changed without a deliberate version bump and revalidation")
	assert_eq(SimConfig.CONFIG_VERSION, 2)
	assert_eq(SimConfig.GRAVITY, 1000.0)
	assert_eq(SimConfig.TOKEN_CCD_MODE, RigidBody2D.CCD_MODE_CAST_RAY)


func test_tuning_defaults_come_from_sim_config_and_the_signature_tracks_every_change() -> void:
	var tuning: SimTuning = SimTuning.new()
	assert_eq(tuning.max_token_speed, SimConfig.MAX_TOKEN_SPEED)
	assert_eq(tuning.token_mass, SimConfig.TOKEN_MASS)
	assert_eq(tuning.token_ccd_mode, SimConfig.TOKEN_CCD_MODE)
	var baseline: String = tuning.signature()
	assert_eq(SimTuning.new().signature(), baseline, "same numbers, same text")
	assert_true(baseline.begins_with("v%d " % SimConfig.CONFIG_VERSION), "records the sim config version")
	var changes: Array[Callable] = [
		func(t: SimTuning) -> void: t.token_mass += 0.5,
		func(t: SimTuning) -> void: t.token_friction += 0.1,
		func(t: SimTuning) -> void: t.token_bounce += 0.1,
		func(t: SimTuning) -> void: t.token_linear_damp += 0.1,
		func(t: SimTuning) -> void: t.token_angular_damp += 0.1,
		func(t: SimTuning) -> void: t.token_ccd_mode = RigidBody2D.CCD_MODE_DISABLED,
		func(t: SimTuning) -> void: t.max_token_speed = 0.0,
		func(t: SimTuning) -> void: t.wall_friction += 0.1,
		func(t: SimTuning) -> void: t.wall_bounce += 0.1,
		func(t: SimTuning) -> void: t.max_dynamic_bodies -= 1,
	]
	for change: Callable in changes:
		var changed: SimTuning = SimTuning.new()
		change.call(changed)
		assert_ne(changed.signature(), baseline)
