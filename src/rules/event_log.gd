class_name EventLog
extends RefCounted
## Append-only, bounded record of LevelEvents for one level attempt.
##
## Enforces the one-shot rules of the event contract so later systems cannot double count:
## - at most one terminal event per attempt, and nothing may follow it,
## - each material id may be collected, lost or destroyed only once.
## append() returns false and records the reason in `last_rejection` instead of storing a
## violating event. Create a new EventLog for every attempt (restart).

const MAX_EVENTS: int = 10000

var events: Array[LevelEvent] = []
var last_rejection: String = ""

var _terminal: LevelEvent = null
var _resolved_materials: Dictionary = {}


func append(event: LevelEvent) -> bool:
	if events.size() >= MAX_EVENTS:
		last_rejection = "event log is full"
		return false
	if _terminal != null:
		last_rejection = "attempt already ended with %s" % LevelEvent.type_name(_terminal.type)
		return false
	if event.is_material_resolution():
		if _resolved_materials.has(event.subject_id):
			last_rejection = "material '%s' was already resolved" % event.subject_id
			return false
		_resolved_materials[event.subject_id] = true
	event.sequence = events.size()
	events.append(event)
	if event.is_terminal():
		_terminal = event
	last_rejection = ""
	return true


func has_terminal() -> bool:
	return _terminal != null


func terminal_event() -> LevelEvent:
	return _terminal


func is_material_resolved(material_id: String) -> bool:
	return _resolved_materials.has(material_id)


func count_of(type: LevelEvent.Type) -> int:
	var total: int = 0
	for event: LevelEvent in events:
		if event.type == type:
			total += 1
	return total


func to_dicts() -> Array:
	var result: Array = []
	for event: LevelEvent in events:
		result.append(event.to_dict())
	return result
