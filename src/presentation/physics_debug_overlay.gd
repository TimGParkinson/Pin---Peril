class_name PhysicsDebugOverlay
extends Node2D
## Developer overlay for the physics world: collision shapes, body ids, velocities, statistics.
##
## Shapes are drawn from the live CollisionShape2D nodes of the world's bodies (not from the
## level data), so what you see is exactly what the physics engine collides with. Everything is
## off by default. LevelScreen toggles the layers with F2 to F5 in debug builds. Read-only: it
## never changes the world.

enum Layer { SHAPES, IDS, VELOCITIES, STATS }

const WALL_SHAPE_COLOR: Color = Color(0.0, 0.85, 1.0, 0.45)
const PIN_SHAPE_COLOR: Color = Color(1.0, 0.2, 0.9, 0.45)
const TOKEN_SHAPE_COLOR: Color = Color(0.2, 1.0, 0.2, 0.45)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const TEXT_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.85)
const SLOW_COLOR: Color = Color(0.2, 1.0, 0.2, 1.0)
const FAST_COLOR: Color = Color(1.0, 0.15, 0.1, 1.0)

## Velocity arrows show where a token would be after this many seconds at its current speed.
const VELOCITY_ARROW_SECONDS: float = 0.25
const FONT_SIZE: int = 15
const STATS_FONT_SIZE: int = 20

var _world: SimWorld = null
var _on: Dictionary = {Layer.SHAPES: false, Layer.IDS: false, Layer.VELOCITIES: false, Layer.STATS: false}


func _init() -> void:
	z_index = 100
	name = "PhysicsDebugOverlay"


func setup(sim_world: SimWorld) -> void:
	_world = sim_world
	queue_redraw()


func is_layer_on(layer: Layer) -> bool:
	return _on[layer] as bool


func set_layer(layer: Layer, enabled: bool) -> void:
	_on[layer] = enabled
	queue_redraw()


func toggle_layer(layer: Layer) -> void:
	set_layer(layer, not is_layer_on(layer))


func any_layer_on() -> bool:
	return _on.values().has(true)


## Number of collision shapes the SHAPES layer draws (walls, pins and tokens). For tests.
func shape_count() -> int:
	var total: int = 0
	if _world == null:
		return total
	for part: StaticPartBody in _world.static_parts():
		total += _shape_nodes(part).size()
	for body: TokenBody in _world.tokens():
		total += _shape_nodes(body).size()
	return total


func _process(_delta: float) -> void:
	# Velocities and statistics change every tick, so redraw while anything is visible.
	if any_layer_on():
		queue_redraw()


func _draw() -> void:
	if _world == null or not any_layer_on():
		return
	if is_layer_on(Layer.SHAPES):
		_draw_shapes()
	if is_layer_on(Layer.VELOCITIES):
		_draw_velocities()
	if is_layer_on(Layer.IDS):
		_draw_ids()
	if is_layer_on(Layer.STATS):
		_draw_stats()


func _draw_shapes() -> void:
	for part: StaticPartBody in _world.static_parts():
		var color: Color = WALL_SHAPE_COLOR if part.part_kind == StaticPartBody.KIND_WALL else PIN_SHAPE_COLOR
		_draw_body_shapes(part, color)
	for body: TokenBody in _world.tokens():
		_draw_body_shapes(body, TOKEN_SHAPE_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_body_shapes(body: CollisionObject2D, color: Color) -> void:
	for node: CollisionShape2D in _shape_nodes(body):
		# Shape2D.draw is the engine's own debug drawing of the shape, in the current transform.
		draw_set_transform_matrix(body.global_transform * node.transform)
		node.shape.draw(get_canvas_item(), color)


func _draw_velocities() -> void:
	var limit: float = maxf(1.0, _world.tuning.max_token_speed)
	for body: TokenBody in _world.tokens():
		var velocity: Vector2 = body.linear_velocity
		if velocity.length() < 1.0:
			continue
		var color: Color = SLOW_COLOR.lerp(FAST_COLOR, clampf(velocity.length() / limit, 0.0, 1.0))
		var tip: Vector2 = body.position + velocity * VELOCITY_ARROW_SECONDS
		draw_line(body.position, tip, color, 3.0)
		var back: Vector2 = -velocity.normalized() * 9.0
		draw_line(tip, tip + back.rotated(0.5), color, 3.0)
		draw_line(tip, tip + back.rotated(-0.5), color, 3.0)


func _draw_ids() -> void:
	var font: Font = ThemeDB.fallback_font
	for body: TokenBody in _world.tokens():
		_text(font, body.position + Vector2(-16.0, -18.0), body.material_id, FONT_SIZE)
	for part: StaticPartBody in _world.static_parts():
		var anchor: Vector2 = part.global_transform * _first_shape_center(part)
		_text(font, anchor + Vector2(-20.0, -14.0), part.part_id, FONT_SIZE)


func _draw_stats() -> void:
	var font: Font = ThemeDB.fallback_font
	var lines: PackedStringArray = PackedStringArray([
		"tick %d   tokens %d   awake %d" % [_world.tick_count, _world.token_count(), _world.awake_token_count()],
		"fastest %.0f   peak %.0f   limit %.0f units/s" % [_world.fastest_token_speed(), _world.peak_token_speed(), _world.tuning.max_token_speed],
		"outside board: %d   fps %d" % [_world.tokens_outside_board(0.0).size(), int(Engine.get_frames_per_second())],
		"F2 shapes  F3 ids  F4 velocity  F5 stats",
	])
	var origin: Vector2 = Vector2(24.0, 36.0)
	for index: int in lines.size():
		_text(font, origin + Vector2(0.0, float(index) * 26.0), lines[index], STATS_FONT_SIZE)


func _text(font: Font, at: Vector2, text: String, size: int) -> void:
	draw_string(font, at + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, TEXT_SHADOW)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, TEXT_COLOR)


func _shape_nodes(body: Node) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	for child: Node in body.get_children():
		var node: CollisionShape2D = child as CollisionShape2D
		if node != null and node.shape != null:
			result.append(node)
	return result


## Centre of a body's first shape in the body's own space (where its id is written).
func _first_shape_center(body: Node) -> Vector2:
	var nodes: Array[CollisionShape2D] = _shape_nodes(body)
	return nodes[0].position if not nodes.is_empty() else Vector2.ZERO
