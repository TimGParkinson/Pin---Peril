extends TestCase
## Guards project settings that gameplay and validation depend on.


func test_physics_tick_rate_matches_sim_config() -> void:
	var configured: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second") as int
	assert_eq(configured, SimConfig.TICK_RATE)


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")


func test_design_viewport_matches_ui_metrics() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width") as int, UiMetrics.DESIGN_SIZE.x)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height") as int, UiMetrics.DESIGN_SIZE.y)


func test_stretch_scales_ui_and_landscape_is_wider_than_tall() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_true(UiMetrics.DESIGN_SIZE.x > UiMetrics.DESIGN_SIZE.y, "design space is landscape")


func test_untyped_declarations_are_errors() -> void:
	# 2 = error. Keeps all GDScript explicitly typed.
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration") as int, 2)
