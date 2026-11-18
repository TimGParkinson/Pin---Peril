class_name LevelSchema
extends RefCounted
## Constants that define level data format version 1: limits, vocabularies and defaults.
##
## This is the single place that decides what a valid level may contain. Generators, the
## editor and the loader all go through these values. The token radius and the body limit were
## fixed by the physics tuning stage (Prompt 03, measurements in docs/PHYSICS.md); numbers still
## marked PROVISIONAL are fixed when the stage that simulates them arrives. Changing any number
## that alters what is playable bumps the sim config version.
## Data layer: no Node access, no dependency on other layers.

## Version of the on-disk format. Bump on any incompatible change and add a migration.
const SCHEMA_VERSION: int = 1

# --- Bounds and counts (all bounded so hostile or broken data cannot blow up work) ---
const DESIGN_MIN: float = 200.0
const DESIGN_MAX: float = 4096.0
const MAX_WALLS: int = 64
const MAX_WALL_POINTS: int = 256
## Across all walls. Bounds validation work: self-intersection is quadratic per wall and
## spawn clearance is walls times spawns. 64 walls of 256 points measured about 5.5 seconds.
const MAX_TOTAL_WALL_POINTS: int = 1024
const MAX_PINS: int = 16
## Dynamic body ceiling per level. Measured in Prompt 03: 150 bodies cost about 0.9 ms per tick
## on average and 2.4 ms at worst on the development machine. Must equal
## SimConfig.MAX_DYNAMIC_BODIES (a test guards this; the data layer cannot read the sim layer).
const MAX_SPAWNS: int = 150
const MAX_GOALS: int = 8
const MAX_HAZARDS: int = 16
const MAX_SEQUENCES: int = 32
const MAX_MECHANICS: int = 16
const MAX_LIST_ENTRIES: int = 256  # cap for any list of strings read from data
const MAX_ID_LENGTH: int = 64
const MAX_TEXT_LENGTH: int = 200
const MAX_NOTES_LENGTH: int = 1000
const MAX_FILE_BYTES: int = 1048576  # 1 MiB cap when reading level files
const MAX_REPORT_ISSUES: int = 50

# --- Geometry limits, design units ---
const WALL_THICKNESS_MIN: float = 8.0
const WALL_THICKNESS_MAX: float = 64.0
const SEGMENT_MIN_LENGTH: float = 4.0
const POLYGON_MIN_AREA: float = 400.0
const PIN_LENGTH_MIN: float = 40.0
const PIN_LENGTH_MAX: float = 2000.0
const PIN_THICKNESS_MIN: float = 6.0
const PIN_THICKNESS_MAX: float = 32.0
const PIN_GAP: float = 4.0  # minimum clear space between two pins
const PULL_DISTANCE_MAX: float = 4096.0
const DIRECTION_TOLERANCE: float = 0.01  # unit-length and parallel checks
const ZONE_MIN_SIZE: float = 20.0  # smallest goal/hazard rectangle side
const SPAWN_GAP: float = 2.0  # minimum clear space around a spawned body
const COORD_DECIMALS: float = 0.0001  # coordinates are quantised to this when saved

# --- Vocabularies ---
const MATERIAL_TOKEN: String = "token"
const MATERIAL_SCRAP: String = "scrap"
const MATERIAL_CORE: String = "core"

## Radius of each material in design units. Token 14 is final (Prompt 03: 28 units across, about
## 1.75 percent of a 1600 unit board, three diameters fit in a 100 unit opening). Scrap and core
## are PROVISIONAL until they are simulated (Prompt 06).
const MATERIAL_RADIUS: Dictionary = {
	"token": 14.0,
	"scrap": 14.0,
	"core": 16.0,
}

## Mechanic a material needs declared in allowed_mechanics. Tokens are always available.
const MATERIAL_MECHANIC: Dictionary = {
	"scrap": "scrap",
	"core": "hazard_cores",
}

const WALL_KIND_POLYLINE: String = "polyline"
const WALL_KIND_POLYGON: String = "polygon"
const WALL_KINDS: PackedStringArray = ["polyline", "polygon"]

const GOAL_COLLECTOR: String = "collector"
const GOAL_DISPOSAL: String = "disposal"
const GOAL_KINDS: PackedStringArray = ["collector", "disposal"]

const HAZARD_DESTROY_ZONE: String = "destroy_zone"
const HAZARD_KINDS: PackedStringArray = ["destroy_zone"]

## Mechanics that this version can simulate and validate.
const SUPPORTED_MECHANICS: PackedStringArray = [
	"pins", "scrap", "hazard_cores", "disposal_zones", "hazard_zones",
]

## Mechanics that are planned but explicitly NOT supported yet. Rejected, never ignored.
const RESERVED_MECHANICS: PackedStringArray = ["fans", "portals", "rescue_lift", "heater"]

const FAIL_CONDITIONS: PackedStringArray = ["scrap_in_protected", "core_in_protected"]

## Names of terminal results. TerminalResult (rules layer) must match, guarded by a test.
const TERMINAL_RESULTS: PackedStringArray = ["won", "lost", "jammed"]

const SOURCES: PackedStringArray = ["handcrafted", "editor", "generator"]


## True for ids like "pin.a" or "workshop.three_pins": dot separated segments of
## [a-z0-9_], the first character a lowercase letter, at most MAX_ID_LENGTH characters.
static func is_valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_ID_LENGTH:
		return false
	var first: int = value.unicode_at(0)
	if first < 97 or first > 122:
		return false
	var previous_was_dot: bool = false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if code == 46:  # "."
			if previous_was_dot or index == value.length() - 1:
				return false
			previous_was_dot = true
			continue
		previous_was_dot = false
		if not (is_lower or is_digit or code == 95):  # "_"
			return false
	return true


## True for YYYY-MM-DD with a plausible month and day.
static func is_valid_date(value: String) -> bool:
	if value.length() != 10 or value[4] != "-" or value[7] != "-":
		return false
	var digits: String = value.replace("-", "")
	if not digits.is_valid_int():
		return false
	var month: int = value.substr(5, 2).to_int()
	var day: int = value.substr(8, 2).to_int()
	return month >= 1 and month <= 12 and day >= 1 and day <= 31
