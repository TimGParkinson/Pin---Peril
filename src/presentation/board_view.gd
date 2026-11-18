class_name BoardView
extends Node2D
## Draws a LevelInstance's board in design-space coordinates and shows the live tokens.
##
## Placeholder presentation: flat shapes only, with a distinct shape for each material so
## meaning does not rely on colour (token circle, scrap square, core triangle). Everything
## drawn here for walls and pins has exactly the outline of its collision shape (see
## BoardColliders), so the picture is the physical boundary. Outlines are drawn inside that
## boundary, never outside it. Once a SimWorld is attached, each token is a TokenVisual that
## follows its physics body; the view only reads the world and never changes it. Scrap and
## cores are not simulated yet and are drawn at their starting positions. Real art arrives in
## Prompt 07.

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
var _world: SimWorld = null
var _visuals: Array[TokenVisual] = []
var _bodies: Array[TokenBody] = []


## The instance this view draws, or null.
var instance: LevelInstance:
	get:
		return _instance


## The physics world whose tokens this view follows, or null.
var world: SimWorld:
	get:
		return _world


func setup(level_instance: LevelInstance) -> void:
	_instance = level_instance
	queue_redraw()


## Shows the world's tokens, each following its body. Call once, after setup.
func attach_world(sim_world: SimWorld) -> void:
	_world = sim_world
	for body: TokenBody in sim_world.tokens():
		var visual: TokenVisual = TokenVisual.new()
		visual.name = "Token_%s" % body.material_id.replace(".", "_")
		visual.radius = _instance.find_material(body.material_id).radius
		visual.position = body.position
		add_child(visual)
		visual.reset_physics_interpolation()
		_visuals.append(visual)
		_bodies.append(body)
	queue_redraw()


## The visual that follows a token, or null.
func token_visual(material_id: String) -> TokenVisual:
	for index: int in _bodies.size():
		if _bodies[index].material_id == material_id:
			return _visuals[index]
	return null


func _physics_process(_delta: float) -> void:
	# Copy body transforms once per tick; the engine's physics interpolation smooths the
	# movement between ticks for displays that do not run at exactly 60 Hz.
	for index: int in _bodies.size():
		if is_instance_valid(_bodies[index]):
			_visuals[index].position = _bodies[index].position
			_visuals[index].rotation = _bodies[index].rotation


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
			# One flat rectangle per segment plus a disc at every point is exactly the union of
			# the collision capsules. draw_polyline would add miter spikes at sharp joints that
			# the physics shapes do not have.
			for index: int in wall.points.size() - 1:
				draw_line(wall.points[index], wall.points[index + 1], WALL_COLOR, wall.thickness)
			for point: Vector2 in wall.points:
				draw_circle(point, wall.thickness * 0.5, WALL_COLOR)

	for pin: LevelDefinition.Pin in def.pins:
		_draw_pin(pin)

	for state: LevelInstance.MaterialState in _instance.materials:
		# Tokens are drawn by their TokenVisual once a world is attached.
		if _world != null and state.kind == LevelSchema.MATERIAL_TOKEN:
			continue
		_draw_material(state)


## A pin is its shaft rectangle plus a handle knob, the same two shapes BoardColliders makes.
## The outline is drawn inside them.
func _draw_pin(pin: LevelDefinition.Pin) -> void:
	var axis: Vector2 = (pin.handle - pin.tip).normalized()
	var side: Vector2 = axis.orthogonal() * pin.thickness * 0.5
	var inset: float = 2.0
	var outer: PackedVector2Array = PackedVector2Array([pin.tip + side, pin.handle + side, pin.handle - side, pin.tip - side])
	draw_colored_polygon(outer, PIN_EDGE_COLOR)
	var inner_side: Vector2 = axis.orthogonal() * (pin.thickness * 0.5 - inset)
	var inner: PackedVector2Array = PackedVector2Array([
		pin.tip + axis * inset + inner_side, pin.handle + inner_side, pin.handle - inner_side, pin.tip + axis * inset - inner_side,
	])
	draw_colored_polygon(inner, PIN_COLOR)
	var knob: float = pin.thickness * SimConfig.PIN_KNOB_RADIUS_FACTOR
	draw_circle(pin.handle, knob, PIN_EDGE_COLOR)
	draw_circle(pin.handle, knob - 3.0, PIN_COLOR)
	_label(pin.handle + Vector2(-8.0, -knob - 6.0), pin.id.get_slice(".", 1).to_upper())


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
