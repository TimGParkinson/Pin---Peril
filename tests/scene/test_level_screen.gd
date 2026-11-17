extends SceneTestCase
## The level screen builds its board from data, restarts from fresh state, and fits the window.

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1600, 1200), Vector2i(3840, 2160),
]


func _open_level() -> LevelScreen:
	await click(find_button(app.current_node, "PlayButton"))
	return app.current_node as LevelScreen


func test_play_loads_the_default_level_from_data() -> void:
	var level: LevelScreen = await _open_level()
	assert_not_null(level.level_definition)
	assert_eq(level.level_definition.level_id, LevelLibrary.DEFAULT_LEVEL_ID)
	assert_not_null(level.instance, "a runtime instance was created")
	assert_not_null(level.board_view, "a board view was created")
	assert_eq(level.board_view.instance, level.instance)
	assert_eq(level.instance.materials.size(), 7)
	assert_eq(level.instance.pins.size(), 3)
	assert_eq((level.get_node("%TitleLabel") as Label).text, "Three Pins Test Chamber")
	assert_false((level.get_node("%PlaceholderLabel") as Label).visible, "no placeholder or error text")
	assert_eq(level.load_problem, "")


func test_restart_builds_a_fresh_instance_with_identical_starting_geometry() -> void:
	var first: LevelScreen = await _open_level()
	var first_instance: LevelInstance = first.instance
	var geometry: String = first_instance.geometry_signature()
	var initial_state: String = first_instance.initial_state_signature
	var source_signature: String = first.level_definition.geometry_signature()
	var first_screen_id: int = first.get_instance_id()
	var first_view_id: int = first.board_view.get_instance_id()

	# Wreck the first attempt thoroughly.
	first_instance.materials[0].position += Vector2(500.0, 400.0)
	first_instance.materials[3].status = LevelInstance.MaterialStatus.LOST
	first_instance.pins[1].pulled = true
	first_instance.definition.walls[1].points[0] = Vector2(9.0, 9.0)

	await click(find_button(first, "RestartButton"))
	var second: LevelScreen = app.current_node as LevelScreen
	assert_ne(second.get_instance_id(), first_screen_id, "a new screen")
	assert_ne(second.instance, first_instance, "a new runtime instance")
	assert_ne(second.board_view.get_instance_id(), first_view_id, "a new board view")
	assert_false(is_instance_valid(instance_from_id(first_screen_id)), "the old screen is freed")
	assert_eq(second.instance.state_signature(), initial_state, "identical initial state")
	assert_eq(second.instance.geometry_signature(), geometry, "identical initial geometry")
	assert_eq(second.level_definition.geometry_signature(), source_signature, "the shared definition was never modified")
	assert_eq(second.board_view.design_rect(), Rect2(0.0, 0.0, 1600.0, 900.0))


func test_leaving_and_replaying_gives_the_same_starting_level() -> void:
	var first: LevelScreen = await _open_level()
	var geometry: String = first.instance.geometry_signature()
	var state: String = first.instance.initial_state_signature
	var first_hash: String = first.level_definition.geometry_hash()
	await click(find_button(first, "BackButton"))
	assert_eq(app.current_screen, AppRoot.Screen.MENU)
	var second: LevelScreen = await _open_level()
	assert_eq(second.instance.geometry_signature(), geometry)
	assert_eq(second.instance.state_signature(), state)
	assert_eq(second.level_definition.geometry_hash(), first_hash)


func test_many_restarts_never_accumulate_boards_or_change_the_start() -> void:
	var level: LevelScreen = await _open_level()
	var geometry: String = level.instance.geometry_signature()
	var state: String = level.instance.initial_state_signature
	for _i: int in 20:
		level.instance.materials[0].position.x += 10.0
		await click(find_button(level, "RestartButton"))
		level = app.current_node as LevelScreen
		assert_eq(level.board_root.get_child_count(), 1, "exactly one board view")
		assert_eq(level.instance.geometry_signature(), geometry)
		assert_eq(level.instance.state_signature(), state)
	assert_eq(app.get_child_count(), 1)


func test_the_board_fits_inside_the_board_area_at_every_window_size() -> void:
	for window_size: Vector2i in WINDOW_SIZES:
		await set_window_size(window_size)
		var level: LevelScreen = await _open_level()
		var area: Rect2 = (level.get_node("%BoardArea") as Control).get_global_rect()
		var board: Rect2 = level.board_root.get_global_transform() * level.board_view.design_rect()
		var label: String = "at %s" % window_size
		assert_true(area.grow(0.5).encloses(board), "board %s inside area %s %s" % [board, area, label])
		assert_true(tree.root.get_visible_rect().encloses(board), "board inside the window " + label)
		assert_true(board.size.x > area.size.x * 0.5 or board.size.y > area.size.y * 0.5, "board is not tiny " + label)
		assert_almost_eq(board.size.x / board.size.y, 1600.0 / 900.0, 0.001, "aspect ratio preserved " + label)
		assert_almost_eq(board.get_center().x, area.get_center().x, 1.0, "centred horizontally " + label)
		assert_almost_eq(board.get_center().y, area.get_center().y, 1.0, "centred vertically " + label)
		var back: Rect2 = find_button(level, "BackButton").get_global_rect()
		var restart: Rect2 = find_button(level, "RestartButton").get_global_rect()
		assert_false(board.intersects(back), "board does not cover Back " + label)
		assert_false(board.intersects(restart), "board does not cover Restart " + label)
		await click(find_button(level, "BackButton"))


func test_the_board_never_blocks_clicks_on_the_hud() -> void:
	var level: LevelScreen = await _open_level()
	var level_id: int = level.get_instance_id()
	await click(find_button(level, "RestartButton"))
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_ne(app.current_node.get_instance_id(), level_id, "Restart still works with a board on screen")


func test_a_missing_level_shows_a_message_instead_of_crashing() -> void:
	var level: LevelScreen = (load("res://scenes/level/level_screen.tscn") as PackedScene).instantiate() as LevelScreen
	level.load_problem = "Could not load level: test problem"
	tree.root.add_child(level)
	await settle_frames()
	assert_null(level.instance)
	assert_null(level.board_view)
	assert_eq((level.get_node("%PlaceholderLabel") as Label).text, "Could not load level: test problem")
	tree.root.remove_child(level)
	level.free()


func test_an_invalid_definition_shows_the_problems_and_builds_no_board() -> void:
	var level: LevelScreen = (load("res://scenes/level/level_screen.tscn") as PackedScene).instantiate() as LevelScreen
	var broken: LevelDefinition = LevelFixtures.minimal_definition()
	broken.pins[0].thickness = 1.0
	level.level_definition = broken
	tree.root.add_child(level)
	await settle_frames()
	assert_null(level.instance, "invalid data is never instantiated")
	assert_null(level.board_view)
	assert_true((level.get_node("%PlaceholderLabel") as Label).text.contains("pin.thickness"))
	tree.root.remove_child(level)
	level.free()
