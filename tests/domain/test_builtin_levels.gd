extends TestCase
## Every shipped level must load, validate and stay what it was.

## Geometry hash of workshop.three_pins. If this fails after an intentional edit of the level,
## inspect the difference, then update the constant deliberately and re-run physics
## validation once it exists (Prompt 16). Do not just paste in the new value.
const THREE_PINS_GEOMETRY_HASH: String = "69c3fb5fe7ca8986f41133d2fef76f42302095bfb857c21c1b0959a241028f90"


func test_at_least_one_builtin_level_exists_and_all_of_them_load() -> void:
	var ids: PackedStringArray = LevelLibrary.list_builtin_ids()
	assert_true(ids.size() >= 1, "no built-in levels found in res://levels")
	assert_true(ids.has(LevelLibrary.DEFAULT_LEVEL_ID))
	for level_id: String in ids:
		var result: LevelLoader.LoadResult = LevelLibrary.load_builtin(level_id)
		assert_true(result.is_ok(), "%s: %s" % [level_id, result.report.summary()])
		if result.is_ok():
			assert_eq(result.definition.level_id, level_id, "file name equals level id")
			assert_not_null(LevelInstance.create(result.definition), "%s can be instantiated" % level_id)


func test_builtin_files_are_in_canonical_form_so_diffs_stay_small() -> void:
	for level_id: String in LevelLibrary.list_builtin_ids():
		var path: String = LevelLoader.BUILTIN_ROOT + level_id + LevelLoader.EXTENSION
		var on_disk: String = FileAccess.get_file_as_string(path)
		var definition: LevelDefinition = LevelLibrary.load_builtin(level_id).definition
		# A Windows checkout may convert line endings; they are not part of the content.
		assert_eq(LevelCodec.to_json_text(definition), on_disk.replace("\r\n", "\n"), "%s is saved canonically; re-save it through LevelCodec" % level_id)


func test_three_pin_level_has_the_expected_shape() -> void:
	var result: LevelLoader.LoadResult = LevelLibrary.load_builtin("workshop.three_pins")
	assert_true(result.is_ok(), result.report.summary())
	var definition: LevelDefinition = result.definition
	assert_eq(definition.pins.size(), 3)
	assert_eq(definition.count_spawns("token"), 5)
	assert_eq(definition.count_spawns("scrap"), 2)
	assert_eq(definition.objective.required_tokens, 5)
	assert_eq(definition.objective.allowed_token_losses, 0, "default: collect every token")
	assert_eq(definition.sim_config_version, SimConfig.CONFIG_VERSION)
	assert_eq(definition.meta.source, "handcrafted")
	assert_eq(definition.design_size, Vector2(1600.0, 900.0))
	assert_true(definition.known_sequences.is_empty(), "no solutions are claimed before real physics replay exists")
	for pin: LevelDefinition.Pin in definition.pins:
		assert_true(pin.pull_distance >= pin.tip.distance_to(pin.handle) - 0.001, "%s clears its own length" % pin.id)


func test_three_pin_geometry_has_not_changed_unnoticed() -> void:
	var definition: LevelDefinition = LevelLibrary.load_builtin("workshop.three_pins").definition
	assert_eq(definition.geometry_hash(), THREE_PINS_GEOMETRY_HASH)


func test_every_spawn_in_the_three_pin_level_is_clear_with_margin() -> void:
	# Stronger than validation: leave at least one extra unit beyond the legal gap.
	var definition: LevelDefinition = LevelLibrary.load_builtin("workshop.three_pins").definition
	for first_index: int in definition.spawns.size():
		for second_index: int in range(first_index + 1, definition.spawns.size()):
			var first: LevelDefinition.Spawn = definition.spawns[first_index]
			var second: LevelDefinition.Spawn = definition.spawns[second_index]
			var needed: float = (LevelSchema.MATERIAL_RADIUS[first.material] as float) + (LevelSchema.MATERIAL_RADIUS[second.material] as float) + LevelSchema.SPAWN_GAP
			assert_true(first.position.distance_to(second.position) >= needed, "%s and %s" % [first.id, second.id])
