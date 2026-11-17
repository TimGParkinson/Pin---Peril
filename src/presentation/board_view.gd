class_name BoardView
extends Node2D
## Draws a LevelInstance's starting board in design-space coordinates.
##
## Placeholder presentation for Prompt 02: flat shapes only, with a distinct shape for each
## material so meaning does not rely on colour (token circle, scrap square, core triangle).
## It only reads the instance; it never changes it. Real art arrives in Prompt 07.

const BOARD_COLOR: Color = Color(0.96, 0.92, 0.82, 1.0)
const BOARD_EDGE_COLOR: Color = Color(0.24, 0.16, 0.08, 1.0)
const WALL_COLOR: Color = Color(0.36, 0.24, 0.14, 1.0)
const PIN_COLOR: Color = Color(0.72, 0.53, 0.18, 1.0)
const PIN_EDGE_COLOR: Color = Color(0.3, 0.2, 0.05, 1.0)
const TOKEN_COLOR: Color = Color(0.95, 0.75, 0.2, 1.0)
const SCRAP_COLOR: Color = Color(0.2, 0.2, 0.22, 1.0)
const CORE_COLOR: Color = Color(0.85, 0.2, 0.15, 1.0)
const COLLECTOR_COLOR: Color = Color(0.2, 0.6, 0.45, 0.35)
const DISPOSAL_COLOR: Color = Color(0.45, 0.45, 0.5, 0.35)
const HAZARD_COLOR: Color = Color(0.85, 0.2, 0.15, 0.3)
const LABEL_COLOR: Color = Color(0.15, 0.1, 0.05, 1.0)

var _instance: LevelInstance = null


## The instance this view draws, or null.
var instance: LevelInstance:
	get:
		return _instance


func setup(level_instance: LevelInstance) -> void:
	_instance = level_instance
	queue_redraw()


## Rectangle covered by the board in this node's local (design) coordinates.
func design_rect() -> Rect2:
	if _instance == null:
		return Rect2()
	return Rect2(Vector2.ZERO, _instance.definition.design_size)


func _draw() -> void:
	if _instance == null:
		return
	var def: LevelDefinition = _instance.definition
	var board: Rect2 = design_rect()
	draw_rect(board, BOARD_COLOR)
	draw_rect(board, BOARD_EDGE_COLOR, false, 4.0)

	for goal: LevelDefinition.Goal in def.goals:
		var color: Color = COLLECTOR_COLOR if goal.kind == LevelSchema.GOAL_COLLECTOR else DISPOSAL_COLOR
		draw_rect(goal.rect, color)
		draw_rect(goal.rect, BOARD_EDGE_COLOR, false, 3.0)
		_label(goal.rect.position + Vector2(8.0, -8.0), goal.kind.to_upper())
	for hazard: LevelDefinition.Hazard in def.hazards:
		draw_rect(hazard.rect, HAZARD_COLOR)
		draw_rect(hazard.rect, CORE_COLOR, false, 3.0)
		_label(hazard.rect.position + Vector2(8.0, -8.0), "HAZARD")

	for wall: LevelDefinition.Wall in def.walls:
		if wall.kind == LevelSchema.WALL_KIND_POLYGON:
			draw_colored_polygon(wall.points, WALL_COLOR)
		else:
			draw_polyline(wall.points, WALL_COLOR, wall.thickness)
			for point: Vector2 in wall.points:
				draw_circle(point, wall.thickness * 0.5, WALL_COLOR)

	for pin: LevelDefinition.Pin in def.pins:
		draw_line(pin.tip, pin.handle, PIN_EDGE_COLOR, pin.thickness + 4.0)
		draw_line(pin.tip, pin.handle, PIN_COLOR, pin.thickness)
		draw_circle(pin.handle, pin.thickness * 1.2, PIN_COLOR)
		draw_arc(pin.handle, pin.thickness * 1.2, 0.0, TAU, 24, PIN_EDGE_COLOR, 3.0)
		_label(pin.handle + Vector2(-8.0, -pin.thickness * 2.0), pin.id.get_slice(".", 1).to_upper())

	for state: LevelInstance.MaterialState in _instance.materials:
		_draw_material(state)


func _draw_material(state: LevelInstance.MaterialState) -> void:
	var center: Vector2 = state.position
	var radius: float = state.radius
	match state.kind:
		LevelSchema.MATERIAL_SCRAP:
			var box: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			draw_rect(box, SCRAP_COLOR)
			draw_rect(box, BOARD_EDGE_COLOR, false, 2.0)
		LevelSchema.MATERIAL_CORE:
			var triangle: PackedVector2Array = PackedVector2Array([
				center + Vector2(0.0, -radius), center + Vector2(radius, radius), center + Vector2(-radius, radius),
			])
			draw_colored_polygon(triangle, CORE_COLOR)
			draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), BOARD_EDGE_COLOR, 2.0)
		_:
			draw_circle(center, radius, TOKEN_COLOR)
			draw_arc(center, radius, 0.0, TAU, 24, BOARD_EDGE_COLOR, 2.0)


func _label(at: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, LABEL_COLOR)
