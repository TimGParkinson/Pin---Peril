class_name LevelEvent
extends RefCounted
## One thing that happened during a level attempt. Live play, replay and tests all produce
## and consume these, so rules never depend on animation or UI.
##
## Event stream contract (rules are implemented in later stages):
## - An action is requested, then either accepted or rejected (with a reason in `detail`).
## - Each material id ends in exactly one of collected, lost or destroyed.
## - An attempt ends with exactly one terminal event: won, lost or jammed.
## `tick` is the fixed physics tick the event happened on. `sequence` is assigned by the
## EventLog and gives a stable total order, including within one tick.
## Rules layer: no Node access.

enum Type {
	ACTION_REQUESTED,
	ACTION_ACCEPTED,
	ACTION_REJECTED,
	MATERIAL_COLLECTED,
	MATERIAL_LOST,
	MATERIAL_DESTROYED,
	LEVEL_WON,
	LEVEL_LOST,
	LEVEL_JAMMED,
}

var type: Type = Type.ACTION_REQUESTED
var tick: int = 0
var sequence: int = -1  # assigned by EventLog.append
## The pin id (action events) or material id (material events). Empty for terminal events.
var subject_id: String = ""
## Pin action: rejection reason. Material: the goal or hazard id involved, or "out_of_bounds".
## Terminal: a short reason code such as "required_tokens_collected".
var detail: String = ""


static func action_requested(at_tick: int, pin_id: String) -> LevelEvent:
	return _make(Type.ACTION_REQUESTED, at_tick, pin_id, "")


static func action_accepted(at_tick: int, pin_id: String) -> LevelEvent:
	return _make(Type.ACTION_ACCEPTED, at_tick, pin_id, "")


static func action_rejected(at_tick: int, pin_id: String, reason: String) -> LevelEvent:
	return _make(Type.ACTION_REJECTED, at_tick, pin_id, reason)


static func material_collected(at_tick: int, material_id: String, goal_id: String) -> LevelEvent:
	return _make(Type.MATERIAL_COLLECTED, at_tick, material_id, goal_id)


static func material_lost(at_tick: int, material_id: String, reason: String) -> LevelEvent:
	return _make(Type.MATERIAL_LOST, at_tick, material_id, reason)


static func material_destroyed(at_tick: int, material_id: String, hazard_id: String) -> LevelEvent:
	return _make(Type.MATERIAL_DESTROYED, at_tick, material_id, hazard_id)


static func level_won(at_tick: int, reason: String) -> LevelEvent:
	return _make(Type.LEVEL_WON, at_tick, "", reason)


static func level_lost(at_tick: int, reason: String) -> LevelEvent:
	return _make(Type.LEVEL_LOST, at_tick, "", reason)


static func level_jammed(at_tick: int, reason: String) -> LevelEvent:
	return _make(Type.LEVEL_JAMMED, at_tick, "", reason)


func is_terminal() -> bool:
	return type == Type.LEVEL_WON or type == Type.LEVEL_LOST or type == Type.LEVEL_JAMMED


func is_material_resolution() -> bool:
	return type == Type.MATERIAL_COLLECTED or type == Type.MATERIAL_LOST or type == Type.MATERIAL_DESTROYED


## The TerminalResult.Kind for a terminal event, or -1 for any other event.
func terminal_kind() -> int:
	match type:
		Type.LEVEL_WON:
			return TerminalResult.Kind.WON
		Type.LEVEL_LOST:
			return TerminalResult.Kind.LOST
		Type.LEVEL_JAMMED:
			return TerminalResult.Kind.JAMMED
		_:
			return -1


static func type_name(event_type: Type) -> String:
	return String(Type.keys()[event_type]).to_lower()


func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"tick": tick,
		"type": type_name(type),
		"subject_id": subject_id,
		"detail": detail,
	}


static func _make(event_type: Type, at_tick: int, subject: String, info: String) -> LevelEvent:
	var event: LevelEvent = LevelEvent.new()
	event.type = event_type
	event.tick = at_tick
	event.subject_id = subject
	event.detail = info
	return event
