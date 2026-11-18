class_name BoardColliders
extends RefCounted
## Builds the collision shapes for level geometry. Pure shape math, no Nodes.
##
## The rule is that collision equals what is drawn, using the simplest exact shapes:
## - a polyline wall is one capsule per segment (a thick line with round joints and round ends,
##   which is what BoardView draws);
## - a polygon wall is its convex decomposition (pieces that together cover exactly the polygon);
## - a pin is a rectangle (the shaft) plus a disc (the handle knob).
## Visual detail (shading, outlines, decoration) never adds collision.


## One shape and where it sits relative to the owning body (the body sits at the origin).
class Collider:
	extends RefCounted
	var shape: Shape2D = null
	var transform: Transform2D = Transform2D.IDENTITY


## Collision shapes for a wall. Empty if a polygon cannot be decomposed, which validation
## prevents; the caller reports that as a problem rather than leaving a hole in the board.
static func for_wall(wall: LevelDefinition.Wall) -> Array[Collider]:
	if wall.kind == LevelSchema.WALL_KIND_POLYGON:
		return _polygon_pieces(wall.points)
	return _capsule_chain(wall.points, wall.thickness)


## Collision shapes for a pin: the shaft rectangle and the knob disc.
static func for_pin(pin: LevelDefinition.Pin) -> Array[Collider]:
	var result: Array[Collider] = []
	var axis: Vector2 = pin.handle - pin.tip
	var shaft: RectangleShape2D = RectangleShape2D.new()
	shaft.size = Vector2(axis.length(), pin.thickness)
	var shaft_collider: Collider = Collider.new()
	shaft_collider.shape = shaft
	shaft_collider.transform = Transform2D(axis.angle(), (pin.tip + pin.handle) * 0.5)
	result.append(shaft_collider)

	var knob: CircleShape2D = CircleShape2D.new()
	knob.radius = pin.thickness * SimConfig.PIN_KNOB_RADIUS_FACTOR
	var knob_collider: Collider = Collider.new()
	knob_collider.shape = knob
	knob_collider.transform = Transform2D(0.0, pin.handle)
	result.append(knob_collider)
	return result


static func _capsule_chain(points: PackedVector2Array, thickness: float) -> Array[Collider]:
	var result: Array[Collider] = []
	for index: int in points.size() - 1:
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var segment: Vector2 = end - start
		var capsule: CapsuleShape2D = CapsuleShape2D.new()
		capsule.radius = thickness * 0.5
		# Godot's capsule height includes both caps. Its long axis is local Y, so rotate a quarter
		# turn past the segment direction to lay it along the segment.
		capsule.height = segment.length() + thickness
		var collider: Collider = Collider.new()
		collider.shape = capsule
		collider.transform = Transform2D(segment.angle() + PI * 0.5, (start + end) * 0.5)
		result.append(collider)
	return result


static func _polygon_pieces(points: PackedVector2Array) -> Array[Collider]:
	var result: Array[Collider] = []
	var pieces: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(points)
	for piece: PackedVector2Array in pieces:
		var convex: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		convex.points = piece
		var collider: Collider = Collider.new()
		collider.shape = convex
		result.append(collider)
	return result
