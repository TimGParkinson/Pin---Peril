class_name LevelGeometry
extends RefCounted
## Pure 2D geometry helpers used by level validation (and later by the editor).
## No Node access. All inputs are assumed finite; the validator checks that first.


## Shortest distance from a point to a segment.
static func distance_point_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))


## True if the two segments share at least one point.
static func segments_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	return Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null


## Shortest distance between two segments (0 if they cross or touch).
static func distance_segment_segment(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> float:
	if segments_intersect(a1, a2, b1, b2):
		return 0.0
	return minf(
		minf(distance_point_segment(a1, b1, b2), distance_point_segment(a2, b1, b2)),
		minf(distance_point_segment(b1, a1, a2), distance_point_segment(b2, a1, a2))
	)


## Absolute polygon area (shoelace formula).
static func polygon_area(points: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in points.size():
		var current: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % points.size()]
		twice_area += current.x * next.y - next.x * current.y
	return absf(twice_area) * 0.5


## Number of edges for an open polyline or a closed polygon.
static func edge_count(points: PackedVector2Array, closed: bool) -> int:
	if points.size() < 2:
		return 0
	return points.size() if closed else points.size() - 1


## Edge endpoints by index. For closed shapes the last edge returns to point 0.
static func edge_start(points: PackedVector2Array, index: int) -> Vector2:
	return points[index]


static func edge_end(points: PackedVector2Array, index: int) -> Vector2:
	return points[(index + 1) % points.size()]


## True if any two non-adjacent edges cross or touch. Adjacent edges only meet at their
## shared vertex, except when one folds back exactly over the other, which also counts.
static func has_self_intersection(points: PackedVector2Array, closed: bool) -> bool:
	var edges: int = edge_count(points, closed)
	for i: int in edges:
		for j: int in range(i + 1, edges):
			var adjacent: bool = j == i + 1 or (closed and i == 0 and j == edges - 1)
			var a1: Vector2 = edge_start(points, i)
			var a2: Vector2 = edge_end(points, i)
			var b1: Vector2 = edge_start(points, j)
			var b2: Vector2 = edge_end(points, j)
			if adjacent:
				if _folds_back(a1, a2, b1, b2):
					return true
			elif segments_intersect(a1, a2, b1, b2):
				return true
	return false


## Distance from a point to the nearest edge of a polyline or polygon outline.
static func distance_to_outline(point: Vector2, points: PackedVector2Array, closed: bool) -> float:
	var best: float = INF
	for index: int in edge_count(points, closed):
		best = minf(best, distance_point_segment(point, edge_start(points, index), edge_end(points, index)))
	return best


## Two adjacent edges fold back when they run along the same line in opposite directions.
static func _folds_back(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var first: Vector2 = (a2 - a1).normalized()
	var second: Vector2 = (b2 - b1).normalized()
	return absf(first.cross(second)) < 0.0001 and first.dot(second) < 0.0
