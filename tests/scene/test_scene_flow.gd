extends SceneTestCase
## Screen flow driven through the screens' signals (see test_scene_input.gd for real input).


func test_main_scene_boots_into_menu() -> void:
	assert_not_null(app, "main scene is an AppRoot")
	assert_eq(app.current_screen, AppRoot.Screen.MENU)
	assert_true(app.current_node is MainMenu)
	assert_eq(app.get_child_count(), 1)


func test_play_opens_level_and_back_returns_to_menu() -> void:
	press(app.current_node, "PlayButton")
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_true(app.current_node is LevelScreen)

	press(app.current_node, "BackButton")
	assert_eq(app.current_screen, AppRoot.Screen.MENU)
	assert_true(app.current_node is MainMenu)
	assert_eq(app.get_child_count(), 1)


func test_restart_replaces_level_with_fresh_instance() -> void:
	press(app.current_node, "PlayButton")
	var first: LevelScreen = app.current_node as LevelScreen
	var first_id: int = first.get_instance_id()
	var baseline: int = first.board_root.get_child_count()
	assert_eq(baseline, 1, "the board view is the only child of the board root")
	first.board_root.add_child(Node2D.new())
	assert_eq(first.board_root.get_child_count(), baseline + 1)

	press(first, "RestartButton")
	await settle_frames()

	var second: LevelScreen = app.current_node as LevelScreen
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_ne(second.get_instance_id(), first_id, "restart creates a new instance")
	assert_false(is_instance_valid(instance_from_id(first_id)), "old level is freed")
	assert_eq(second.board_root.get_child_count(), baseline, "restarted level has no leftover state")
	assert_eq(app.get_child_count(), 1)


func test_screen_changed_signal_fires_once_per_transition() -> void:
	var seen: Array[int] = []
	app.screen_changed.connect(func(screen: AppRoot.Screen) -> void: seen.append(screen))
	press(app.current_node, "PlayButton")
	press(app.current_node, "RestartButton")
	press(app.current_node, "BackButton")
	assert_eq(seen, [AppRoot.Screen.LEVEL, AppRoot.Screen.LEVEL, AppRoot.Screen.MENU])


func test_repeated_transitions_do_not_accumulate_nodes() -> void:
	var baseline: int = app.get_child_count()
	var node_count_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for _i: int in 50:
		press(app.current_node, "PlayButton")
		press(app.current_node, "RestartButton")
		press(app.current_node, "BackButton")
	await settle_frames()
	assert_eq(app.current_screen, AppRoot.Screen.MENU)
	assert_eq(app.get_child_count(), baseline)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), node_count_before, "no leaked nodes")


func test_quit_button_is_wired_to_app_quit() -> void:
	# Pressing Quit would end the test process, so only the wiring is checked here.
	# Actually quitting is a manual check (docs/PROGRESS.md).
	var menu: MainMenu = app.current_node as MainMenu
	assert_true(menu.quit_requested.is_connected(app.quit_game))
	assert_true(menu.play_requested.is_connected(app.show_level))
