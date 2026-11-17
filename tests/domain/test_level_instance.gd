extends TestCase
## Definitions are separate from runtime instances, and every instance starts identically.


func test_instance_is_built_from_the_definition() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var report: ValidationReport = ValidationReport.new()
	var instance: LevelInstance = LevelInstance.create(definition, report)
	assert_not_null(instance, report.summary())
	assert_true(report.is_ok())
	assert_eq(instance.materials.size(), 5)
	assert_eq(instance.pins.size(), 2)
	for index: int in instance.materials.size():
		var state: LevelInstance.MaterialState = instance.materials[index]
		var spawn: LevelDefinition.Spawn = definition.spawns[index]
		assert_eq(state.id, spawn.id)
		assert_eq(state.kind, spawn.material)
		assert_eq(state.position, spawn.position, "explicit spawn position is used, never randomised")
		assert_eq(state.radius, LevelSchema.MATERIAL_RADIUS[spawn.material] as float)
		assert_eq(state.status, LevelInstance.MaterialStatus.ACTIVE)
	for pin_state: LevelInstance.PinState in instance.pins:
		assert_false(pin_state.pulled)
	assert_eq(instance.geometry_signature(), definition.geometry_signature())


func test_invalid_definitions_are_never_instantiated() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	definition.spawns[1].position = definition.spawns[0].position  # exact overlap
	definition.pins[0].id = definition.pins[1].id  # duplicate id
	var report: ValidationReport = ValidationReport.new()
	var instance: LevelInstance = LevelInstance.create(definition, report)
	assert_null(instance)
	assert_true(report.has_code("spawn.overlap"))
	assert_true(report.has_code("id.duplicate"))


func test_a_definition_for_another_sim_version_is_not_instantiated() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	definition.sim_config_version = SimConfig.CONFIG_VERSION + 1
	var report: ValidationReport = ValidationReport.new()
	assert_null(LevelInstance.create(definition, report))
	assert_true(report.has_code("sim.version_mismatch"))


func test_creating_an_instance_does_not_change_the_definition() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var before: String = LevelCodec.to_json_text(definition)
	var instance: LevelInstance = LevelInstance.create(definition)
	assert_not_null(instance)
	assert_eq(LevelCodec.to_json_text(definition), before)


func test_changing_an_instance_never_changes_its_source_or_later_instances() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var source_signature: String = definition.geometry_signature()

	var first: LevelInstance = LevelInstance.create(definition)
	var initial: String = first.initial_state_signature
	assert_eq(first.state_signature(), initial)

	# Play damage: move bodies, resolve one, pull a pin, even corrupt the instance's own geometry.
	first.materials[0].position += Vector2(300.0, 200.0)
	first.materials[1].status = LevelInstance.MaterialStatus.COLLECTED
	first.pins[0].pulled = true
	first.definition.walls[0].points[0] = Vector2(5.0, 5.0)
	first.definition.spawns[2].position.x += 77.0
	assert_ne(first.state_signature(), initial, "the state signature notices play changes")

	assert_eq(definition.geometry_signature(), source_signature, "source definition untouched")

	# Restart: a brand new instance from the same definition.
	var second: LevelInstance = LevelInstance.create(definition)
	assert_not_null(second)
	assert_false(second == first, "a different object")
	assert_ne(second.get_instance_id(), first.get_instance_id())
	assert_eq(second.state_signature(), initial, "identical initial state after restart")
	assert_eq(second.initial_state_signature, initial)
	assert_eq(second.geometry_signature(), source_signature, "identical initial geometry after restart")
	assert_eq(second.materials[0].position, definition.spawns[0].position)
	assert_eq(second.materials[1].status, LevelInstance.MaterialStatus.ACTIVE)
	assert_false(second.pins[0].pulled)


func test_many_restarts_always_start_the_same() -> void:
	var definition: LevelDefinition = LevelFixtures.minimal_definition()
	var expected: String = LevelInstance.create(definition).initial_state_signature
	for _i: int in 50:
		var instance: LevelInstance = LevelInstance.create(definition)
		instance.materials[0].position.y += 1.0
		instance.pins[1].pulled = true
		var restarted: LevelInstance = LevelInstance.create(definition)
		assert_eq(restarted.state_signature(), expected)


func test_lookup_helpers_find_objects_by_stable_id() -> void:
	var instance: LevelInstance = LevelInstance.create(LevelFixtures.minimal_definition())
	assert_eq(instance.find_material("scrap.1").kind, "scrap")
	assert_null(instance.find_material("scrap.9"))
	assert_eq(instance.find_pin_state("pin.two").id, "pin.two")
	assert_null(instance.find_pin_state("pin.nope"))
