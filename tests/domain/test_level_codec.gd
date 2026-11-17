extends TestCase
## Structural parsing of untrusted data, and lossless round trips.


func test_round_trip_through_plain_data_preserves_everything() -> void:
	var original: LevelDefinition = LevelFixtures.minimal_definition()
	var copy: LevelDefinition = LevelFixtures.check(LevelCodec.to_dict(original)).definition
	assert_not_null(copy, "round-tripped data is still valid")
	assert_eq(LevelCodec.to_json_text(copy), LevelCodec.to_json_text(original))
	assert_eq(copy.geometry_signature(), original.geometry_signature())
	assert_eq(copy.level_id, "test.minimal")
	assert_eq(copy.walls.size(), 4)
	assert_eq(copy.walls[3].kind, "polygon")
	assert_eq(copy.walls[3].points.size(), 4)
	assert_eq(copy.pins[1].handle, Vector2(940.0, 200.0))
	assert_eq(copy.pins[0].pull_direction, Vector2(-1.0, 0.0))
	assert_eq(copy.spawns[4].material, "core")
	assert_true(copy.goals[0].is_protected)
	assert_eq(copy.goals[1].accepts, PackedStringArray(["scrap", "core"]))
	assert_eq(copy.hazards[0].rect, Rect2(450.0, 560.0, 100.0, 70.0))
	assert_eq(copy.objective.fail_conditions, PackedStringArray(["scrap_in_protected", "core_in_protected"]))
	assert_eq(copy.known_sequences[1].actions, PackedStringArray(["pin.two", "pin.one"]))
	assert_eq(copy.known_sequences[1].expected_result, "lost")
	assert_eq(copy.meta.author, "Test Author")


func test_json_text_round_trip_is_byte_stable() -> void:
	var first: String = LevelCodec.to_json_text(LevelFixtures.minimal_definition())
	var reloaded: LevelLoader.LoadResult = LevelLoader.parse_text(first, SimConfig.CONFIG_VERSION)
	assert_true(reloaded.is_ok(), reloaded.report.summary())
	assert_eq(LevelCodec.to_json_text(reloaded.definition), first, "second save is identical to the first")


func test_json_text_is_canonical_sorted_and_newline_terminated() -> void:
	var text: String = LevelCodec.to_json_text(LevelFixtures.minimal_definition())
	assert_true(text.ends_with("}\n"))
	assert_true(text.find("\"allowed_mechanics\"") < text.find("\"design_size\""))
	assert_true(text.find("\"design_size\"") < text.find("\"walls\""))
	assert_true(text.contains("\t\"level_id\": \"test.minimal\""), "tab indented")


func test_saved_coordinates_are_quantised_and_then_stable() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	definition.spawns[0].position = Vector2(200.123456, 160.987654)
	var saved: LevelDefinition = LevelLoader.parse_text(LevelCodec.to_json_text(definition), SimConfig.CONFIG_VERSION).definition
	assert_almost_eq(saved.spawns[0].position.x, 200.1235, 0.00001)
	assert_almost_eq(saved.spawns[0].position.y, 160.9877, 0.00001)
	var saved_again: LevelDefinition = LevelLoader.parse_text(LevelCodec.to_json_text(saved), SimConfig.CONFIG_VERSION).definition
	assert_eq(saved_again.geometry_signature(), saved.geometry_signature(), "no further drift on later saves")


func test_clone_shares_no_state_with_the_original() -> void:
	var original: LevelDefinition = LevelFixtures.minimal_definition()
	var before: String = original.geometry_signature()
	var copy: LevelDefinition = LevelCodec.clone(original)
	assert_not_null(copy)
	assert_eq(copy.geometry_signature(), before)
	copy.spawns[0].position.x += 100.0
	copy.walls[0].points[0] = Vector2(1.0, 1.0)
	copy.pins[0].id = "pin.changed"
	copy.goals[0].accepts.append("scrap")
	assert_eq(original.geometry_signature(), before, "mutating the clone left the original untouched")
	assert_ne(copy.geometry_signature(), before)


func test_geometry_signature_covers_geometry_but_not_text_or_rules() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var baseline: String = definition.geometry_signature()
	definition.title = "A different title"
	definition.meta.notes = "other notes"
	definition.objective.required_tokens = 2
	definition.known_sequences.clear()
	assert_eq(definition.geometry_signature(), baseline, "text, notes, objective and solutions do not change geometry")
	var moved: LevelDefinition = LevelFixtures.minimal_definition()
	moved.spawns[2].position.x += 1.0
	assert_ne(moved.geometry_signature(), baseline, "moving one spawn by one unit does")
	var pin_moved: LevelDefinition = LevelFixtures.minimal_definition()
	pin_moved.pins[0].tip.y += 1.0
	assert_ne(pin_moved.geometry_signature(), baseline, "moving a pin does")
	assert_eq(definition.geometry_hash().length(), 64)
	assert_eq(definition.geometry_hash(), baseline.sha256_text())


func test_all_object_ids_lists_every_gameplay_object_once() -> void:
	var ids: PackedStringArray = LevelFixtures.minimal_definition().all_object_ids()
	assert_eq(ids.size(), 4 + 2 + 5 + 2 + 1)
	var seen: Dictionary = {}
	for id: String in ids:
		assert_false(seen.has(id), "id %s appears once" % id)
		seen[id] = true


func test_unknown_keys_are_rejected_wherever_they_appear() -> void:
	var top: Dictionary = LevelFixtures.minimal()
	top["script"] = "res://evil.gd"
	var report: ValidationReport = LevelFixtures.check(top).report
	assert_eq(report.paths_for("key.unknown"), PackedStringArray(["$"]))

	var nested: Dictionary = LevelFixtures.minimal()
	LevelFixtures.pin(nested, 0)["on_pull"] = "do something"
	assert_eq(LevelFixtures.check(nested).report.paths_for("key.unknown"), PackedStringArray(["pins[0]"]))

	var polygon: Dictionary = LevelFixtures.minimal()
	LevelFixtures.wall(polygon, 3)["thickness"] = 24
	assert_true(LevelFixtures.check(polygon).report.has_code("key.unknown"), "polygons take no thickness")


func test_missing_keys_are_reported() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	data.erase("objective")
	LevelFixtures.spawn(data, 0).erase("position")
	var report: ValidationReport = LevelFixtures.check(data).report
	assert_true(report.has_code("key.missing"))
	assert_true(report.paths_for("key.missing").has("spawns[0]"))


func test_wrong_types_are_reported_at_their_path() -> void:
	var cases: Array[Dictionary] = [
		{"path": "pins[0].thickness", "mutate": func(d: Dictionary) -> void: LevelFixtures.pin(d, 0)["thickness"] = "16"},
		{"path": "spawns[0].position", "mutate": func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = [1]},
		{"path": "spawns[0].position[0]", "mutate": func(d: Dictionary) -> void: LevelFixtures.spawn(d, 0)["position"] = ["a", 2]},
		{"path": "goals[0].rect", "mutate": func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["rect"] = [1, 2, 3]},
		{"path": "goals[0].protected", "mutate": func(d: Dictionary) -> void: LevelFixtures.goal(d, 0)["protected"] = "yes"},
		{"path": "level_id", "mutate": func(d: Dictionary) -> void: d["level_id"] = 12},
		{"path": "walls", "mutate": func(d: Dictionary) -> void: d["walls"] = {}},
		{"path": "objective.required_tokens", "mutate": func(d: Dictionary) -> void: LevelFixtures.objective(d)["required_tokens"] = 2.5},
		{"path": "objective", "mutate": func(d: Dictionary) -> void: d["objective"] = []},
		{"path": "allowed_mechanics[0]", "mutate": func(d: Dictionary) -> void: (d["allowed_mechanics"] as Array)[0] = 5},
		{"path": "pins[1]", "mutate": func(d: Dictionary) -> void: (d["pins"] as Array)[1] = "pin"},
	]
	for case: Dictionary in cases:
		var data: Dictionary = LevelFixtures.minimal()
		(case["mutate"] as Callable).call(data)
		var report: ValidationReport = LevelFixtures.check(data).report
		assert_true(report.has_code("type.mismatch"), "expected a type mismatch at %s, got %s" % [case["path"], report.summary()])
		assert_true(report.paths_for("type.mismatch").has(case["path"] as String), "path %s in %s" % [case["path"], report.summary()])


func test_whole_number_fields_accept_floats_that_are_whole() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	LevelFixtures.objective(data)["required_tokens"] = 3.0
	data["schema_version"] = 1.0
	assert_true(LevelFixtures.check(data).is_ok())


func test_top_level_value_must_be_an_object() -> void:
	for bad: Variant in [[], "level", 5, null, true]:
		var report: ValidationReport = LevelFixtures.check(bad).report
		assert_true(report.has_code("type.mismatch"), "value %s" % str(bad))


func test_resource_looking_strings_in_text_fields_are_plain_text_never_loaded() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	data["title"] = "res://evil.gd"
	(data["meta"] as Dictionary)["notes"] = "load(\"res://evil.tscn\") and preload and Object()"
	var result: LevelLoader.LoadResult = LevelFixtures.check(data)
	assert_true(result.is_ok(), result.report.summary())
	assert_eq(result.definition.title, "res://evil.gd", "kept as an ordinary string")
	assert_true(result.definition.meta.notes.contains("evil.tscn"))


func test_encoded_godot_values_in_text_are_not_decoded() -> void:
	# str_to_var would turn this into an Object-like value. JSON parsing must keep it a string.
	var data: Dictionary = LevelFixtures.minimal()
	data["title"] = "Vector2(1, 2)"
	var result: LevelLoader.LoadResult = LevelFixtures.check(data)
	assert_true(result.is_ok(), result.report.summary())
	assert_eq(typeof(result.definition.title), TYPE_STRING)
	assert_eq(result.definition.title, "Vector2(1, 2)")


func test_oversized_lists_are_refused_before_any_entry_is_parsed() -> void:
	# 1000 malformed entries. If the codec built objects first it would report a type
	# mismatch for each one; instead it must refuse the list as a whole.
	for key: String in ["walls", "pins", "spawns", "goals", "hazards", "known_sequences"]:
		var data: Dictionary = LevelFixtures.minimal()
		var junk: Array = []
		for _i: int in 1000:
			junk.append("not an object")
		data[key] = junk
		var report: ValidationReport = LevelFixtures.check(data).report
		assert_eq(report.codes(), PackedStringArray(["count.exceeded"]), "%s: %s" % [key, report.summary(3)])
		assert_eq(report.paths_for("count.exceeded"), PackedStringArray([key]))


func test_clone_is_exact_and_saving_is_quantised() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	definition.spawns[0].position = Vector2(200.123456, 160.987654)
	var copy: LevelDefinition = LevelCodec.clone(definition)
	assert_eq(copy.spawns[0].position, definition.spawns[0].position, "a clone must equal what was validated, bit for bit")
	var saved: LevelDefinition = LevelLoader.parse_text(LevelCodec.to_json_text(definition), SimConfig.CONFIG_VERSION).definition
	assert_ne(saved.spawns[0].position, definition.spawns[0].position, "saving rounds to 0.0001")
	assert_almost_eq(saved.spawns[0].position.x, definition.spawns[0].position.x, 0.0001)
	assert_ne(LevelCodec.to_dict(definition, false), LevelCodec.to_dict(definition, true))


func test_byte_order_mark_and_windows_line_endings_are_accepted() -> void:
	var text: String = LevelCodec.to_json_text(LevelFixtures.minimal_definition())
	var with_bom: LevelLoader.LoadResult = LevelLoader.parse_text("\uFEFF" + text, SimConfig.CONFIG_VERSION)
	assert_true(with_bom.is_ok(), "Notepad-style BOM: " + with_bom.report.summary(3))
	var crlf: LevelLoader.LoadResult = LevelLoader.parse_text(text.replace("\n", "\r\n"), SimConfig.CONFIG_VERSION)
	assert_true(crlf.is_ok(), "CRLF line endings: " + crlf.report.summary(3))
	assert_eq(LevelCodec.to_json_text(crlf.definition), text, "same level either way")
	var both: LevelLoader.LoadResult = LevelLoader.parse_text("\uFEFF" + text.replace("\n", "\r\n"), SimConfig.CONFIG_VERSION)
	assert_true(both.is_ok())
