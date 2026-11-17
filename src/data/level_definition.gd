class_name LevelDefinition
extends RefCounted
## Versioned, data-only description of one level. Never a runtime object.
##
## A definition holds what the author or generator specified. It has no physics bodies and
## no mutable play state; LevelInstance (sim layer) is built from it at play time. All
## coordinates are in the level's design space: origin top-left, x right, y down.
## Every gameplay object has a unique stable string id (see LevelSchema.is_valid_id).
## Format documented in docs/LEVEL_FORMAT.md. Data layer: no Node access.


class Meta:
	extends RefCounted
	var author: String = ""
	var created: String = ""  # YYYY-MM-DD
	var source: String = "handcrafted"  # handcrafted | editor | generator
	var notes: String = ""


class Wall:
	extends RefCounted
	var id: String = ""
	var kind: String = LevelSchema.WALL_KIND_POLYLINE
	var thickness: float = 24.0  # polylines only; polygons are filled solids
	var points: PackedVector2Array = PackedVector2Array()


class Pin:
	extends RefCounted
	var id: String = ""
	var tip: Vector2 = Vector2.ZERO  # end that blocks material
	var handle: Vector2 = Vector2.ZERO  # end the player grabs
	var thickness: float = 16.0
	var pull_direction: Vector2 = Vector2.LEFT  # unit vector, direction the pin slides out
	var pull_distance: float = 0.0


class Spawn:
	extends RefCounted
	var id: String = ""
	var material: String = LevelSchema.MATERIAL_TOKEN
	var position: Vector2 = Vector2.ZERO


class Goal:
	extends RefCounted
	var id: String = ""
	var kind: String = LevelSchema.GOAL_COLLECTOR
	var rect: Rect2 = Rect2()
	var accepts: PackedStringArray = PackedStringArray()
	var is_protected: bool = false  # delivering a non-accepted material here is a failure


class Hazard:
	extends RefCounted
	var id: String = ""
	var kind: String = LevelSchema.HAZARD_DESTROY_ZONE
	var rect: Rect2 = Rect2()
	var affects: PackedStringArray = PackedStringArray()


class Objective:
	extends RefCounted
	var required_tokens: int = 1
	var allowed_token_losses: int = 0
	var collector_ids: PackedStringArray = PackedStringArray()
	var fail_conditions: PackedStringArray = PackedStringArray()


class Sequence:
	extends RefCounted
	var id: String = ""
	var actions: PackedStringArray = PackedStringArray()  # pin ids in pull order
	var expected_result: String = "won"


var schema_version: int = LevelSchema.SCHEMA_VERSION
var level_id: String = ""
var title: String = ""
var sim_config_version: int = 0
var meta: Meta = Meta.new()
var design_size: Vector2 = Vector2(1600.0, 900.0)
var allowed_mechanics: PackedStringArray = PackedStringArray()
var walls: Array[Wall] = []
var pins: Array[Pin] = []
var spawns: Array[Spawn] = []
var goals: Array[Goal] = []
var hazards: Array[Hazard] = []
var objective: Objective = Objective.new()
var known_sequences: Array[Sequence] = []


func count_spawns(material: String) -> int:
	var total: int = 0
	for spawn: Spawn in spawns:
		if spawn.material == material:
			total += 1
	return total


func find_pin(pin_id: String) -> Pin:
	for pin: Pin in pins:
		if pin.id == pin_id:
			return pin
	return null


func find_goal(goal_id: String) -> Goal:
	for goal: Goal in goals:
		if goal.id == goal_id:
			return goal
	return null


## Every gameplay object id (walls, pins, spawns, goals, hazards), in declaration order.
func all_object_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for wall: Wall in walls:
		ids.append(wall.id)
	for pin: Pin in pins:
		ids.append(pin.id)
	for spawn: Spawn in spawns:
		ids.append(spawn.id)
	for goal: Goal in goals:
		ids.append(goal.id)
	for hazard: Hazard in hazards:
		ids.append(hazard.id)
	return ids


## Canonical text of everything that affects initial geometry and starting positions.
## Excludes titles, metadata, objective rules and solutions. Two definitions with the same
## signature start with identical boards. Numbers use fixed 4 decimal formatting.
func geometry_signature() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("design %s" % _fmt_vec(design_size))
	for wall: Wall in walls:
		var points: PackedStringArray = PackedStringArray()
		for point: Vector2 in wall.points:
			points.append(_fmt_vec(point))
		lines.append("wall %s %s %s %s" % [wall.id, wall.kind, _fmt(wall.thickness), ";".join(points)])
	for pin: Pin in pins:
		lines.append("pin %s tip %s handle %s thickness %s dir %s dist %s" % [
			pin.id, _fmt_vec(pin.tip), _fmt_vec(pin.handle), _fmt(pin.thickness),
			_fmt_vec(pin.pull_direction), _fmt(pin.pull_distance),
		])
	for spawn: Spawn in spawns:
		lines.append("spawn %s %s %s" % [spawn.id, spawn.material, _fmt_vec(spawn.position)])
	for goal: Goal in goals:
		lines.append("goal %s %s %s accepts %s protected %s" % [
			goal.id, goal.kind, _fmt_rect(goal.rect), ",".join(goal.accepts), str(goal.is_protected),
		])
	for hazard: Hazard in hazards:
		lines.append("hazard %s %s %s affects %s" % [
			hazard.id, hazard.kind, _fmt_rect(hazard.rect), ",".join(hazard.affects),
		])
	return "\n".join(lines)


## SHA-256 (hex) of geometry_signature().
func geometry_hash() -> String:
	return geometry_signature().sha256_text()


static func _fmt(value: float) -> String:
	return "%.4f" % value


static func _fmt_vec(value: Vector2) -> String:
	return "%.4f,%.4f" % [value.x, value.y]


static func _fmt_rect(value: Rect2) -> String:
	return "%.4f,%.4f,%.4f,%.4f" % [value.position.x, value.position.y, value.size.x, value.size.y]
