class_name PhysicsScenarios
extends RefCounted
## Builders for physics test levels: tall drop shafts, V troughs, ramps, funnels, bowls and
## corners. Every level is built as plain data and passed through the real loader and validator,
## so a scenario that breaks a schema rule fails loudly instead of testing something unreal.
## Spawn jitter uses a caller-supplied seeded generator, never the gameplay or cosmetic RNG.

const TOKEN_RADIUS: float = 14.0
const TOKEN_DIAMETER: float = 28.0

## Problems from the most recent level() call, so a failing scenario can say why.
static var last_report: ValidationReport = ValidationReport.new()


## Wraps walls and spawns into a complete, validated level. Returns null if validation fails;
## `report_out` receives the problems.
static func level(level_id: String, size: Vector2, walls: Array, spawns: Array, report_out: ValidationReport = null) -> LevelDefinition:
	var token_count: int = 0
	for spawn: Variant in spawns:
		if (spawn as Dictionary)["material"] == LevelSchema.MATERIAL_TOKEN:
			token_count += 1
	var data: Dictionary = {
		"schema_version": 1,
		"level_id": level_id,
		"title": level_id,
		"sim_config_version": SimConfig.CONFIG_VERSION,
		"meta": {"author": "Physics test", "created": "2026-11-17", "source": "handcrafted", "notes": ""},
		"design_size": [size.x, size.y],
		"allowed_mechanics": [],
		"walls": walls,
		"pins": [],
		"spawns": spawns,
		"goals": [{"id": "goal.collector", "kind": "collector", "rect": [4.0, size.y - 44.0, 40.0, 40.0], "accepts": ["token"], "protected": false}],
		"hazards": [],
		"objective": {"required_tokens": maxi(1, token_count), "allowed_token_losses": 0, "collector_ids": ["goal.collector"], "fail_conditions": []},
		"known_sequences": [],
	}
	var result: LevelLoader.LoadResult = LevelFixtures.check(data)
	last_report = result.report
	if report_out != null:
		report_out.merge(result.report)
	return result.definition if result.is_ok() else null


static func polyline(wall_id: String, thickness: float, points: Array) -> Dictionary:
	var raw: Array = []
	for point: Vector2 in points:
		raw.append([point.x, point.y])
	return {"id": wall_id, "kind": "polyline", "thickness": thickness, "points": raw}


static func polygon(wall_id: String, points: Array) -> Dictionary:
	var raw: Array = []
	for point: Vector2 in points:
		raw.append([point.x, point.y])
	return {"id": wall_id, "kind": "polygon", "points": raw}


static func token(token_id: String, position: Vector2) -> Dictionary:
	return {"id": token_id, "material": "token", "position": [position.x, position.y]}


## `columns` x `rows` tokens, `spacing` apart, top-left at `origin`. Each position is moved by up
## to `jitter` in x and y using `rng` (pass null for none). `phase_step` lowers each token a
## little more than the one before, so tokens dropped from one height hit a wall at different
## points within a tick (equal heights would test only one phase). Ids are token.1, token.2, ...
static func token_grid(origin: Vector2, columns: int, rows: int, spacing: float, jitter: float = 0.0, rng: RandomNumberGenerator = null, phase_step: float = 0.0) -> Array:
	var spawns: Array = []
	var number: int = 1
	for row: int in rows:
		for column: int in columns:
			var at: Vector2 = origin + Vector2(float(column), float(row)) * spacing + Vector2(0.0, float(number - 1) * phase_step)
			if rng != null and jitter > 0.0:
				at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
			spawns.append(token("token.%d" % number, at))
			number += 1
	return spawns


# --- Drop shafts: tokens fall a long way onto thin floors, to test tunnelling ---

const SHAFT_SIZE: Vector2 = Vector2(720.0, 4096.0)
const SHAFT_FLOOR_Y: float = 4000.0

## Each token in a shaft starts this much lower than the one before (see token_grid). A token
## moves about 16.7 units per tick at the speed limit, so ten tokens cover the whole tick.
const PHASE_STEP: float = 1.7

## Tokens released at the top of a 4096-unit-tall board fall onto a flat floor of the given
## thickness. Falling that far with no speed limit reaches about 2800 units per second.
static func flat_floor_shaft(thickness: float, tokens: int = 10) -> LevelDefinition:
	var walls: Array = [polyline("wall.floor", thickness, [Vector2(40.0, SHAFT_FLOOR_Y), Vector2(680.0, SHAFT_FLOOR_Y)])]
	var spawns: Array = token_grid(Vector2(60.0, 80.0), tokens, 1, 60.0, 0.0, null, PHASE_STEP)
	return level("test.flat_floor", SHAFT_SIZE, walls, spawns)


## Same drop, but into a V trough (two sloped capsules) so the impact is oblique and the
## tokens are contained if nothing tunnels. `thickness` applies to both sides.
static func v_trough_shaft(thickness: float, tokens: int = 10) -> LevelDefinition:
	var walls: Array = [
		polyline("wall.left", thickness, [Vector2(40.0, 3700.0), Vector2(360.0, 4000.0)]),
		polyline("wall.right", thickness, [Vector2(680.0, 3700.0), Vector2(360.0, 4000.0)]),
	]
	var spawns: Array = token_grid(Vector2(120.0, 80.0), tokens, 1, 50.0, 0.0, null, PHASE_STEP)
	return level("test.v_trough", SHAFT_SIZE, walls, spawns)


## A thin solid plate (polygon wall) under the drop. Polygons have no minimum thickness in the
## schema, only a minimum area, so thin plates are legal data.
static func plate_shaft(plate_thickness: float, tokens: int = 10) -> LevelDefinition:
	var plate_length: float = maxf(600.0, 400.0 / plate_thickness + 10.0)
	var left: float = 360.0 - plate_length * 0.5
	var right: float = 360.0 + plate_length * 0.5
	var top: float = SHAFT_FLOOR_Y - plate_thickness * 0.5
	var bottom: float = SHAFT_FLOOR_Y + plate_thickness * 0.5
	var walls: Array = [polygon("wall.plate", [Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])]
	var spawns: Array = token_grid(Vector2(maxf(60.0, left + 20.0), 80.0), tokens, 1, 50.0, 0.0, null, PHASE_STEP)
	return level("test.plate", SHAFT_SIZE, walls, spawns)


## A thin solid wedge (polygon wall) under the drop: flat top at SHAFT_FLOOR_Y, tapering from
## `thick_end` units thick at its right edge to a point at its left. Legal data when its edges
## are at least 4 long and its area at least 400. `tokens` fall at `x_offset` plus a 24-unit
## pitch across the wedge, so every part of the taper is hit over a few offsets.
static func wedge_shaft(thick_end: float, length: float, tokens: int, x_offset: float) -> LevelDefinition:
	var left: float = 360.0 - length * 0.5
	var right: float = left + length
	var top: float = SHAFT_FLOOR_Y
	var walls: Array = [polygon("wall.wedge", [Vector2(left, top), Vector2(right, top), Vector2(right, top + thick_end)])]
	var spawns: Array = []
	for index: int in tokens:
		spawns.append(token("token.%d" % (index + 1), Vector2(left + x_offset + float(index) * 30.0, 80.0 + float(index) * PHASE_STEP)))
	return level("test.wedge", SHAFT_SIZE, walls, spawns)


# --- Ramps, funnels, bowls and corners: flow tests on a normal-size board ---

const BOARD_SIZE: Vector2 = Vector2(1600.0, 1000.0)
const RAMP_START: Vector2 = Vector2(160.0, 200.0)
const RAMP_LENGTH: float = 700.0
const RAMP_THICKNESS: float = 24.0

## A straight ramp at `angle_degrees` below horizontal with a stop wall at its upper end and a
## floor under its lower end. Tokens start resting on the ramp near the top. Flowing means every
## token passes the ramp's lower end. Returns the level; use ramp_end() for the finish line.
static func ramp(angle_degrees: float, tokens: int = 5, jitter: float = 0.0, rng: RandomNumberGenerator = null) -> LevelDefinition:
	var direction: Vector2 = Vector2.from_angle(deg_to_rad(angle_degrees))
	var up: Vector2 = Vector2(direction.y, -direction.x)  # unit normal pointing up and away
	var end: Vector2 = RAMP_START + direction * RAMP_LENGTH
	var walls: Array = [
		polyline("wall.ramp", RAMP_THICKNESS, [RAMP_START, end]),
		polyline("wall.stop", RAMP_THICKNESS, [RAMP_START + Vector2(-RAMP_THICKNESS * 0.5, -120.0), RAMP_START + Vector2(-RAMP_THICKNESS * 0.5, 0.0)]),
		polyline("wall.floor", 24.0, [Vector2(40.0, 960.0), Vector2(1560.0, 960.0)]),
	]
	var spawns: Array = []
	var lift: float = RAMP_THICKNESS * 0.5 + TOKEN_RADIUS + LevelSchema.SPAWN_GAP + 2.0
	for index: int in tokens:
		# Tokens are 40 apart along the slope. Jitter slides them along the slope and lifts them
		# away from it, never toward it, so the legal clearance to the ramp always holds.
		var along: float = 40.0 + float(index) * 40.0
		var away: float = lift
		if rng != null and jitter > 0.0:
			along += rng.randf_range(-jitter, jitter)
			away += rng.randf_range(0.0, jitter)
		spawns.append(token("token.%d" % (index + 1), RAMP_START + direction * along + up * away))
	return level("test.ramp", BOARD_SIZE, walls, spawns)


## Where the ramp for `angle_degrees` ends.
static func ramp_end(angle_degrees: float) -> Vector2:
	return RAMP_START + Vector2.from_angle(deg_to_rad(angle_degrees)) * RAMP_LENGTH


const FUNNEL_TOP_Y: float = 300.0
const FUNNEL_BOTTOM_Y: float = 560.0
const FUNNEL_CENTER_X: float = 600.0

## A hopper: two walls slope inward to a gap of `opening` units, with straight walls above. A
## block of tokens starts in the hopper. Tokens that fall through land in a closed tray below.
## Flowing means every token ends below FUNNEL_BOTTOM_Y.
static func funnel(opening: float, tokens: int, jitter: float = 0.0, rng: RandomNumberGenerator = null) -> LevelDefinition:
	var half: float = opening * 0.5
	var walls: Array = [
		polyline("wall.hopper_left", 24.0, [Vector2(FUNNEL_CENTER_X - 300.0, 60.0), Vector2(FUNNEL_CENTER_X - 300.0, FUNNEL_TOP_Y), Vector2(FUNNEL_CENTER_X - half - 12.0, FUNNEL_BOTTOM_Y)]),
		polyline("wall.hopper_right", 24.0, [Vector2(FUNNEL_CENTER_X + 300.0, 60.0), Vector2(FUNNEL_CENTER_X + 300.0, FUNNEL_TOP_Y), Vector2(FUNNEL_CENTER_X + half + 12.0, FUNNEL_BOTTOM_Y)]),
		polyline("wall.tray", 24.0, [Vector2(FUNNEL_CENTER_X - 300.0, 900.0), Vector2(FUNNEL_CENTER_X + 300.0, 900.0)]),
		polyline("wall.tray_left", 24.0, [Vector2(FUNNEL_CENTER_X - 300.0, 700.0), Vector2(FUNNEL_CENTER_X - 300.0, 900.0)]),
		polyline("wall.tray_right", 24.0, [Vector2(FUNNEL_CENTER_X + 300.0, 700.0), Vector2(FUNNEL_CENTER_X + 300.0, 900.0)]),
	]
	# 12 columns 40 apart and rows 38 apart; jitter of 3 keeps every pair at least 32 apart.
	var columns: int = 12
	var spawns: Array = []
	for index: int in tokens:
		var at: Vector2 = Vector2(FUNNEL_CENTER_X - 220.0 + float(index % columns) * 40.0, FUNNEL_TOP_Y - 30.0 - float(index / columns) * 38.0)
		if rng != null and jitter > 0.0:
			at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		spawns.append(token("token.%d" % (index + 1), at))
	return level("test.funnel", Vector2(1200.0, 1000.0), walls, spawns)


## A closed box with a flat floor and a block of tokens released above it, `columns` wide
## (tokens 40 apart, rows 36 apart; jitter of up to 2 keeps every pair legally clear). The box is
## as wide as the block needs and the board always has 300 units of margin on both sides.
static func bowl(tokens: int, jitter: float = 0.0, rng: RandomNumberGenerator = null, columns: int = 14) -> LevelDefinition:
	var right: float = 330.0 + float(columns - 1) * 40.0 + 50.0
	var walls: Array = [
		polyline("wall.floor", 24.0, [Vector2(300.0, 900.0), Vector2(right, 900.0)]),
		polyline("wall.left", 24.0, [Vector2(300.0, 100.0), Vector2(300.0, 900.0)]),
		polyline("wall.right", 24.0, [Vector2(right, 100.0), Vector2(right, 900.0)]),
	]
	var spawns: Array = []
	for index: int in tokens:
		var at: Vector2 = Vector2(330.0 + float(index % columns) * 40.0, 710.0 - float(index / columns) * 36.0)
		if rng != null and jitter > 0.0:
			at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		spawns.append(token("token.%d" % (index + 1), at))
	return level("test.bowl", Vector2(right + 300.0, 1000.0), walls, spawns)


## Two walls meeting at `angle_degrees` (the corner's inner angle) with tokens dropped in. A
## tight corner can wedge tokens but must never squeeze one through a wall.
static func corner(angle_degrees: float, tokens: int, jitter: float = 0.0, rng: RandomNumberGenerator = null) -> LevelDefinition:
	var apex: Vector2 = Vector2(600.0, 800.0)
	var half: float = deg_to_rad(angle_degrees * 0.5)
	var arm: float = 520.0
	var left: Vector2 = apex + Vector2(-sin(half), -cos(half)) * arm
	var right: Vector2 = apex + Vector2(sin(half), -cos(half)) * arm
	var walls: Array = [
		polyline("wall.arm_left", 16.0, [left, apex]),
		polyline("wall.arm_right", 16.0, [right, apex]),
	]
	var spawns: Array = []
	for index: int in tokens:
		var at: Vector2 = Vector2(apex.x - 20.0 + float(index % 2) * 40.0, apex.y - 330.0 - float(index / 2) * 34.0)
		if rng != null and jitter > 0.0:
			at += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		spawns.append(token("token.%d" % (index + 1), at))
	return level("test.corner", Vector2(1200.0, 1000.0), walls, spawns)
