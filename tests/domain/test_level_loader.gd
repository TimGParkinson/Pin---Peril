extends TestCase
## File access rules: where levels may be read from, size limits, atomic saves.

const TEST_FILES: PackedStringArray = ["_test_roundtrip.json", "_test_big.json", "_test_bad.json", "_test_keep.json", "_test_other.json", "test.mismatch.json", "test.minimal.json"]


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func test_allowed_paths_are_accepted() -> void:
	assert_eq(LevelLoader.check_path("res://levels/workshop.three_pins.json"), "")
	assert_eq(LevelLoader.check_path("user://levels/my_level-2.json"), "")


func test_paths_outside_the_level_folders_are_rejected_before_any_file_access() -> void:
	var bad_paths: PackedStringArray = [
		"", "res://project.godot", "res://levels/../project.godot", "res://levels/sub/x.json",
		"res://levels/x.gd", "res://levels/x.tres", "res://levels/x.tscn", "res://levels/x.json.exe",
		"res://levels/", "user://evil.json", "user://levels/../evil.json", "C:/Windows/x.json",
		"/etc/passwd", "user://levels/X.json", "user://levels/a b.json", "user://levels/a\\b.json",
		"res://scenes/main.tscn", "user://levels/sub/dir.json", "https://example.com/x.json",
		# Valid-looking names in the wrong place. These pass every check except the root folder
		# check, so they only fail if that check really works.
		"res://a_long_file_name.json", "user://a_long_file_name.json", "res://scenes/a_long_name.json",
		"user://other/a_long_name.json", "res://level/data.json", "user://level/data.json",
	]
	for path: String in bad_paths:
		assert_ne(LevelLoader.check_path(path), "", "path must be rejected: '%s'" % path)
		var result: LevelLoader.LoadResult = LevelLoader.load_file(path, SimConfig.CONFIG_VERSION)
		assert_false(result.is_ok(), path)
		assert_true(result.report.has_code("path.rejected"), "'%s' rejected by path check, got %s" % [path, result.report.summary()])


func test_missing_file_is_reported() -> void:
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_missing_file.json", SimConfig.CONFIG_VERSION)
	assert_true(result.report.has_code("file.missing"))
	assert_null(result.definition)


func test_invalid_json_text_is_reported_with_a_line() -> void:
	_write("_test_bad.json", "{\n  \"schema_version\": 1,\n  oops\n}")
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_bad.json", SimConfig.CONFIG_VERSION)
	assert_true(result.report.has_code("json.parse"))
	# The engine reports the line where it gave up (line 2 or 3 here); just require a usable one.
	assert_true(result.report.summary().contains("line 2") or result.report.summary().contains("line 3"), result.report.summary())
	assert_null(result.definition)


func test_oversized_files_are_refused_without_parsing() -> void:
	_write("_test_big.json", "[" + "1,".repeat(LevelSchema.MAX_FILE_BYTES) + "1]")
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_big.json", SimConfig.CONFIG_VERSION)
	assert_true(result.report.has_code("file.too_large"), result.report.summary())
	assert_null(result.definition)


func test_a_valid_file_loads() -> void:
	_write("_test_roundtrip.json", JSON.stringify(LevelFixtures.minimal()))
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_roundtrip.json", SimConfig.CONFIG_VERSION)
	assert_true(result.is_ok(), result.report.summary())
	assert_eq(result.definition.level_id, "test.minimal")


func test_a_file_with_hostile_content_is_rejected_and_nothing_is_executed() -> void:
	var data: Dictionary = LevelFixtures.minimal()
	# If anything loaded or ran this script, the engine would print a SCRIPT ERROR and the
	# test wrapper would fail. Rejecting the file must not touch it.
	data["script"] = "res://tests/harness_fixtures/script_error/test_errors.gd"
	data["_class"] = "Object"
	_write("_test_bad.json", JSON.stringify(data))
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_bad.json", SimConfig.CONFIG_VERSION)
	assert_false(result.is_ok())
	assert_true(result.report.has_code("key.unknown"))
	assert_eq(result.report.paths_for("key.unknown"), PackedStringArray(["$", "$"]))
	assert_null(result.definition)

	# A resource path smuggled in as an id is rejected by validation, again without loading.
	var spoofed: Dictionary = LevelFixtures.minimal()
	spoofed["level_id"] = "res://tests/harness_fixtures/script_error/test_errors.gd"
	_write("_test_bad.json", JSON.stringify(spoofed))
	var spoofed_result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_bad.json", SimConfig.CONFIG_VERSION)
	assert_true(spoofed_result.report.has_code("id.invalid"))
	assert_null(spoofed_result.definition)


func test_save_then_load_round_trips_through_a_real_file() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	assert_eq(LevelLoader.save_file(definition, "user://levels/_test_roundtrip.json", SimConfig.CONFIG_VERSION), OK)
	assert_false(FileAccess.file_exists("user://levels/_test_roundtrip.json.tmp"), "no temp file left behind")
	var loaded: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_roundtrip.json", SimConfig.CONFIG_VERSION)
	assert_true(loaded.is_ok(), loaded.report.summary())
	assert_eq(loaded.definition.geometry_signature(), definition.geometry_signature())
	assert_eq(LevelCodec.to_json_text(loaded.definition), LevelCodec.to_json_text(definition))
	assert_eq(_read("_test_roundtrip.json"), LevelCodec.to_json_text(definition), "file holds the canonical text")


func test_save_refuses_an_invalid_definition_and_keeps_the_existing_file() -> void:
	var good: LevelDefinition = LevelFixtures.minimal_definition()
	assert_eq(LevelLoader.save_file(good, "user://levels/_test_keep.json", SimConfig.CONFIG_VERSION), OK)
	var before: String = _read("_test_keep.json")
	var broken: LevelDefinition = LevelFixtures.minimal_definition()
	broken.pins[0].thickness = 1.0
	assert_eq(LevelLoader.save_file(broken, "user://levels/_test_keep.json", SimConfig.CONFIG_VERSION), ERR_INVALID_DATA)
	assert_eq(_read("_test_keep.json"), before, "the earlier file is byte-for-byte unchanged")
	assert_false(FileAccess.file_exists("user://levels/_test_keep.json.tmp"))


func test_save_overwrites_an_existing_valid_file_with_new_content() -> void:
	var first: LevelDefinition = LevelFixtures.minimal_definition()
	assert_eq(LevelLoader.save_file(first, "user://levels/_test_other.json", SimConfig.CONFIG_VERSION), OK)
	var second: LevelDefinition = LevelFixtures.minimal_definition()
	second.title = "Second Version"
	assert_eq(LevelLoader.save_file(second, "user://levels/_test_other.json", SimConfig.CONFIG_VERSION), OK)
	var loaded: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_other.json", SimConfig.CONFIG_VERSION)
	assert_eq(loaded.definition.title, "Second Version")


func test_save_only_writes_inside_the_user_levels_folder() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	for path: String in ["res://levels/_test_nope.json", "user://elsewhere.json", "user://levels/../escape.json", "C:/temp/x.json"]:
		assert_eq(LevelLoader.save_file(definition, path, SimConfig.CONFIG_VERSION), ERR_INVALID_PARAMETER, path)
	assert_false(FileAccess.file_exists("res://levels/_test_nope.json"))


func test_library_rejects_bad_ids_and_mismatched_file_names() -> void:
	for bad_id: String in ["../project", "res://x", "Upper", "", "a/b"]:
		var result: LevelLoader.LoadResult = LevelLibrary.load_builtin(bad_id)
		assert_true(result.report.has_code("id.invalid"), "'%s'" % bad_id)
	# A file named test.mismatch.json that actually contains level "test.minimal".
	_write("test.mismatch.json", JSON.stringify(LevelFixtures.minimal()))
	var mismatch: LevelLoader.LoadResult = LevelLibrary.load_user("test.mismatch")
	assert_false(mismatch.is_ok(), "file name and level id must agree")
	assert_true(mismatch.report.has_code("id.file_mismatch"), mismatch.report.summary())
	assert_null(mismatch.definition)
	# The same content under its true name loads.
	_write("test.minimal.json", JSON.stringify(LevelFixtures.minimal()))
	assert_true(LevelLibrary.load_user("test.minimal").is_ok())


func _write(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(LevelLoader.USER_ROOT)
	var file: FileAccess = FileAccess.open(LevelLoader.USER_ROOT + file_name, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(LevelLoader.USER_ROOT + file_name)


func _cleanup() -> void:
	for file_name: String in TEST_FILES:
		for suffix: String in ["", ".tmp"]:
			var path: String = LevelLoader.USER_ROOT + file_name + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func test_temporary_save_files_are_not_readable_as_levels() -> void:
	assert_ne(LevelLoader.check_path("user://levels/x.json.tmp"), "")
	assert_ne(LevelLoader.check_path("res://levels/x.json.tmp"), "")
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/x.json.tmp", SimConfig.CONFIG_VERSION)
	assert_true(result.report.has_code("path.rejected"))


func test_a_file_saved_with_a_byte_order_mark_still_loads() -> void:
	_write("_test_roundtrip.json", "\uFEFF" + JSON.stringify(LevelFixtures.minimal()))
	var result: LevelLoader.LoadResult = LevelLoader.load_file("user://levels/_test_roundtrip.json", SimConfig.CONFIG_VERSION)
	assert_true(result.is_ok(), result.report.summary(3))


func test_what_save_would_write_always_loads_back() -> void:
	assert_eq(LevelLoader.to_saved_text(LevelFixtures.minimal_definition(), SimConfig.CONFIG_VERSION), LevelCodec.to_json_text(LevelFixtures.minimal_definition()))
	# Two bodies placed within 0.0004 of the legal gap at random angles. Rounding on save can
	# push some of them just inside the limit. Measured: about 4 percent of these placements are
	# valid in memory but invalid once rounded. Save must never write such a file.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	var written_ok: int = 0
	var refused_after_rounding: int = 0
	for trial: int in 1500:
		var definition: LevelDefinition = LevelFixtures.minimal_definition()
		var anchor: Vector2 = Vector2(rng.randf_range(300.0, 700.0), rng.randf_range(400.0, 500.0))
		var angle: float = rng.randf() * TAU
		definition.spawns[0].position = anchor
		definition.spawns[1].position = anchor + Vector2.from_angle(angle) * (30.0 + rng.randf_range(0.0, 0.0004))
		definition.spawns[2].position = Vector2(600.0, 100.0)
		if not LevelValidator.validate(definition, SimConfig.CONFIG_VERSION).is_ok():
			continue
		var report: ValidationReport = ValidationReport.new()
		var text: String = LevelLoader.to_saved_text(definition, SimConfig.CONFIG_VERSION, report)
		if text.is_empty():
			refused_after_rounding += 1
			assert_true(report.has_code("save.rounding"), "trial %d refused with an explanation: %s" % [trial, report.summary(3)])
		else:
			written_ok += 1
			assert_true(LevelLoader.parse_text(text, SimConfig.CONFIG_VERSION).is_ok(), "trial %d: what would be written must load" % trial)
	assert_true(written_ok > 100, "most placements save fine (%d)" % written_ok)
	assert_true(refused_after_rounding > 5, "the rounding hazard really occurs in this sample (%d), so the guard is exercised" % refused_after_rounding)
	var invalid: LevelDefinition = LevelFixtures.minimal_definition()
	invalid.pins[0].thickness = 1.0
	var invalid_report: ValidationReport = ValidationReport.new()
	assert_eq(LevelLoader.to_saved_text(invalid, SimConfig.CONFIG_VERSION, invalid_report), "", "invalid definitions produce no text")
	assert_true(invalid_report.has_code("pin.thickness"))
	assert_false(invalid_report.has_code("save.rounding"))


func test_save_file_refuses_a_rounding_hazard_and_explains_why() -> void:
	# Find one definition that is valid in memory but not after rounding, then try to save it.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	var victim: LevelDefinition = null
	for _trial: int in 1500:
		var definition: LevelDefinition = LevelFixtures.minimal_definition()
		var anchor: Vector2 = Vector2(rng.randf_range(300.0, 700.0), rng.randf_range(400.0, 500.0))
		definition.spawns[0].position = anchor
		definition.spawns[1].position = anchor + Vector2.from_angle(rng.randf() * TAU) * (30.0 + rng.randf_range(0.0, 0.0004))
		definition.spawns[2].position = Vector2(600.0, 100.0)
		if LevelValidator.validate(definition, SimConfig.CONFIG_VERSION).is_ok() and LevelLoader.to_saved_text(definition, SimConfig.CONFIG_VERSION).is_empty():
			victim = definition
			break
	assert_not_null(victim, "a hazard case exists in the sample")
	var report: ValidationReport = ValidationReport.new()
	assert_eq(LevelLoader.save_file(victim, "user://levels/_test_roundtrip.json", SimConfig.CONFIG_VERSION, report), ERR_INVALID_DATA)
	assert_true(report.has_code("save.rounding"), report.summary(3))
	assert_false(FileAccess.file_exists("user://levels/_test_roundtrip.json"), "nothing was written")
