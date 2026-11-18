extends SceneTestCase
## The level screen runs the real physics world, shows its tokens, offers the debug overlay, and
## tears everything down on restart and Back. Physics claims themselves live in tests/physics;
## this file is about the wiring on the real screen.


func _open_level() -> LevelScreen:
	await click(find_button(app.current_node, "PlayButton"))
	return app.current_node as LevelScreen


func _wait_physics_ticks(count: int) -> void:
	for _i: int in count:
		await tree.physics_frame


func test_the_level_screen_runs_a_live_world_built_from_its_instance() -> void:
	var level: LevelScreen = await _open_level()
	assert_not_null(level.world)
	assert_eq(level.world.instance, level.instance, "the world simulates this screen's own instance")
	assert_eq(level.world.get_parent(), level)
	assert_true(level.world.top_level, "physics space is design space, whatever the board scale")
	assert_eq(level.world.global_position, Vector2.ZERO)
	assert_eq(level.world.token_count(), 5)
	assert_eq(level.world.static_parts().size(), 4 + 3, "4 walls and 3 pins")
	assert_eq(level.board_view.world, level.world)
	assert_eq(level.board_root.get_child_count(), 1, "still exactly one board view")


func test_token_visuals_follow_their_physics_bodies() -> void:
	var level: LevelScreen = await _open_level()
	await _wait_physics_ticks(30)
	var checked: int = 0
	for body: TokenBody in level.world.tokens():
		var visual: TokenVisual = level.board_view.token_visual(body.material_id)
		assert_not_null(visual, body.material_id)
		var tolerance: float = body.linear_velocity.length() * SimConfig.TICK_DELTA + 0.5
		assert_true(visual.position.distance_to(body.position) <= tolerance, "%s visual %s body %s" % [body.material_id, visual.position, body.position])
		assert_eq(visual.radius, LevelSchema.MATERIAL_RADIUS[LevelSchema.MATERIAL_TOKEN] as float)
		checked += 1
	assert_eq(checked, 5)
	assert_eq(level.board_view.get_child_count(), 5 + 1, "five token visuals and the overlay")
	assert_null(level.board_view.token_visual("token.99"))


func test_the_tokens_really_start_at_the_authored_positions_after_a_restart() -> void:
	var first: LevelScreen = await _open_level()
	var ticks_before: int = first.world.tick_count
	await _wait_physics_ticks(120)
	# physics_frame fires just before a tick's node processing, so allow one tick of slack.
	assert_true(first.world.tick_count - ticks_before >= 119, "the first world ran for %d ticks" % (first.world.tick_count - ticks_before))
	await click(find_button(first, "RestartButton"))
	var second: LevelScreen = app.current_node as LevelScreen
	assert_true(second.world.tick_count <= 30, "a fresh world, not the 120 tick old one (%d ticks old)" % second.world.tick_count)
	var bound: float = 0.5 * SimConfig.GRAVITY * pow(float(second.world.tick_count + 1) * SimConfig.TICK_DELTA, 2.0) + 1.0
	for spawn: LevelDefinition.Spawn in second.level_definition.spawns:
		var body: TokenBody = second.world.token_body(spawn.id)
		if body == null:
			continue  # scrap is not simulated yet
		assert_true(body.position.distance_to(spawn.position) <= bound, "%s starts at its authored position (moved %.1f)" % [spawn.id, body.position.distance_to(spawn.position)])


func test_back_and_restart_free_the_world_and_every_body() -> void:
	var level: LevelScreen = await _open_level()
	var world_id: int = level.world.get_instance_id()
	var body_id: int = level.world.tokens()[0].get_instance_id()
	var visual_id: int = level.board_view.token_visual("token.1").get_instance_id()
	await click(find_button(level, "RestartButton"))
	assert_false(is_instance_valid(instance_from_id(world_id)), "the old world is freed on restart")
	assert_false(is_instance_valid(instance_from_id(body_id)), "and its bodies")
	assert_false(is_instance_valid(instance_from_id(visual_id)), "and the old visuals")
	var second: LevelScreen = app.current_node as LevelScreen
	assert_ne(second.world.get_instance_id(), world_id)
	var second_world_id: int = second.world.get_instance_id()
	await click(find_button(second, "BackButton"))
	assert_false(is_instance_valid(instance_from_id(second_world_id)), "and on Back")


func test_debug_overlay_is_off_by_default_and_f_keys_toggle_each_layer() -> void:
	assert_true(OS.is_debug_build(), "these tests run on a debug build")
	var level: LevelScreen = await _open_level()
	var overlay: PhysicsDebugOverlay = level.debug_overlay
	assert_not_null(overlay)
	assert_false(overlay.any_layer_on(), "nothing is drawn by default")
	var keys: Dictionary = {
		KEY_F2: PhysicsDebugOverlay.Layer.SHAPES,
		KEY_F3: PhysicsDebugOverlay.Layer.IDS,
		KEY_F4: PhysicsDebugOverlay.Layer.VELOCITIES,
		KEY_F5: PhysicsDebugOverlay.Layer.STATS,
	}
	for keycode: int in keys.keys():
		var layer: PhysicsDebugOverlay.Layer = keys[keycode] as PhysicsDebugOverlay.Layer
		await send_key(keycode as Key)
		assert_true(overlay.is_layer_on(layer), "key %s turns its layer on" % OS.get_keycode_string(keycode as Key))
		for other: int in keys.keys():
			if other != keycode:
				assert_false(overlay.is_layer_on(keys[other] as PhysicsDebugOverlay.Layer), "only that layer")
		await send_key(keycode as Key)
		assert_false(overlay.is_layer_on(layer), "the same key turns it off again")
	assert_false(overlay.any_layer_on())


func test_the_overlay_draws_every_physics_shape_with_all_layers_on() -> void:
	var level: LevelScreen = await _open_level()
	var overlay: PhysicsDebugOverlay = level.debug_overlay
	var expected: int = 0
	for part: StaticPartBody in level.world.static_parts():
		expected += part.get_child_count()
	for body: TokenBody in level.world.tokens():
		expected += body.get_child_count()
	assert_true(expected >= 10, "the level has %d collision shapes" % expected)
	assert_eq(overlay.shape_count(), expected, "the overlay draws the shapes the physics engine holds")
	for layer: PhysicsDebugOverlay.Layer in [PhysicsDebugOverlay.Layer.SHAPES, PhysicsDebugOverlay.Layer.IDS, PhysicsDebugOverlay.Layer.VELOCITIES, PhysicsDebugOverlay.Layer.STATS]:
		overlay.set_layer(layer, true)
	await _wait_physics_ticks(20)
	await settle_frames()
	assert_true(overlay.any_layer_on())
	assert_eq(level.world.tick_count >= 20, true, "the world keeps running with the overlay on")


func test_the_debug_overlay_never_changes_the_simulation() -> void:
	# The same level with and without every overlay layer must reach the same state.
	var plain: LevelScreen = await _open_level()
	await _wait_physics_ticks(60)
	var plain_ticks: int = plain.world.tick_count
	var plain_state: String = plain.world.state_signature()
	await click(find_button(plain, "RestartButton"))
	var shown: LevelScreen = app.current_node as LevelScreen
	for layer: PhysicsDebugOverlay.Layer in [PhysicsDebugOverlay.Layer.SHAPES, PhysicsDebugOverlay.Layer.IDS, PhysicsDebugOverlay.Layer.VELOCITIES, PhysicsDebugOverlay.Layer.STATS]:
		shown.debug_overlay.set_layer(layer, true)
	while shown.world.tick_count < plain_ticks:
		await tree.physics_frame
	# Both worlds are compared at the same tick count.
	assert_eq(shown.world.tick_count, plain_ticks)
	assert_eq(shown.world.state_signature(), plain_state, "overlays are read-only")


func test_a_changed_project_physics_setting_stops_the_level_from_starting_quietly() -> void:
	var original: Variant = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 3000.0)
	var level: LevelScreen = await _open_level()
	ProjectSettings.set_setting("physics/2d/default_gravity", original)
	var message: String = (level.get_node("%PlaceholderLabel") as Label).text
	assert_null(level.world, "no world is built on settings that differ from SimConfig")
	assert_null(level.board_view)
	assert_null(level.instance)
	assert_true(message.begins_with("Physics could not start"), message)
	assert_true(message.contains("default_gravity"), message)
	var area: Rect2 = (level.get_node("%BoardArea") as Control).get_global_rect()
	assert_true(area.grow(0.5).encloses((level.get_node("%PlaceholderLabel") as Label).get_global_rect()), "the message stays inside the board area")


func test_the_play_button_can_open_another_built_in_level_in_debug_builds() -> void:
	var args: PackedStringArray = PackedStringArray(["--suite=scene", "--level=dev.physics_lab", "--other"])
	assert_eq(AppRoot.level_id_from_arguments(args, true), "dev.physics_lab")
	assert_eq(AppRoot.level_id_from_arguments(args, false), LevelLibrary.DEFAULT_LEVEL_ID, "release builds ignore it")
	assert_eq(AppRoot.level_id_from_arguments(PackedStringArray(["--suite=scene"]), true), LevelLibrary.DEFAULT_LEVEL_ID)
	assert_eq(AppRoot.level_id_from_arguments(PackedStringArray(), true), LevelLibrary.DEFAULT_LEVEL_ID)
	assert_eq(AppRoot.level_id_from_arguments(PackedStringArray(["--level="]), true), "", "an empty id is passed on and shows the normal load problem")
