class_name SceneTestCase
extends TestCase
## Base for scene tests. Boots a fresh AppRoot at an explicit window size before each test.
##
## The headless root window defaults to 64x64, which distorts layout, so every scene test
## runs at a known size (the design size unless a test changes it).

var app: AppRoot = null
var _saved_window_size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_saved_window_size = tree.root.size
	tree.root.size = UiMetrics.DESIGN_SIZE
	var main_scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene") as String) as PackedScene
	app = main_scene.instantiate() as AppRoot
	tree.root.add_child(app)
	await settle_frames()


func after_each() -> void:
	if app != null:
		tree.root.remove_child(app)
		app.free()
		app = null
	tree.root.size = _saved_window_size
	await settle_frames()


## Waits two frames so queued frees and container layout have completed.
func settle_frames() -> void:
	await tree.process_frame
	await tree.process_frame


func set_window_size(window_size: Vector2i) -> void:
	tree.root.size = window_size
	await settle_frames()


func find_button(screen: Node, button_name: String) -> Button:
	var button: Button = screen.find_child(button_name, true, false) as Button
	assert_not_null(button, "button %s exists" % button_name)
	return button


## Emits the button's pressed signal directly (bypasses input routing).
func press(screen: Node, button_name: String) -> void:
	find_button(screen, button_name).pressed.emit()


## Sends a real left mouse click at a control's center through the viewport input pipeline.
func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())


func click_at(position: Vector2) -> void:
	for is_pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = position
		event.global_position = position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_pressed else 0
		tree.root.push_input(event, true)
	await settle_frames()


## Sends a real key press and release through the viewport pipeline. Key events (not
## InputEventAction) are what Godot routes to the focused control.
func send_key(keycode: Key) -> void:
	for is_pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = is_pressed
		tree.root.push_input(event)
	await settle_frames()
