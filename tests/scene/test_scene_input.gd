extends SceneTestCase
## Real input and real layout. Events go through the viewport input pipeline and the
## checks use laid-out rectangles, at several window sizes and aspect ratios.

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(1600, 1200),
	Vector2i(3840, 2160),
]


func test_mouse_clicks_drive_the_whole_flow() -> void:
	await click(find_button(app.current_node, "PlayButton"))
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)

	var first_id: int = app.current_node.get_instance_id()
	await click(find_button(app.current_node, "RestartButton"))
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_ne(app.current_node.get_instance_id(), first_id, "restart click made a fresh level")

	await click(find_button(app.current_node, "BackButton"))
	assert_eq(app.current_screen, AppRoot.Screen.MENU)
	assert_eq(app.get_child_count(), 1)


func test_mouse_flow_works_at_every_window_size() -> void:
	for window_size: Vector2i in WINDOW_SIZES:
		await set_window_size(window_size)
		await click(find_button(app.current_node, "PlayButton"))
		assert_eq(app.current_screen, AppRoot.Screen.LEVEL, "Play clickable at %s" % window_size)
		await click(find_button(app.current_node, "BackButton"))
		assert_eq(app.current_screen, AppRoot.Screen.MENU, "Back clickable at %s" % window_size)


func test_clicks_outside_buttons_do_nothing() -> void:
	await click_at(Vector2(5.0, 5.0))
	assert_eq(app.current_screen, AppRoot.Screen.MENU)

	await click(find_button(app.current_node, "PlayButton"))
	var level_id: int = app.current_node.get_instance_id()
	var board_center: Vector2 = Vector2(UiMetrics.DESIGN_SIZE) / 2.0
	await click_at(board_center)
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_eq(app.current_node.get_instance_id(), level_id, "empty board click must not restart or leave")


func test_double_click_on_play_keeps_exactly_one_level() -> void:
	var play: Button = find_button(app.current_node, "PlayButton")
	var position: Vector2 = play.get_global_rect().get_center()
	# Two clicks in the same frame, before layout of the new screen has settled.
	for _i: int in 2:
		for is_pressed: bool in [true, false]:
			var event: InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = is_pressed
			event.position = position
			event.global_position = position
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_pressed else 0
			tree.root.push_input(event, true)
	await settle_frames()
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	assert_eq(app.get_child_count(), 1)


func test_escape_goes_back_from_level_only() -> void:
	await send_key(KEY_ESCAPE)
	assert_eq(app.current_screen, AppRoot.Screen.MENU, "Esc on the menu does nothing")
	assert_true(app.current_node is MainMenu)

	await click(find_button(app.current_node, "PlayButton"))
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL)
	await send_key(KEY_ESCAPE)
	assert_eq(app.current_screen, AppRoot.Screen.MENU, "Esc on the level returns to the menu")
	assert_eq(app.get_child_count(), 1)


func test_menu_is_keyboard_operable() -> void:
	var play: Button = find_button(app.current_node, "PlayButton")
	assert_true(play.has_focus(), "Play has initial focus")
	await send_key(KEY_ENTER)
	assert_eq(app.current_screen, AppRoot.Screen.LEVEL, "Enter activates the focused button")


func test_hit_areas_meet_minimum_in_design_units_at_every_window_size() -> void:
	for window_size: Vector2i in WINDOW_SIZES:
		await set_window_size(window_size)
		for button: Button in _all_buttons():
			var rect: Rect2 = button.get_global_rect()
			assert_true(
				rect.size.x >= UiMetrics.MIN_HIT_SIZE.x and rect.size.y >= UiMetrics.MIN_HIT_SIZE.y,
				"%s is %s at %s" % [button.name, rect.size, window_size]
			)
		await click(find_button(app.current_node, "PlayButton"))
		for button: Button in _all_buttons():
			var rect: Rect2 = button.get_global_rect()
			assert_true(
				rect.size.x >= UiMetrics.MIN_HIT_SIZE.x and rect.size.y >= UiMetrics.MIN_HIT_SIZE.y,
				"%s is %s at %s" % [button.name, rect.size, window_size]
			)
		await click(find_button(app.current_node, "BackButton"))


func test_layout_stays_on_screen_and_centred_at_every_window_size() -> void:
	for window_size: Vector2i in WINDOW_SIZES:
		await set_window_size(window_size)
		var visible: Rect2 = tree.root.get_visible_rect()
		var label: String = "at %s (visible %s)" % [window_size, visible.size]
		assert_true(visible.size.x >= float(UiMetrics.DESIGN_SIZE.x) - 0.5, "design width never cropped " + label)
		assert_true(visible.size.y >= float(UiMetrics.DESIGN_SIZE.y) - 0.5, "design height never cropped " + label)

		for button: Button in _all_buttons():
			assert_true(visible.encloses(button.get_global_rect()), "menu %s inside window %s" % [button.name, label])
			assert_almost_eq(button.get_global_rect().get_center().x, visible.get_center().x, 2.0, "menu %s centred %s" % [button.name, label])

		await click(find_button(app.current_node, "PlayButton"))
		var back: Rect2 = find_button(app.current_node, "BackButton").get_global_rect()
		var restart: Rect2 = find_button(app.current_node, "RestartButton").get_global_rect()
		assert_true(visible.encloses(back), "Back inside window " + label)
		assert_true(visible.encloses(restart), "Restart inside window " + label)
		assert_false(back.intersects(restart), "Back and Restart do not overlap " + label)
		assert_true(back.end.x < restart.position.x, "Back is left of Restart " + label)
		await click(find_button(app.current_node, "BackButton"))


func test_focus_ring_is_thick_two_tone_and_applied_to_every_button() -> void:
	var theme: Theme = load(ProjectSettings.get_setting("gui/theme/custom") as String) as Theme
	assert_not_null(theme, "project theme loads")
	var ring: StyleBoxFlat = theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	assert_not_null(ring, "theme defines a StyleBoxFlat focus ring for Button")
	assert_false(ring.draw_center, "ring must not cover the button label")
	for width: int in [ring.border_width_left, ring.border_width_top, ring.border_width_right, ring.border_width_bottom]:
		assert_true(width >= UiMetrics.MIN_FOCUS_RING_WIDTH, "ring width %d >= %d" % [width, UiMetrics.MIN_FOCUS_RING_WIDTH])
	assert_eq(ring.border_color.a, 1.0, "ring colour is opaque")
	# One colour cannot contrast with both the cream and the teal backgrounds, so the ring
	# needs a dark outer edge (shadow) as well as the bright border.
	assert_true(ring.shadow_size > 0 and ring.shadow_color.a >= 0.5, "ring has a strong dark outer edge")

	for button: Button in _all_buttons():
		assert_true(button.get_theme_stylebox(&"focus") == ring, "menu %s uses the theme focus ring" % button.name)
	await click(find_button(app.current_node, "PlayButton"))
	for button: Button in _all_buttons():
		assert_true(button.get_theme_stylebox(&"focus") == ring, "level %s uses the theme focus ring" % button.name)


func _all_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in app.current_node.find_children("*", "Button", true, false):
		result.append(node as Button)
	return result
