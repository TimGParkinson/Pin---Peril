class_name TerminalResult
extends RefCounted
## How a level attempt ended. Names match LevelSchema.TERMINAL_RESULTS (guarded by a test)
## so level data can state expected results for known action sequences.

enum Kind { WON, LOST, JAMMED }


static func to_name(kind: Kind) -> String:
	match kind:
		Kind.WON:
			return "won"
		Kind.LOST:
			return "lost"
		_:
			return "jammed"


## Returns the Kind for a name, or -1 if the name is not a terminal result.
static func from_name(result_name: String) -> int:
	match result_name:
		"won":
			return Kind.WON
		"lost":
			return Kind.LOST
		"jammed":
			return Kind.JAMMED
		_:
			return -1
