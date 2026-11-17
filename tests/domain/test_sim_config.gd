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
