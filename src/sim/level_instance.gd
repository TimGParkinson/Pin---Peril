class_name LevelInstance
extends RefCounted
## One playable copy of a level, created fresh from a validated LevelDefinition.
##
## The instance owns an independent deep copy of the definition's geometry, plus the mutable
## starting state (material records, pin pulled flags). Changing an instance never changes
## the source definition or any other instance, so restart always begins from the exact
## authored starting positions. There are no physics bodies yet; Prompt 03 attaches the real
## 2D physics world to these records. Sim layer: no Node access.

enum MaterialStatus { ACTIVE, COLLECTED, LOST, DESTROYED }


class MaterialState:
	extends RefCounted
	var id: String = ""
	var kind: String = ""
	var position: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var status: MaterialStatus = MaterialStatus.ACTIVE


class PinState:
	extends RefCounted
	var id: String = ""
	var pulled: bool = false


## Independent copy of the source definition (read-only by convention).
var definition: LevelDefinition = null
var materials: Array[MaterialState] = []
var pins: Array[PinState] = []

## State signature at creation time, for restart comparisons.
var initial_state_signature: String = ""


## Validates `source` and builds a fresh instance. Returns null if the definition is not
## valid; the problems are appended to `report_out` when one is given.
static func create(source: LevelDefinition, report_out: ValidationReport = null) -> LevelInstance:
	var report: ValidationReport = LevelValidator.validate(source, SimConfig.CONFIG_VERSION)
	if report_out != null:
		report_out.merge(report)
	if not report.is_ok():
		return null
	var copy: LevelDefinition = LevelCodec.clone(source)
	if copy == null:
		return null

	var instance: LevelInstance = LevelInstance.new()
	instance.definition = copy
	for spawn: LevelDefinition.Spawn in copy.spawns:
		var state: MaterialState = MaterialState.new()
		state.id = spawn.id
		state.kind = spawn.material
		state.position = spawn.position
		state.radius = LevelSchema.MATERIAL_RADIUS[spawn.material] as float
		instance.materials.append(state)
	for pin: LevelDefinition.Pin in copy.pins:
		var pin_state: PinState = PinState.new()
		pin_state.id = pin.id
		instance.pins.append(pin_state)
	instance.initial_state_signature = instance.state_signature()
	return instance


func find_material(material_id: String) -> MaterialState:
	for state: MaterialState in materials:
		if state.id == material_id:
			return state
	return null


func find_pin_state(pin_id: String) -> PinState:
	for state: PinState in pins:
		if state.id == pin_id:
			return state
	return null


## Text form of all mutable state: material positions and status, pin pulled flags.
func state_signature() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for state: MaterialState in materials:
		lines.append("material %s %s %.4f,%.4f %s" % [
			state.id, state.kind, state.position.x, state.position.y, MaterialStatus.keys()[state.status],
		])
	for state: PinState in pins:
		lines.append("pin %s pulled %s" % [state.id, str(state.pulled)])
	return "\n".join(lines)


## Signature of the immutable starting geometry (walls, pins, zones, spawn positions).
func geometry_signature() -> String:
	return definition.geometry_signature()
