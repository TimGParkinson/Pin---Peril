class_name LevelCodec
extends RefCounted
## Converts between untrusted plain data (parsed JSON) and LevelDefinition.
##
## Parsing is strict and structural only: every key must be known, present where required,
## and of the right type, and nothing is ever loaded, instantiated or executed from the
## data. Meaning (ranges, references, geometry) is checked afterwards by LevelValidator.
## Plain Variants only: no str_to_var, bytes_to_var, load() or script/resource paths.
## Saved coordinates are quantised to LevelSchema.COORD_DECIMALS so files are stable.

const TOP_KEYS: PackedStringArray = [
	"schema_version", "level_id", "title", "sim_config_version", "meta", "design_size",
	"allowed_mechanics", "walls", "pins", "spawns", "goals", "hazards", "objective",
	"known_sequences",
]
const META_KEYS: PackedStringArray = ["author", "created", "source", "notes"]
const POLYLINE_KEYS: PackedStringArray = ["id", "kind", "thickness", "points"]
const POLYGON_KEYS: PackedStringArray = ["id", "kind", "points"]
const PIN_KEYS: PackedStringArray = ["id", "tip", "handle", "thickness", "pull_direction", "pull_distance"]
const SPAWN_KEYS: PackedStringArray = ["id", "material", "position"]
const GOAL_KEYS: PackedStringArray = ["id", "kind", "rect", "accepts", "protected"]
const HAZARD_KEYS: PackedStringArray = ["id", "kind", "rect", "affects"]
const OBJECTIVE_KEYS: PackedStringArray = ["required_tokens", "allowed_token_losses", "collector_ids", "fail_conditions"]
const SEQUENCE_KEYS: PackedStringArray = ["id", "actions", "expected_result"]


## Parse result: `definition` is only meaningful when `report.is_ok()`.
class ParseResult:
	extends RefCounted
	var definition: LevelDefinition = null
	var report: ValidationReport = ValidationReport.new()


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

static func from_variant(data: Variant) -> ParseResult:
	var result: ParseResult = ParseResult.new()
	var report: ValidationReport = result.report
	if typeof(data) != TYPE_DICTIONARY:
		report.add("$", "type.mismatch", "level data must be a JSON object")
		return result
	var root: Dictionary = data as Dictionary
	_check_keys(root, TOP_KEYS, "$", report)

	var def: LevelDefinition = LevelDefinition.new()
	def.schema_version = _int(root, "schema_version", "$", report)
	def.level_id = _string(root, "level_id", "$", report)
	def.title = _string(root, "title", "$", report)
	def.sim_config_version = _int(root, "sim_config_version", "$", report)
	def.design_size = _vec2(root, "design_size", "$", report)
	def.allowed_mechanics = _string_list(root, "allowed_mechanics", "$", report)

	var meta_data: Dictionary = _dict(root, "meta", "$", report)
	_check_keys(meta_data, META_KEYS, "meta", report)
	def.meta.author = _string(meta_data, "author", "meta", report)
	def.meta.created = _string(meta_data, "created", "meta", report)
	def.meta.source = _string(meta_data, "source", "meta", report)
	def.meta.notes = _string(meta_data, "notes", "meta", report, false)

	var index: int = 0
	for item: Variant in _array(root, "walls", "$", report):
		def.walls.append(_parse_wall(item, "walls[%d]" % index, report))
		index += 1
	index = 0
	for item: Variant in _array(root, "pins", "$", report):
		def.pins.append(_parse_pin(item, "pins[%d]" % index, report))
		index += 1
	index = 0
	for item: Variant in _array(root, "spawns", "$", report):
		def.spawns.append(_parse_spawn(item, "spawns[%d]" % index, report))
		index += 1
	index = 0
	for item: Variant in _array(root, "goals", "$", report):
		def.goals.append(_parse_goal(item, "goals[%d]" % index, report))
		index += 1
	index = 0
	for item: Variant in _array(root, "hazards", "$", report):
		def.hazards.append(_parse_hazard(item, "hazards[%d]" % index, report))
		index += 1
	def.objective = _parse_objective(_dict(root, "objective", "$", report), report)
	index = 0
	for item: Variant in _array(root, "known_sequences", "$", report):
		def.known_sequences.append(_parse_sequence(item, "known_sequences[%d]" % index, report))
		index += 1

	if report.is_ok():
		result.definition = def
	return result


static func _parse_wall(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Wall:
	var wall: LevelDefinition.Wall = LevelDefinition.Wall.new()
	var data: Dictionary = _dict_value(item, path, report)
	var kind_value: Variant = data.get("kind", "")
	var is_polygon: bool = typeof(kind_value) == TYPE_STRING and kind_value == LevelSchema.WALL_KIND_POLYGON
	_check_keys(data, POLYGON_KEYS if is_polygon else POLYLINE_KEYS, path, report)
	wall.id = _string(data, "id", path, report)
	wall.kind = _string(data, "kind", path, report)
	if not is_polygon:
		wall.thickness = _number(data, "thickness", path, report)
	var points: PackedVector2Array = PackedVector2Array()
	var raw_points: Array = _array(data, "points", path, report)
	if raw_points.size() > LevelSchema.MAX_WALL_POINTS:
		# Do not parse an unbounded list; the validator reports the count problem.
		report.add(path + ".points", "count.exceeded", "at most %d points allowed" % LevelSchema.MAX_WALL_POINTS)
	else:
		var point_index: int = 0
		for raw_point: Variant in raw_points:
			points.append(_vec2_value(raw_point, "%s.points[%d]" % [path, point_index], report))
			point_index += 1
	wall.points = points
	return wall


static func _parse_pin(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Pin:
	var pin: LevelDefinition.Pin = LevelDefinition.Pin.new()
	var data: Dictionary = _dict_value(item, path, report)
	_check_keys(data, PIN_KEYS, path, report)
	pin.id = _string(data, "id", path, report)
	pin.tip = _vec2(data, "tip", path, report)
	pin.handle = _vec2(data, "handle", path, report)
	pin.thickness = _number(data, "thickness", path, report)
	pin.pull_direction = _vec2(data, "pull_direction", path, report)
	pin.pull_distance = _number(data, "pull_distance", path, report)
	return pin


static func _parse_spawn(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Spawn:
	var spawn: LevelDefinition.Spawn = LevelDefinition.Spawn.new()
	var data: Dictionary = _dict_value(item, path, report)
	_check_keys(data, SPAWN_KEYS, path, report)
	spawn.id = _string(data, "id", path, report)
	spawn.material = _string(data, "material", path, report)
	spawn.position = _vec2(data, "position", path, report)
	return spawn


static func _parse_goal(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Goal:
	var goal: LevelDefinition.Goal = LevelDefinition.Goal.new()
	var data: Dictionary = _dict_value(item, path, report)
	_check_keys(data, GOAL_KEYS, path, report)
	goal.id = _string(data, "id", path, report)
	goal.kind = _string(data, "kind", path, report)
	goal.rect = _rect(data, "rect", path, report)
	goal.accepts = _string_list(data, "accepts", path, report)
	goal.is_protected = _bool(data, "protected", path, report)
	return goal


static func _parse_hazard(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Hazard:
	var hazard: LevelDefinition.Hazard = LevelDefinition.Hazard.new()
	var data: Dictionary = _dict_value(item, path, report)
	_check_keys(data, HAZARD_KEYS, path, report)
	hazard.id = _string(data, "id", path, report)
	hazard.kind = _string(data, "kind", path, report)
	hazard.rect = _rect(data, "rect", path, report)
	hazard.affects = _string_list(data, "affects", path, report)
	return hazard


static func _parse_objective(data: Dictionary, report: ValidationReport) -> LevelDefinition.Objective:
	var objective: LevelDefinition.Objective = LevelDefinition.Objective.new()
	_check_keys(data, OBJECTIVE_KEYS, "objective", report)
	objective.required_tokens = _int(data, "required_tokens", "objective", report)
	objective.allowed_token_losses = _int(data, "allowed_token_losses", "objective", report)
	objective.collector_ids = _string_list(data, "collector_ids", "objective", report)
	objective.fail_conditions = _string_list(data, "fail_conditions", "objective", report)
	return objective


static func _parse_sequence(item: Variant, path: String, report: ValidationReport) -> LevelDefinition.Sequence:
	var sequence: LevelDefinition.Sequence = LevelDefinition.Sequence.new()
	var data: Dictionary = _dict_value(item, path, report)
	_check_keys(data, SEQUENCE_KEYS, path, report)
	sequence.id = _string(data, "id", path, report)
	sequence.actions = _string_list(data, "actions", path, report)
	sequence.expected_result = _string(data, "expected_result", path, report)
	return sequence


# ---------------------------------------------------------------------------
# Serialising
# ---------------------------------------------------------------------------

## Plain Dictionary form of a definition, ready for JSON.stringify.
static func to_dict(def: LevelDefinition) -> Dictionary:
	var walls: Array = []
	for wall: LevelDefinition.Wall in def.walls:
		var points: Array = []
		for point: Vector2 in wall.points:
			points.append(_vec_out(point))
		var wall_data: Dictionary = {"id": wall.id, "kind": wall.kind, "points": points}
		if wall.kind != LevelSchema.WALL_KIND_POLYGON:
			wall_data["thickness"] = _num_out(wall.thickness)
		walls.append(wall_data)
	var pins: Array = []
	for pin: LevelDefinition.Pin in def.pins:
		pins.append({
			"id": pin.id, "tip": _vec_out(pin.tip), "handle": _vec_out(pin.handle),
			"thickness": _num_out(pin.thickness), "pull_direction": _vec_out(pin.pull_direction),
			"pull_distance": _num_out(pin.pull_distance),
		})
	var spawns: Array = []
	for spawn: LevelDefinition.Spawn in def.spawns:
		spawns.append({"id": spawn.id, "material": spawn.material, "position": _vec_out(spawn.position)})
	var goals: Array = []
	for goal: LevelDefinition.Goal in def.goals:
		goals.append({
			"id": goal.id, "kind": goal.kind, "rect": _rect_out(goal.rect),
			"accepts": _strings_out(goal.accepts), "protected": goal.is_protected,
		})
	var hazards: Array = []
	for hazard: LevelDefinition.Hazard in def.hazards:
		hazards.append({
			"id": hazard.id, "kind": hazard.kind, "rect": _rect_out(hazard.rect),
			"affects": _strings_out(hazard.affects),
		})
	var sequences: Array = []
	for sequence: LevelDefinition.Sequence in def.known_sequences:
		sequences.append({
			"id": sequence.id, "actions": _strings_out(sequence.actions),
			"expected_result": sequence.expected_result,
		})
	return {
		"schema_version": def.schema_version,
		"level_id": def.level_id,
		"title": def.title,
		"sim_config_version": def.sim_config_version,
		"meta": {
			"author": def.meta.author, "created": def.meta.created,
			"source": def.meta.source, "notes": def.meta.notes,
		},
		"design_size": _vec_out(def.design_size),
		"allowed_mechanics": _strings_out(def.allowed_mechanics),
		"walls": walls,
		"pins": pins,
		"spawns": spawns,
		"goals": goals,
		"hazards": hazards,
		"objective": {
			"required_tokens": def.objective.required_tokens,
			"allowed_token_losses": def.objective.allowed_token_losses,
			"collector_ids": _strings_out(def.objective.collector_ids),
			"fail_conditions": _strings_out(def.objective.fail_conditions),
		},
		"known_sequences": sequences,
	}


## Canonical JSON text: sorted keys, tab indent, trailing newline. Same definition in,
## same bytes out.
static func to_json_text(def: LevelDefinition) -> String:
	return JSON.stringify(to_dict(def), "\t", true) + "\n"


## Independent deep copy (through plain data, so nothing is shared with the original).
## Returns null if the definition cannot round-trip (it was not structurally valid).
static func clone(def: LevelDefinition) -> LevelDefinition:
	return from_variant(to_dict(def)).definition


# ---------------------------------------------------------------------------
# Typed field readers. Each records an issue and returns a harmless default on error.
# ---------------------------------------------------------------------------

static func _check_keys(data: Dictionary, allowed: PackedStringArray, path: String, report: ValidationReport) -> void:
	for key: Variant in data.keys():
		if typeof(key) != TYPE_STRING or not allowed.has(key as String):
			report.add(path, "key.unknown", "unknown key '%s'" % str(key).left(40))


static func _dict(data: Dictionary, key: String, path: String, report: ValidationReport) -> Dictionary:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return {}
	return _dict_value(data[key], _join(path, key), report)


static func _dict_value(value: Variant, path: String, report: ValidationReport) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		report.add(path, "type.mismatch", "expected an object")
		return {}
	return value as Dictionary


static func _array(data: Dictionary, key: String, path: String, report: ValidationReport) -> Array:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return []
	var value: Variant = data[key]
	if typeof(value) != TYPE_ARRAY:
		report.add(_join(path, key), "type.mismatch", "expected an array")
		return []
	var items: Array = value as Array
	return items


static func _string(data: Dictionary, key: String, path: String, report: ValidationReport, required: bool = true) -> String:
	if not data.has(key):
		if required:
			report.add(path, "key.missing", "missing '%s'" % key)
		return ""
	var value: Variant = data[key]
	if typeof(value) != TYPE_STRING:
		report.add(_join(path, key), "type.mismatch", "expected a string")
		return ""
	return value as String


static func _bool(data: Dictionary, key: String, path: String, report: ValidationReport) -> bool:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return false
	var value: Variant = data[key]
	if typeof(value) != TYPE_BOOL:
		report.add(_join(path, key), "type.mismatch", "expected true or false")
		return false
	return value as bool


## Numbers may arrive as int or float (JSON has one number type). Non-finite values are
## kept so the validator can report them with a precise path.
static func _number(data: Dictionary, key: String, path: String, report: ValidationReport) -> float:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return 0.0
	return _number_value(data[key], _join(path, key), report)


static func _number_value(value: Variant, path: String, report: ValidationReport) -> float:
	var kind: int = typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		report.add(path, "type.mismatch", "expected a number")
		return 0.0
	return float(value)


static func _int(data: Dictionary, key: String, path: String, report: ValidationReport) -> int:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return 0
	var number: float = _number_value(data[key], _join(path, key), report)
	if not is_finite(number) or number != floorf(number) or absf(number) > 1000000000.0:
		report.add(_join(path, key), "type.mismatch", "expected a whole number")
		return 0
	return int(number)


static func _vec2(data: Dictionary, key: String, path: String, report: ValidationReport) -> Vector2:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return Vector2.ZERO
	return _vec2_value(data[key], _join(path, key), report)


static func _vec2_value(value: Variant, path: String, report: ValidationReport) -> Vector2:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		report.add(path, "type.mismatch", "expected [x, y]")
		return Vector2.ZERO
	var pair: Array = value as Array
	return Vector2(_number_value(pair[0], path + "[0]", report), _number_value(pair[1], path + "[1]", report))


static func _rect(data: Dictionary, key: String, path: String, report: ValidationReport) -> Rect2:
	if not data.has(key):
		report.add(path, "key.missing", "missing '%s'" % key)
		return Rect2()
	var value: Variant = data[key]
	var rect_path: String = _join(path, key)
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 4:
		report.add(rect_path, "type.mismatch", "expected [x, y, width, height]")
		return Rect2()
	var quad: Array = value as Array
	return Rect2(
		_number_value(quad[0], rect_path + "[0]", report), _number_value(quad[1], rect_path + "[1]", report),
		_number_value(quad[2], rect_path + "[2]", report), _number_value(quad[3], rect_path + "[3]", report)
	)


static func _string_list(data: Dictionary, key: String, path: String, report: ValidationReport) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var items: Array = _array(data, key, path, report)
	if items.size() > LevelSchema.MAX_LIST_ENTRIES:
		report.add(_join(path, key), "count.exceeded", "at most %d entries allowed" % LevelSchema.MAX_LIST_ENTRIES)
		return result
	var index: int = 0
	for item: Variant in items:
		if typeof(item) != TYPE_STRING:
			report.add("%s[%d]" % [_join(path, key), index], "type.mismatch", "expected a string")
		else:
			result.append(item as String)
		index += 1
	return result


static func _join(path: String, key: String) -> String:
	return key if path == "$" else "%s.%s" % [path, key]


# --- output helpers ---

static func _num_out(value: float) -> float:
	return snappedf(value, LevelSchema.COORD_DECIMALS)


static func _vec_out(value: Vector2) -> Array:
	return [_num_out(value.x), _num_out(value.y)]


static func _rect_out(value: Rect2) -> Array:
	return [_num_out(value.position.x), _num_out(value.position.y), _num_out(value.size.x), _num_out(value.size.y)]


static func _strings_out(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
