class_name SimWorld
extends Node2D
## The live physics world for one LevelInstance: static walls and pins plus dynamic brass tokens.
##
## Everything here uses Godot's real 2D physics, stepped by the engine at the fixed tick rate.
## Nothing moves a body by setting its transform. Scrap and cores are not simulated yet (their
## rules arrive in Prompt 06) and pins are immovable until Prompt 04.
##
## The node sits at the origin and ignores its parent's transform (`top_level`), so physics
## coordinates are design coordinates. Scaling the board to the window is purely presentation.
## Presentation reads this node (positions, ids, velocities) and never writes to it.
## Sim layer: Nodes allowed, no UI.

## Sync order: after other physics-process nodes, so reads see the latest settled state.
const PROCESS_PRIORITY: int = 1000

## Project settings that define the world and must equal SimConfig. Checked on every build,
## because a hand-edited project file would otherwise silently change every outcome.
const WORLD_SETTINGS: Array[String] = [
	"physics/common/physics_ticks_per_second",
	"physics/2d/default_gravity",
	"physics/2d/default_gravity_vector",
	"physics/2d/sleep_threshold_linear",
	"physics/2d/sleep_threshold_angular",
	"physics/2d/time_before_sleep",
	"physics/2d/solver/solver_iterations",
]

## The tuning used by this world.
var tuning: SimTuning = null

## The instance this world was built from. Token positions are copied back into its material
## records every tick so the records always show where each token is.
var instance: LevelInstance = null

## Number of physics ticks processed since the world entered the tree.
var tick_count: int = 0

## Why the last build() was refused, empty when it succeeded.
var build_problems: PackedStringArray = PackedStringArray()

var _tokens: Array[TokenBody] = []
var _statics: Array[StaticPartBody] = []
var _token_by_id: Dictionary[String, TokenBody] = {}
var _records: Array[LevelInstance.MaterialState] = []


func _init() -> void:
	top_level = true
	process_physics_priority = PROCESS_PRIORITY


## Builds the bodies. Returns false (and fills build_problems) instead of building a partial or
## unsafe world. May be called once per node; call it before or after adding the node to the tree.
func build(level_instance: LevelInstance, tuning_override: SimTuning = null) -> bool:
	build_problems = PackedStringArray()
	if level_instance == null:
		build_problems.append("no level instance")
	if instance != null:
		build_problems.append("this world was already built")
	if not build_problems.is_empty():
		return false
	tuning = tuning_override if tuning_override != null else SimTuning.new()
	build_problems.append_array(settings_mismatches())

	var token_count: int = level_instance.definition.count_spawns(LevelSchema.MATERIAL_TOKEN)
	if token_count > tuning.max_dynamic_bodies:
		build_problems.append("%d tokens exceed the limit of %d dynamic bodies" % [token_count, tuning.max_dynamic_bodies])
	if not build_problems.is_empty():
		return false

	var def: LevelDefinition = level_instance.definition
	for wall: LevelDefinition.Wall in def.walls:
		var colliders: Array[BoardColliders.Collider] = BoardColliders.for_wall(wall)
		if colliders.is_empty():
			build_problems.append("wall %s produced no collision shapes" % wall.id)
			continue
		_add_static(wall.id, StaticPartBody.KIND_WALL, SimConfig.LAYER_WALL, colliders)
	for pin: LevelDefinition.Pin in def.pins:
		_add_static(pin.id, StaticPartBody.KIND_PIN, SimConfig.LAYER_PIN, BoardColliders.for_pin(pin))
	if not build_problems.is_empty():
		_discard_bodies()
		return false

	instance = level_instance
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = tuning.token_friction
	material.bounce = tuning.token_bounce
	var shapes: Dictionary[float, CircleShape2D] = {}
	for record: LevelInstance.MaterialState in level_instance.materials:
		if record.kind != LevelSchema.MATERIAL_TOKEN:
			continue
		if not shapes.has(record.radius):
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = record.radius
			shapes[record.radius] = circle
		_add_token(record, shapes[record.radius], material)
	return true


## All tokens in spawn order.
func tokens() -> Array[TokenBody]:
	return _tokens


## All static parts (walls first, then pins), in definition order.
func static_parts() -> Array[StaticPartBody]:
	return _statics


func token_count() -> int:
	return _tokens.size()


## The token body for a material id, or null.
func token_body(material_id: String) -> TokenBody:
	return _token_by_id.get(material_id) as TokenBody


## The static body for a wall or pin id, or null.
func static_part(part_id: String) -> StaticPartBody:
	for part: StaticPartBody in _statics:
		if part.part_id == part_id:
			return part
	return null


## Number of tokens that are awake (still being simulated).
func awake_token_count() -> int:
	var total: int = 0
	for body: TokenBody in _tokens:
		if not body.sleeping:
			total += 1
	return total


## True when every token is asleep. Settling rules proper arrive in Prompt 04.
func all_tokens_asleep() -> bool:
	return awake_token_count() == 0


## Speed of the fastest token right now, units per second.
func fastest_token_speed() -> float:
	var fastest: float = 0.0
	for body: TokenBody in _tokens:
		fastest = maxf(fastest, body.linear_velocity.length())
	return fastest


## Fastest speed any token has had at the start of a tick, before the speed limit applied.
func peak_token_speed() -> float:
	var peak: float = 0.0
	for body: TokenBody in _tokens:
		peak = maxf(peak, body.peak_speed)
	return peak


## Ids of tokens whose centre is outside the board rectangle grown by `margin`. A diagnostic for
## tests and the overlay; deciding that a token is lost is a rule (Prompt 05), not done here.
func tokens_outside_board(margin: float = 0.0) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var bounds: Rect2 = Rect2(Vector2.ZERO, instance.definition.design_size).grow(margin)
	for body: TokenBody in _tokens:
		if not bounds.has_point(body.position):
			result.append(body.material_id)
	return result


## Exact text of every token's position, velocity and sleep flag. Equal text means an identical
## world; used to compare repeated runs (same machine and build only).
func state_signature() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for body: TokenBody in _tokens:
		lines.append("%s %.4f,%.4f v %.4f,%.4f a %.4f %s" % [
			body.material_id, body.position.x, body.position.y,
			body.linear_velocity.x, body.linear_velocity.y, body.rotation, str(body.sleeping),
		])
	return "\n".join(lines)


## Names of project settings whose value differs from SimConfig. Empty means the world is as
## documented.
static func settings_mismatches() -> PackedStringArray:
	var expected: Dictionary = {
		"physics/common/physics_ticks_per_second": SimConfig.TICK_RATE,
		"physics/2d/default_gravity": SimConfig.GRAVITY,
		"physics/2d/default_gravity_vector": Vector2.DOWN,
		"physics/2d/sleep_threshold_linear": SimConfig.SLEEP_LINEAR_THRESHOLD,
		"physics/2d/sleep_threshold_angular": SimConfig.SLEEP_ANGULAR_THRESHOLD,
		"physics/2d/time_before_sleep": SimConfig.TIME_BEFORE_SLEEP,
		"physics/2d/solver/solver_iterations": SimConfig.SOLVER_ITERATIONS,
	}
	var problems: PackedStringArray = PackedStringArray()
	for key: String in WORLD_SETTINGS:
		var actual: Variant = ProjectSettings.get_setting(key)
		var wanted: Variant = expected[key]
		var same: bool = false
		if actual is float or wanted is float:
			same = is_equal_approx(float(actual), float(wanted))
		else:
			same = actual == wanted
		if not same:
			problems.append("project setting %s is %s but SimConfig expects %s" % [key, str(actual), str(wanted)])
	return problems


func _physics_process(_delta: float) -> void:
	tick_count += 1
	for index: int in _tokens.size():
		_records[index].position = _tokens[index].position


func _add_static(part_id: String, kind: String, layer: int, colliders: Array[BoardColliders.Collider]) -> void:
	var body: StaticPartBody = StaticPartBody.new()
	body.name = part_id.replace(".", "_")
	body.part_id = part_id
	body.part_kind = kind
	body.collision_layer = layer
	body.collision_mask = 0
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = tuning.wall_friction
	material.bounce = tuning.wall_bounce
	body.physics_material_override = material
	for collider: BoardColliders.Collider in colliders:
		var node: CollisionShape2D = CollisionShape2D.new()
		node.shape = collider.shape
		node.transform = collider.transform
		body.add_child(node)
	add_child(body)
	_statics.append(body)


func _add_token(record: LevelInstance.MaterialState, circle: CircleShape2D, material: PhysicsMaterial) -> void:
	var body: TokenBody = TokenBody.new()
	body.name = record.id.replace(".", "_")
	body.material_id = record.id
	body.max_speed = tuning.max_token_speed
	body.mass = tuning.token_mass
	body.physics_material_override = material
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp = tuning.token_linear_damp
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp = tuning.token_angular_damp
	body.continuous_cd = tuning.token_ccd_mode as RigidBody2D.CCDMode
	body.collision_layer = SimConfig.LAYER_TOKEN
	body.collision_mask = SimConfig.LAYER_WALL | SimConfig.LAYER_PIN | SimConfig.LAYER_TOKEN
	body.position = record.position
	var node: CollisionShape2D = CollisionShape2D.new()
	node.shape = circle
	body.add_child(node)
	add_child(body)
	_tokens.append(body)
	_records.append(record)
	_token_by_id[record.id] = body


func _discard_bodies() -> void:
	for part: StaticPartBody in _statics:
		remove_child(part)
		part.free()
	_statics.clear()
