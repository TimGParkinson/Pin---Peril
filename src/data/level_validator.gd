class_name LevelValidator
extends RefCounted
## Semantic validation of a structurally parsed LevelDefinition.
##
## Run it before a level is instantiated or saved. Checks finite numbers, bounded sizes and
## counts, unique ids, references, wall geometry, supported mechanics, pin geometry and
## spawn clearances. Never mutates the definition. Cheap checks run first; if counts are
## exceeded or numbers are not finite the expensive geometry checks are skipped, so hostile
## data cannot cause large amounts of work. Data layer: no Node access.


## `supported_sim_config_version` is passed in so this layer does not depend on the sim layer.
static func validate(def: LevelDefinition, supported_sim_config_version: int) -> ValidationReport:
	var report: ValidationReport = ValidationReport.new()
	_check_header(def, supported_sim_config_version, report)
	_check_meta(def, report)
	_check_counts(def, report)
	if not _check_finite(def, report):
		return report
	if not _check_design_size(def, report) or report.has_code("count.exceeded"):
		return report
	_check_ids(def, report)
	_check_mechanics(def, report)
	_check_walls(def, report)
	_check_pins(def, report)
	_check_zones(def, report)
	_check_spawns(def, report)
	_check_objective(def, report)
	_check_sequences(def, report)
	return report


# ---------------------------------------------------------------------------
# Header, metadata, counts
# ---------------------------------------------------------------------------

static func _check_header(def: LevelDefinition, supported_sim: int, report: ValidationReport) -> void:
	if def.schema_version != LevelSchema.SCHEMA_VERSION:
		report.add("schema_version", "schema.version_unsupported",
			"schema version %d is not supported (expected %d)" % [def.schema_version, LevelSchema.SCHEMA_VERSION])
	if def.sim_config_version != supported_sim:
		report.add("sim_config_version", "sim.version_mismatch",
			"level was made for simulation config %d but this build uses %d; revalidate and migrate" % [def.sim_config_version, supported_sim])
	if not LevelSchema.is_valid_id(def.level_id):
		report.add("level_id", "id.invalid", "invalid level id")
	if def.title.strip_edges().is_empty() or def.title.length() > LevelSchema.MAX_TEXT_LENGTH:
		report.add("title", "text.invalid", "title must be 1 to %d characters" % LevelSchema.MAX_TEXT_LENGTH)


static func _check_meta(def: LevelDefinition, report: ValidationReport) -> void:
	if def.meta.author.length() > LevelSchema.MAX_TEXT_LENGTH:
		report.add("meta.author", "text.invalid", "author too long")
	if def.meta.notes.length() > LevelSchema.MAX_NOTES_LENGTH:
		report.add("meta.notes", "text.invalid", "notes too long")
	if not LevelSchema.is_valid_date(def.meta.created):
		report.add("meta.created", "meta.date_invalid", "created must be YYYY-MM-DD")
	if not LevelSchema.SOURCES.has(def.meta.source):
		report.add("meta.source", "meta.source_invalid", "source must be one of %s" % ", ".join(LevelSchema.SOURCES))


static func _check_counts(def: LevelDefinition, report: ValidationReport) -> void:
	_limit(report, "walls", def.walls.size(), LevelSchema.MAX_WALLS)
	_limit(report, "pins", def.pins.size(), LevelSchema.MAX_PINS)
	_limit(report, "spawns", def.spawns.size(), LevelSchema.MAX_SPAWNS)
	_limit(report, "goals", def.goals.size(), LevelSchema.MAX_GOALS)
	_limit(report, "hazards", def.hazards.size(), LevelSchema.MAX_HAZARDS)
	_limit(report, "known_sequences", def.known_sequences.size(), LevelSchema.MAX_SEQUENCES)
	_limit(report, "allowed_mechanics", def.allowed_mechanics.size(), LevelSchema.MAX_MECHANICS)
	for index: int in def.walls.size():
		_limit(report, "walls[%d].points" % index, def.walls[index].points.size(), LevelSchema.MAX_WALL_POINTS)


## Inclusive containment (Rect2.has_point excludes the right and bottom edges).
static func _contains(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


static func _limit(report: ValidationReport, path: String, count: int, maximum: int) -> void:
	if count > maximum:
		report.add(path, "count.exceeded", "%d entries, at most %d allowed" % [count, maximum])


## Returns false if any number is NaN or infinite. Later checks assume finite values.
static func _check_finite(def: LevelDefinition, report: ValidationReport) -> bool:
	var ok: bool = true
	ok = _finite(report, "design_size", def.design_size) and ok
	for index: int in def.walls.size():
		var wall: LevelDefinition.Wall = def.walls[index]
		ok = _finite_number(report, "walls[%d].thickness" % index, wall.thickness) and ok
		for point_index: int in wall.points.size():
			ok = _finite(report, "walls[%d].points[%d]" % [index, point_index], wall.points[point_index]) and ok
	for index: int in def.pins.size():
		var pin: LevelDefinition.Pin = def.pins[index]
		var base: String = "pins[%d]" % index
		ok = _finite(report, base + ".tip", pin.tip) and ok
		ok = _finite(report, base + ".handle", pin.handle) and ok
		ok = _finite(report, base + ".pull_direction", pin.pull_direction) and ok
		ok = _finite_number(report, base + ".thickness", pin.thickness) and ok
		ok = _finite_number(report, base + ".pull_distance", pin.pull_distance) and ok
	for index: int in def.spawns.size():
		ok = _finite(report, "spawns[%d].position" % index, def.spawns[index].position) and ok
	for index: int in def.goals.size():
		ok = _finite_rect(report, "goals[%d].rect" % index, def.goals[index].rect) and ok
	for index: int in def.hazards.size():
		ok = _finite_rect(report, "hazards[%d].rect" % index, def.hazards[index].rect) and ok
	return ok


static func _finite_number(report: ValidationReport, path: String, value: float) -> bool:
	if is_finite(value):
		return true
	report.add(path, "number.not_finite", "value must be a finite number")
	return false


static func _finite(report: ValidationReport, path: String, value: Vector2) -> bool:
	if is_finite(value.x) and is_finite(value.y):
		return true
	report.add(path, "number.not_finite", "values must be finite numbers")
	return false


static func _finite_rect(report: ValidationReport, path: String, value: Rect2) -> bool:
	return _finite(report, path, value.position) and _finite(report, path, value.size)


static func _check_design_size(def: LevelDefinition, report: ValidationReport) -> bool:
	var size: Vector2 = def.design_size
	if size.x < LevelSchema.DESIGN_MIN or size.y < LevelSchema.DESIGN_MIN \
			or size.x > LevelSchema.DESIGN_MAX or size.y > LevelSchema.DESIGN_MAX:
		report.add("design_size", "design.size_invalid", "each side must be between %d and %d" % [LevelSchema.DESIGN_MIN, LevelSchema.DESIGN_MAX])
		return false
	return true


# ---------------------------------------------------------------------------
# Ids and mechanics
# ---------------------------------------------------------------------------

static func _check_ids(def: LevelDefinition, report: ValidationReport) -> void:
	var seen: Dictionary = {}
	_collect_ids(report, seen, "walls", def.walls.map(func(item: LevelDefinition.Wall) -> String: return item.id))
	_collect_ids(report, seen, "pins", def.pins.map(func(item: LevelDefinition.Pin) -> String: return item.id))
	_collect_ids(report, seen, "spawns", def.spawns.map(func(item: LevelDefinition.Spawn) -> String: return item.id))
	_collect_ids(report, seen, "goals", def.goals.map(func(item: LevelDefinition.Goal) -> String: return item.id))
	_collect_ids(report, seen, "hazards", def.hazards.map(func(item: LevelDefinition.Hazard) -> String: return item.id))
	var sequence_ids: Dictionary = {}
	_collect_ids(report, sequence_ids, "known_sequences", def.known_sequences.map(func(item: LevelDefinition.Sequence) -> String: return item.id))


static func _collect_ids(report: ValidationReport, seen: Dictionary, collection: String, ids: Array) -> void:
	for index: int in ids.size():
		var id: String = ids[index] as String
		var path: String = "%s[%d].id" % [collection, index]
		if not LevelSchema.is_valid_id(id):
			report.add(path, "id.invalid", "invalid id '%s'" % id.left(40))
		elif seen.has(id):
			report.add(path, "id.duplicate", "id '%s' is already used by %s" % [id, seen[id]])
		else:
			seen[id] = "%s[%d]" % [collection, index]


static func _check_mechanics(def: LevelDefinition, report: ValidationReport) -> void:
	var declared: Dictionary = {}
	for index: int in def.allowed_mechanics.size():
		var mechanic: String = def.allowed_mechanics[index]
		var path: String = "allowed_mechanics[%d]" % index
		if declared.has(mechanic):
			report.add(path, "mechanic.duplicate", "mechanic '%s' listed twice" % mechanic)
		declared[mechanic] = true
		if LevelSchema.RESERVED_MECHANICS.has(mechanic):
			report.add(path, "mechanic.unsupported", "mechanic '%s' is planned but not supported yet" % mechanic)
		elif not LevelSchema.SUPPORTED_MECHANICS.has(mechanic):
			report.add(path, "mechanic.unknown", "unknown mechanic '%s'" % mechanic.left(40))

	if not def.pins.is_empty():
		_require_mechanic(report, declared, "pins", "pins", "pins are present")
	if not def.hazards.is_empty():
		_require_mechanic(report, declared, "hazard_zones", "hazards", "hazard zones are present")
	for index: int in def.goals.size():
		if def.goals[index].kind == LevelSchema.GOAL_DISPOSAL:
			_require_mechanic(report, declared, "disposal_zones", "goals[%d]" % index, "a disposal zone is present")
	for index: int in def.spawns.size():
		var material: String = def.spawns[index].material
		if LevelSchema.MATERIAL_MECHANIC.has(material):
			_require_mechanic(report, declared, LevelSchema.MATERIAL_MECHANIC[material] as String, "spawns[%d]" % index, "material '%s' is used" % material)


static func _require_mechanic(report: ValidationReport, declared: Dictionary, mechanic: String, path: String, reason: String) -> void:
	if not declared.has(mechanic):
		report.add(path, "mechanic.undeclared_use", "'%s' must be listed in allowed_mechanics because %s" % [mechanic, reason])


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------

static func _check_walls(def: LevelDefinition, report: ValidationReport) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, def.design_size)
	for index: int in def.walls.size():
		var wall: LevelDefinition.Wall = def.walls[index]
		var path: String = "walls[%d]" % index
		var closed: bool = wall.kind == LevelSchema.WALL_KIND_POLYGON
		if not LevelSchema.WALL_KINDS.has(wall.kind):
			report.add(path + ".kind", "wall.kind_invalid", "kind must be polyline or polygon")
			continue
		var minimum: int = 3 if closed else 2
		if wall.points.size() < minimum:
			report.add(path + ".points", "wall.too_few_points", "%s needs at least %d points" % [wall.kind, minimum])
			continue
		if not closed and (wall.thickness < LevelSchema.WALL_THICKNESS_MIN or wall.thickness > LevelSchema.WALL_THICKNESS_MAX):
			report.add(path + ".thickness", "wall.thickness", "thickness must be between %d and %d" % [LevelSchema.WALL_THICKNESS_MIN, LevelSchema.WALL_THICKNESS_MAX])
		var geometry_ok: bool = true
		for point_index: int in wall.points.size():
			if not _contains(bounds, wall.points[point_index]):
				report.add("%s.points[%d]" % [path, point_index], "wall.out_of_bounds", "point is outside the design space")
				geometry_ok = false
		for edge: int in LevelGeometry.edge_count(wall.points, closed):
			if LevelGeometry.edge_start(wall.points, edge).distance_to(LevelGeometry.edge_end(wall.points, edge)) < LevelSchema.SEGMENT_MIN_LENGTH:
				report.add("%s.points[%d]" % [path, edge], "wall.degenerate_segment", "segment shorter than %d units" % LevelSchema.SEGMENT_MIN_LENGTH)
				geometry_ok = false
		if not geometry_ok:
			continue
		if LevelGeometry.has_self_intersection(wall.points, closed):
			report.add(path + ".points", "wall.self_intersect", "wall crosses or folds over itself")
		elif closed and LevelGeometry.polygon_area(wall.points) < LevelSchema.POLYGON_MIN_AREA:
			report.add(path + ".points", "wall.polygon_area", "polygon area is too small")


# ---------------------------------------------------------------------------
# Pins
# ---------------------------------------------------------------------------

static func _check_pins(def: LevelDefinition, report: ValidationReport) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, def.design_size)
	var usable: Array[int] = []
	for index: int in def.pins.size():
		var pin: LevelDefinition.Pin = def.pins[index]
		var path: String = "pins[%d]" % index
		var ok: bool = true
		if pin.thickness < LevelSchema.PIN_THICKNESS_MIN or pin.thickness > LevelSchema.PIN_THICKNESS_MAX:
			report.add(path + ".thickness", "pin.thickness", "thickness must be between %d and %d" % [LevelSchema.PIN_THICKNESS_MIN, LevelSchema.PIN_THICKNESS_MAX])
			ok = false
		if not _contains(bounds, pin.tip) or not _contains(bounds, pin.handle):
			report.add(path, "pin.out_of_bounds", "tip and handle must be inside the design space")
			ok = false
		var length: float = pin.tip.distance_to(pin.handle)
		if length < LevelSchema.PIN_LENGTH_MIN or length > LevelSchema.PIN_LENGTH_MAX:
			report.add(path, "pin.length", "pin length must be between %d and %d" % [LevelSchema.PIN_LENGTH_MIN, LevelSchema.PIN_LENGTH_MAX])
			ok = false
		if absf(pin.pull_direction.length() - 1.0) > LevelSchema.DIRECTION_TOLERANCE:
			report.add(path + ".pull_direction", "pin.direction_not_unit", "pull direction must have length 1")
			ok = false
		elif ok:
			# The pin slides out along its own axis: from the tip toward the handle.
			var axis: Vector2 = (pin.handle - pin.tip).normalized()
			if absf(axis.cross(pin.pull_direction)) > LevelSchema.DIRECTION_TOLERANCE or axis.dot(pin.pull_direction) <= 0.0:
				report.add(path + ".pull_direction", "pin.direction_mismatch", "pull direction must point from the tip toward the handle")
				ok = false
		if pin.pull_distance < length - 0.0001 or pin.pull_distance > LevelSchema.PULL_DISTANCE_MAX:
			report.add(path + ".pull_distance", "pin.pull_distance", "pull distance must be at least the pin length (%.1f) and at most %d" % [length, LevelSchema.PULL_DISTANCE_MAX])
			ok = false
		if ok:
			usable.append(index)

	for first_slot: int in usable.size():
		for second_slot: int in range(first_slot + 1, usable.size()):
			var first: LevelDefinition.Pin = def.pins[usable[first_slot]]
			var second: LevelDefinition.Pin = def.pins[usable[second_slot]]
			var gap: float = LevelGeometry.distance_segment_segment(first.tip, first.handle, second.tip, second.handle)
			if gap < (first.thickness + second.thickness) * 0.5 + LevelSchema.PIN_GAP:
				report.add("pins[%d]" % usable[second_slot], "pin.overlap", "pin is too close to or overlaps pins[%d]" % usable[first_slot])


# ---------------------------------------------------------------------------
# Goals and hazards
# ---------------------------------------------------------------------------

static func _check_zones(def: LevelDefinition, report: ValidationReport) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, def.design_size)
	var zones: Array[Dictionary] = []
	for index: int in def.goals.size():
		var goal: LevelDefinition.Goal = def.goals[index]
		var path: String = "goals[%d]" % index
		if not LevelSchema.GOAL_KINDS.has(goal.kind):
			report.add(path + ".kind", "goal.kind_invalid", "kind must be collector or disposal")
		if goal.accepts.is_empty():
			report.add(path + ".accepts", "goal.accepts_empty", "a goal must accept at least one material")
		for material: String in goal.accepts:
			if not LevelSchema.MATERIAL_RADIUS.has(material):
				report.add(path + ".accepts", "goal.accepts_unknown", "unknown material '%s'" % material.left(40))
		if _check_rect(report, path + ".rect", goal.rect, bounds):
			zones.append({"path": path, "rect": goal.rect})
	for index: int in def.hazards.size():
		var hazard: LevelDefinition.Hazard = def.hazards[index]
		var path: String = "hazards[%d]" % index
		if not LevelSchema.HAZARD_KINDS.has(hazard.kind):
			report.add(path + ".kind", "hazard.kind_invalid", "kind must be destroy_zone")
		if hazard.affects.is_empty():
			report.add(path + ".affects", "hazard.affects_empty", "a hazard must affect at least one material")
		for material: String in hazard.affects:
			if not LevelSchema.MATERIAL_RADIUS.has(material):
				report.add(path + ".affects", "hazard.affects_unknown", "unknown material '%s'" % material.left(40))
		if _check_rect(report, path + ".rect", hazard.rect, bounds):
			zones.append({"path": path, "rect": hazard.rect})
	for first_index: int in zones.size():
		for second_index: int in range(first_index + 1, zones.size()):
			if (zones[first_index]["rect"] as Rect2).intersects(zones[second_index]["rect"] as Rect2):
				report.add(zones[second_index]["path"] as String, "goal.overlap",
					"zone overlaps %s; overlapping goals and hazards are ambiguous" % zones[first_index]["path"])


static func _check_rect(report: ValidationReport, path: String, rect: Rect2, bounds: Rect2) -> bool:
	if rect.size.x < LevelSchema.ZONE_MIN_SIZE or rect.size.y < LevelSchema.ZONE_MIN_SIZE:
		report.add(path, "goal.rect", "rectangle sides must be at least %d" % LevelSchema.ZONE_MIN_SIZE)
		return false
	if not bounds.encloses(rect):
		report.add(path, "goal.rect", "rectangle must be inside the design space")
		return false
	return true


# ---------------------------------------------------------------------------
# Spawns
# ---------------------------------------------------------------------------

static func _check_spawns(def: LevelDefinition, report: ValidationReport) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, def.design_size)
	var valid_spawns: Array[int] = []
	for index: int in def.spawns.size():
		var spawn: LevelDefinition.Spawn = def.spawns[index]
		var path: String = "spawns[%d]" % index
		if not LevelSchema.MATERIAL_RADIUS.has(spawn.material):
			report.add(path + ".material", "spawn.unknown_material", "unknown material '%s'" % spawn.material.left(40))
			continue
		var radius: float = LevelSchema.MATERIAL_RADIUS[spawn.material] as float
		if not _contains(bounds.grow(-radius), spawn.position):
			report.add(path + ".position", "spawn.out_of_bounds", "body must be fully inside the design space")
			continue
		valid_spawns.append(index)
		var clear_of_walls: bool = true
		for wall_index: int in def.walls.size():
			if not _spawn_clear_of_wall(spawn.position, radius, def.walls[wall_index]):
				report.add(path + ".position", "spawn.in_wall", "body overlaps or touches walls[%d]" % wall_index)
				clear_of_walls = false
				break
		if not clear_of_walls:
			continue
		for pin_index: int in def.pins.size():
			var pin: LevelDefinition.Pin = def.pins[pin_index]
			if is_finite(pin.thickness) and LevelGeometry.distance_point_segment(spawn.position, pin.tip, pin.handle) < radius + pin.thickness * 0.5 + LevelSchema.SPAWN_GAP:
				report.add(path + ".position", "spawn.in_pin", "body overlaps or touches pins[%d]" % pin_index)
				break
		for goal_index: int in def.goals.size():
			if def.goals[goal_index].rect.grow(radius).has_point(spawn.position):
				report.add(path + ".position", "spawn.in_zone", "body starts inside or touching goals[%d]" % goal_index)
		for hazard_index: int in def.hazards.size():
			if def.hazards[hazard_index].rect.grow(radius).has_point(spawn.position):
				report.add(path + ".position", "spawn.in_zone", "body starts inside or touching hazards[%d]" % hazard_index)

	for first_slot: int in valid_spawns.size():
		for second_slot: int in range(first_slot + 1, valid_spawns.size()):
			var first: LevelDefinition.Spawn = def.spawns[valid_spawns[first_slot]]
			var second: LevelDefinition.Spawn = def.spawns[valid_spawns[second_slot]]
			var needed: float = (LevelSchema.MATERIAL_RADIUS[first.material] as float) + (LevelSchema.MATERIAL_RADIUS[second.material] as float) + LevelSchema.SPAWN_GAP
			if first.position.distance_to(second.position) < needed:
				report.add("spawns[%d].position" % valid_spawns[second_slot], "spawn.overlap",
					"body overlaps or touches spawns[%d] (needs %.1f clear distance)" % [valid_spawns[first_slot], needed])


static func _spawn_clear_of_wall(center: Vector2, radius: float, wall: LevelDefinition.Wall) -> bool:
	if not LevelSchema.WALL_KINDS.has(wall.kind):
		return true  # reported by the wall check
	var closed: bool = wall.kind == LevelSchema.WALL_KIND_POLYGON
	var minimum: int = 3 if closed else 2
	if wall.points.size() < minimum:
		return true  # reported by the wall check
	if closed:
		if Geometry2D.is_point_in_polygon(center, wall.points):
			return false
		return LevelGeometry.distance_to_outline(center, wall.points, true) >= radius + LevelSchema.SPAWN_GAP
	return LevelGeometry.distance_to_outline(center, wall.points, false) >= radius + wall.thickness * 0.5 + LevelSchema.SPAWN_GAP


# ---------------------------------------------------------------------------
# Objective and known sequences
# ---------------------------------------------------------------------------

static func _check_objective(def: LevelDefinition, report: ValidationReport) -> void:
	var objective: LevelDefinition.Objective = def.objective
	var tokens: int = def.count_spawns(LevelSchema.MATERIAL_TOKEN)
	if objective.required_tokens < 1 or objective.required_tokens > tokens:
		report.add("objective.required_tokens", "objective.required_tokens",
			"required tokens must be between 1 and the number of token spawns (%d)" % tokens)
	elif objective.allowed_token_losses < 0 or objective.allowed_token_losses > tokens - objective.required_tokens:
		report.add("objective.allowed_token_losses", "objective.allowed_losses",
			"allowed losses must be between 0 and %d (tokens minus required)" % (tokens - objective.required_tokens))
	if objective.collector_ids.is_empty():
		report.add("objective.collector_ids", "objective.collector_ref", "at least one collector is required")
	for index: int in objective.collector_ids.size():
		var goal: LevelDefinition.Goal = def.find_goal(objective.collector_ids[index])
		var path: String = "objective.collector_ids[%d]" % index
		if goal == null:
			report.add(path, "objective.collector_ref", "no goal with id '%s'" % objective.collector_ids[index].left(40))
		elif goal.kind != LevelSchema.GOAL_COLLECTOR:
			report.add(path, "objective.collector_kind", "goal '%s' is not a collector" % goal.id)
		elif not goal.accepts.has(LevelSchema.MATERIAL_TOKEN):
			report.add(path, "objective.collector_kind", "collector '%s' does not accept tokens" % goal.id)
	for index: int in objective.fail_conditions.size():
		if not LevelSchema.FAIL_CONDITIONS.has(objective.fail_conditions[index]):
			report.add("objective.fail_conditions[%d]" % index, "objective.fail_condition_unknown",
				"unknown fail condition '%s'" % objective.fail_conditions[index].left(40))


static func _check_sequences(def: LevelDefinition, report: ValidationReport) -> void:
	for index: int in def.known_sequences.size():
		var sequence: LevelDefinition.Sequence = def.known_sequences[index]
		var path: String = "known_sequences[%d]" % index
		if not LevelSchema.TERMINAL_RESULTS.has(sequence.expected_result):
			report.add(path + ".expected_result", "sequence.result_unknown", "expected_result must be one of %s" % ", ".join(LevelSchema.TERMINAL_RESULTS))
		if sequence.actions.is_empty():
			report.add(path + ".actions", "sequence.empty", "a sequence needs at least one action")
		var used: Dictionary = {}
		for action_index: int in sequence.actions.size():
			var pin_id: String = sequence.actions[action_index]
			var action_path: String = "%s.actions[%d]" % [path, action_index]
			if def.find_pin(pin_id) == null:
				report.add(action_path, "sequence.pin_unknown", "no pin with id '%s'" % pin_id.left(40))
			elif used.has(pin_id):
				report.add(action_path, "sequence.pin_repeated", "pin '%s' is one-use and cannot be pulled twice" % pin_id)
			used[pin_id] = true
