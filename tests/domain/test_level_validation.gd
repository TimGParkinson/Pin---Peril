extends TestCase
## Malformed definitions must be caught, with the right code at the right place.
## Each case mutates a fresh copy of a known-good level, so a failure means that single
## mutation was not detected (or the good level stopped being good).


func test_the_unmodified_fixture_is_valid() -> void:
	var result: LevelLoader.LoadResult = LevelFixtures.check(LevelFixtures.minimal())
	assert_true(result.is_ok(), result.report.summary())
	assert_not_null(result.definition)
	assert_eq(result.definition.spawns.size(), 5)


func test_each_semantic_mistake_is_reported_with_its_code() -> void:
	var cases: Array[Dictionary] = _semantic_cases()
	assert_true(cases.size() >= 40, "case table is not accidentally empty")
	for case: Dictionary in cases:
		var data: Dictionary = LevelFixtures.minimal()
		(case["mutate"] as Callable).call(data)
		var result: LevelLoader.LoadResult = LevelFixtures.check(data)
		var code: String = case["code"] as String
		assert_false(result.is_ok(), "%s: must not be accepted" % case["name"])
		assert_true(result.report.has_code(code), "%s: expected code %s, got %s" % [case["name"], code, ", ".join(result.report.codes())])
		assert_null(result.definition, "%s: no definition is handed out for bad data" % case["name"])


func test_issue_paths_point_at_the_offending_object() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	LevelFixtures.spawn(data, 1)["position"] = [210, 160]  # overlaps token.1
	LevelFixtures.pin(data, 1)["thickness"] = 1  # too thin
	var report: ValidationReport = LevelFixtures.check(data).report
	assert_eq(report.paths_for("spawn.overlap"), PackedStringArray(["spawns[1].position"]))
	assert_eq(report.paths_for("pin.thickness"), PackedStringArray(["pins[1].thickness"]))
	assert_eq(report.issues.size(), 2, "exactly the two injected problems: " + report.summary())


func test_several_problems_are_all_reported_together() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	data["schema_version"] = 7
	LevelFixtures.objective(data)["required_tokens"] = 9
	(data["allowed_mechanics"] as Array).append("fans")
	var codes: PackedStringArray = LevelFixtures.check(data).report.codes()
	assert_true(codes.has("schema.version_unsupported"))
	assert_true(codes.has("objective.required_tokens"))
	assert_true(codes.has("mechanic.unsupported"))


func test_non_finite_numbers_are_rejected_without_running_geometry_checks() -> void:
	for bad: float in [NAN, INF, -INF]:
		var data: Dictionary = LevelFixtures.minimal()
		LevelFixtures.pin(data, 0)["tip"] = [bad, 200.0]
		var report: ValidationReport = LevelFixtures.check(data).report
		assert_true(report.has_code("number.not_finite"), "value %s" % bad)
		assert_eq(report.paths_for("number.not_finite"), PackedStringArray(["pins[0].tip"]))
		assert_eq(report.codes().size(), 1, "geometry checks are skipped when numbers are not finite")


func test_huge_exponent_numbers_in_text_are_not_accepted() -> void:
	# Godot prints "WARNING: Exponent too high" while parsing 1e999 and yields infinity.
	# That engine warning is expected here; the validator must then reject the value.
	var text: String = JSON.stringify(LevelFixtures.minimal()).replace("\"pull_distance\":240", "\"pull_distance\":1e999")
	assert_true(text.contains("1e999"), "fixture text was altered")
	var result: LevelLoader.LoadResult = LevelLoader.parse_text(text, SimConfig.CONFIG_VERSION)
	assert_false(result.is_ok())
	assert_eq(result.report.codes(), PackedStringArray(["number.not_finite"]), result.report.summary())
	assert_eq(result.report.paths_for("number.not_finite"), PackedStringArray(["pins[0].pull_distance", "pins[1].pull_distance"]))


func test_oversized_collections_are_rejected_quickly_before_geometry_work() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	var spawns: Array = data["spawns"] as Array
	for index: int in LevelSchema.MAX_SPAWNS + 50:
		# Deliberately all overlapping: an O(n squared) pass over these would be wasteful.
		spawns.append({"id": "extra.%d" % index, "material": "token", "position": [500, 500]})
	var started: int = Time.get_ticks_msec()
	var report: ValidationReport = LevelFixtures.check(data).report
	var elapsed: int = Time.get_ticks_msec() - started
	assert_true(report.has_code("count.exceeded"))
	assert_false(report.has_code("spawn.overlap"), "overlap pass is skipped once counts are exceeded")
	assert_true(elapsed < 1000, "rejected in %d ms" % elapsed)


func test_maximum_allowed_spawn_count_validates_in_bounded_time() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	data["design_size"] = [4000, 2000]
	var spawns: Array = data["spawns"] as Array
	spawns.clear()
	var count: int = 0
	for row: int in 10:
		for column: int in 15:
			spawns.append({"id": "token.%d" % count, "material": "token", "position": [300 + column * 40, 900 + row * 40]})
			count += 1
	assert_eq(count, LevelSchema.MAX_SPAWNS)
	LevelFixtures.objective(data)["required_tokens"] = count
	var started: int = Time.get_ticks_msec()
	var result: LevelLoader.LoadResult = LevelFixtures.check(data)
	var elapsed: int = Time.get_ticks_msec() - started
	assert_true(result.is_ok(), result.report.summary())
	assert_true(elapsed < 2000, "validated %d spawns in %d ms" % [count, elapsed])


func test_report_is_capped_so_hostile_files_cannot_flood_output() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	for index: int in 200:
		data["junk_%d" % index] = 1
	var report: ValidationReport = LevelFixtures.check(data).report
	assert_eq(report.issues.size(), LevelSchema.MAX_REPORT_ISSUES)
	assert_true(report.truncated)
	assert_true(report.summary().contains("more issues not shown"))


func test_spawn_clearances_accept_the_tightest_legal_placement() -> void:
	# Exactly SPAWN_GAP clear of another token and of a pin must still be valid.
	var data: Dictionary = LevelFixtures.minimal()
	LevelFixtures.spawn(data, 1)["position"] = [200.0 + 14.0 + 14.0 + LevelSchema.SPAWN_GAP, 160.0]
	assert_true(LevelFixtures.check(data).is_ok(), "touching-gap placement is legal")
	LevelFixtures.spawn(data, 1)["position"] = [200.0 + 14.0 + 14.0 + LevelSchema.SPAWN_GAP - 0.5, 160.0]
	assert_true(LevelFixtures.check(data).report.has_code("spawn.overlap"), "half a unit closer is not")


func test_reserved_future_mechanics_are_rejected_not_ignored() -> void:
	for mechanic: String in LevelSchema.RESERVED_MECHANICS:
		var data: Dictionary = LevelFixtures.minimal()
		(data["allowed_mechanics"] as Array).append(mechanic)
		assert_true(LevelFixtures.check(data).report.has_code("mechanic.unsupported"), mechanic)


func test_polygon_walls_are_validated_like_polylines() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	assert_true(LevelFixtures.check(data).is_ok(), "square polygon is fine")
	LevelFixtures.wall(data, 3)["points"] = [[400, 300], [500, 300]]
	assert_true(LevelFixtures.check(data).report.has_code("wall.too_few_points"), "two points is not a polygon")


func _semantic_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_case(cases, "schema version", "schema.version_unsupported", func(d: Dictionary) -> void: d["schema_version"] = 2)
	_case(cases, "sim version", "sim.version_mismatch", func(d: Dictionary) -> void: d["sim_config_version"] = 99)
	_case(cases, "level id uppercase", "id.invalid", func(d: Dictionary) -> void: d["level_id"] = "Bad Id")
	_case(cases, "level id empty", "id.invalid", func(d: Dictionary) -> void: d["level_id"] = "")
	_case(cases, "level id trailing dot", "id.invalid", func(d: Dictionary) -> void: d["level_id"] = "test.")
	_case(cases, "level id resource path", "id.invalid", func(d: Dictionary) -> void: d["level_id"] = "res://evil.gd")
	_case(cases, "object id with space", "id.invalid", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["id"] = "pin one")
	_case(cases, "duplicate id across kinds", "id.duplicate", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 1)["id"] = "pin.one")
	_case(cases, "duplicate spawn id", "id.duplicate", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 1)["id"] = "token.1")
	_case(cases, "design too small", "design.size_invalid", func(d: Dictionary) -> void: d["design_size"] = [100, 700])
	_case(cases, "design too big", "design.size_invalid", func(d: Dictionary) -> void: d["design_size"] = [99999, 700])
	_case(cases, "empty title", "text.invalid", func(d: Dictionary) -> void: d["title"] = "   ")
	_case(cases, "bad date", "meta.date_invalid", func(d: Dictionary) -> void: (d["meta"] as Dictionary)["created"] = "2026-13-01")
	_case(cases, "bad source", "meta.source_invalid", func(d: Dictionary) -> void: (d["meta"] as Dictionary)["source"] = "ai")
	_case(cases, "wall single point", "wall.too_few_points", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[100, 100]])
	_case(cases, "wall point negative", "wall.out_of_bounds", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[-5, 100], [900, 640]])
	_case(cases, "wall point beyond design", "wall.out_of_bounds", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[100, 100], [1200, 100]])
	_case(cases, "wall tiny segment", "wall.degenerate_segment", func(d: Dictionary) -> void: LevelFixtures.wall(d, 1)["points"] = [[100, 100], [100, 102]])
	_case(cases, "wall repeated point", "wall.degenerate_segment", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[100, 640], [100, 640], [900, 640]])
	_case(cases, "polygon bowtie", "wall.self_intersect", func(d: Dictionary) -> void: LevelFixtures.wall(d, 3)["points"] = [[400, 300], [500, 380], [500, 300], [400, 380]])
	_case(cases, "polyline crosses itself", "wall.self_intersect", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[100, 640], [900, 640], [500, 700], [500, 600]])
	_case(cases, "polyline folds back", "wall.self_intersect", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["points"] = [[100, 640], [500, 640], [300, 640]])
	_case(cases, "polygon too small", "wall.polygon_area", func(d: Dictionary) -> void: LevelFixtures.wall(d, 3)["points"] = [[400, 300], [410, 300], [410, 310], [400, 310]])
	_case(cases, "wall too thin", "wall.thickness", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["thickness"] = 2)
	_case(cases, "wall too thick", "wall.thickness", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["thickness"] = 200)
	_case(cases, "wall kind unknown", "wall.kind_invalid", func(d: Dictionary) -> void: LevelFixtures.wall(d, 0)["kind"] = "circle")
	_case(cases, "pin direction not unit", "pin.direction_not_unit", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["pull_direction"] = [2, 0])
	_case(cases, "pin direction zero", "pin.direction_not_unit", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["pull_direction"] = [0, 0])
	_case(cases, "pin direction reversed", "pin.direction_mismatch", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["pull_direction"] = [1, 0])
	_case(cases, "pin direction sideways", "pin.direction_mismatch", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["pull_direction"] = [0, -1])
	_case(cases, "pin pull too short", "pin.pull_distance", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["pull_distance"] = 100)
	_case(cases, "pin handle outside", "pin.out_of_bounds", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["handle"] = [-10, 200])
	_case(cases, "pin too short", "pin.length", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["handle"] = [290, 200])
	_case(cases, "pin too thin", "pin.thickness", func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["thickness"] = 1)
	_case(cases, "pins overlap", "pin.overlap", func(d: Dictionary) -> void:
		var second: Dictionary = LevelFixtures.pin(d, 1)
		second["tip"] = [300, 206]
		second["handle"] = [60, 206]
		second["pull_direction"] = [-1, 0])
	_case(cases, "spawn overlaps spawn", "spawn.overlap", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 1)["position"] = [210, 160])
	_case(cases, "spawn inside wall", "spawn.in_wall", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [105, 160])
	_case(cases, "spawn inside polygon wall", "spawn.in_wall", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [450, 340])
	_case(cases, "spawn outside design", "spawn.out_of_bounds", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [5, 5])
	_case(cases, "spawn inside goal", "spawn.in_zone", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [250, 590])
	_case(cases, "spawn inside hazard", "spawn.in_zone", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [500, 590])
	_case(cases, "spawn on pin", "spawn.in_pin", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [200, 205])
	_case(cases, "spawn unknown material", "spawn.unknown_material", func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["material"] = "gold")
	_case(cases, "scrap without mechanic", "mechanic.undeclared_use", func(d: Dictionary) -> void: d["allowed_mechanics"] = ["pins", "hazard_cores", "disposal_zones", "hazard_zones"])
	_case(cases, "core without mechanic", "mechanic.undeclared_use", func(d: Dictionary) -> void: d["allowed_mechanics"] = ["pins", "scrap", "disposal_zones", "hazard_zones"])
	_case(cases, "pins without mechanic", "mechanic.undeclared_use", func(d: Dictionary) -> void: d["allowed_mechanics"] = ["scrap", "hazard_cores", "disposal_zones", "hazard_zones"])
	_case(cases, "disposal without mechanic", "mechanic.undeclared_use", func(d: Dictionary) -> void: d["allowed_mechanics"] = ["pins", "scrap", "hazard_cores", "hazard_zones"])
	_case(cases, "hazard without mechanic", "mechanic.undeclared_use", func(d: Dictionary) -> void: d["allowed_mechanics"] = ["pins", "scrap", "hazard_cores", "disposal_zones"])
	_case(cases, "mechanic unsupported fans", "mechanic.unsupported", func(d: Dictionary) -> void: (d["allowed_mechanics"] as Array).append("fans"))
	_case(cases, "mechanic unsupported portals", "mechanic.unsupported", func(d: Dictionary) -> void: (d["allowed_mechanics"] as Array).append("portals"))
	_case(cases, "mechanic unknown", "mechanic.unknown", func(d: Dictionary) -> void: (d["allowed_mechanics"] as Array).append("teleporter"))
	_case(cases, "mechanic duplicate", "mechanic.duplicate", func(d: Dictionary) -> void: (d["allowed_mechanics"] as Array).append("pins"))
	_case(cases, "goal kind unknown", "goal.kind_invalid", func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["kind"] = "portal")
	_case(cases, "goal accepts nothing", "goal.accepts_empty", func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["accepts"] = [])
	_case(cases, "goal accepts unknown", "goal.accepts_unknown", func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["accepts"] = ["gold"])
	_case(cases, "goal too small", "goal.rect", func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["rect"] = [150, 560, 5, 5])
	_case(cases, "goal outside design", "goal.rect", func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["rect"] = [900, 560, 200, 70])
	_case(cases, "goal overlaps hazard", "goal.overlap", func(d: Dictionary) -> void: LevelFixtures.hazard(d, 0)["rect"] = [300, 560, 100, 70])
	_case(cases, "hazard kind unknown", "hazard.kind_invalid", func(d: Dictionary) -> void: LevelFixtures.hazard(d, 0)["kind"] = "lava")
	_case(cases, "hazard affects nothing", "hazard.affects_empty", func(d: Dictionary) -> void: LevelFixtures.hazard(d, 0)["affects"] = [])
	_case(cases, "objective needs more tokens than exist", "objective.required_tokens", func(d: Dictionary) -> void: LevelFixtures.objective(d)["required_tokens"] = 4)
	_case(cases, "objective needs zero tokens", "objective.required_tokens", func(d: Dictionary) -> void: LevelFixtures.objective(d)["required_tokens"] = 0)
	_case(cases, "objective losses exceed slack", "objective.allowed_losses", func(d: Dictionary) -> void: LevelFixtures.objective(d)["allowed_token_losses"] = 1)
	_case(cases, "objective collector missing", "objective.collector_ref", func(d: Dictionary) -> void: LevelFixtures.objective(d)["collector_ids"] = ["goal.nope"])
	_case(cases, "objective no collectors", "objective.collector_ref", func(d: Dictionary) -> void: LevelFixtures.objective(d)["collector_ids"] = [])
	_case(cases, "objective collector is disposal", "objective.collector_kind", func(d: Dictionary) -> void: LevelFixtures.objective(d)["collector_ids"] = ["goal.disposal"])
	_case(cases, "objective fail condition unknown", "objective.fail_condition_unknown", func(d: Dictionary) -> void: LevelFixtures.objective(d)["fail_conditions"] = ["explode"])
	_case(cases, "sequence unknown pin", "sequence.pin_unknown", func(d: Dictionary) -> void: LevelFixtures.sequence(d, 0)["actions"] = ["pin.nope"])
	_case(cases, "sequence repeats a pin", "sequence.pin_repeated", func(d: Dictionary) -> void: LevelFixtures.sequence(d, 0)["actions"] = ["pin.one", "pin.one"])
	_case(cases, "sequence unknown result", "sequence.result_unknown", func(d: Dictionary) -> void: LevelFixtures.sequence(d, 0)["expected_result"] = "draw")
	_case(cases, "sequence empty", "sequence.empty", func(d: Dictionary) -> void: LevelFixtures.sequence(d, 0)["actions"] = [])
	_case(cases, "duplicate sequence id", "id.duplicate", func(d: Dictionary) -> void: LevelFixtures.sequence(d, 1)["id"] = "seq.good")
	_case(cases, "too many spawns", "count.exceeded", func(d: Dictionary) -> void:
		var spawns: Array = d["spawns"] as Array
		for index: int in LevelSchema.MAX_SPAWNS + 1:
			spawns.append({"id": "extra.%d" % index, "material": "token", "position": [500, 500]}))
	_case(cases, "too many wall points", "count.exceeded", func(d: Dictionary) -> void:
		var points: Array = []
		for index: int in LevelSchema.MAX_WALL_POINTS + 1:
			points.append([100 + index, 100])
		LevelFixtures.wall(d, 0)["points"] = points)
	return cases


func _case(cases: Array[Dictionary], case_name: String, code: String, mutate: Callable) -> void:
	cases.append({"name": case_name, "code": code, "mutate": mutate})
