class_name SimConfig
extends RefCounted
## Fixed-step simulation constants shared by live play and (later) headless replay.
##
## Changing any value here changes physics outcomes. Bump CONFIG_VERSION and
## revalidate every known solution (see docs/ARCHITECTURE.md, "Versioning"). The measurements
## behind these numbers are in docs/PHYSICS.md. Units are design units (1 unit = 1 pixel of the
## 1920x1080 design space) and seconds.

## Version of the simulation rules and tuning. Recorded with every replay result.
## 1 = no physics yet (Prompt 02). 2 = first physics tuning (Prompt 03).
const CONFIG_VERSION: int = 2

## Fixed physics ticks per second. Must equal project setting
## physics/common/physics_ticks_per_second (checked by tests/domain/test_project_config.gd).
const TICK_RATE: int = 60

## Seconds per fixed tick.
const TICK_DELTA: float = 1.0 / 60.0

# --- World. Mirrored in project.godot and guarded by tests/domain/test_project_config.gd ---

## Gravity, design units per second squared, pointing down the screen.
const GRAVITY: float = 1000.0

## Rigid bodies fall asleep when slower than this (units per second) for TIME_BEFORE_SLEEP.
const SLEEP_LINEAR_THRESHOLD: float = 2.0

## Sleep angular threshold in radians per second (8 degrees per second).
const SLEEP_ANGULAR_THRESHOLD: float = 0.13962634015955

## Seconds below both thresholds before a body sleeps.
const TIME_BEFORE_SLEEP: float = 0.5

## Constraint solver iterations per tick. More iterations make piles steadier and cost time.
const SOLVER_ITERATIONS: int = 16

# --- Collision layers (bit values). Walls and pins are static, tokens are the dynamic bodies ---
const LAYER_WALL: int = 1
const LAYER_PIN: int = 2
const LAYER_TOKEN: int = 4

# --- Brass token. Radius lives in LevelSchema.MATERIAL_RADIUS (it also drives spawn validation) ---

## Relative mass. Only ratios matter between bodies; every token weighs the same.
const TOKEN_MASS: float = 1.0
const TOKEN_FRICTION: float = 0.4
const TOKEN_BOUNCE: float = 0.15

## Godot damping multiplies velocity by (1 - damp / tick rate) each tick. Both are set per body
## and replace the project and area defaults, so nothing else can change how tokens move.
const TOKEN_LINEAR_DAMP: float = 0.05
const TOKEN_ANGULAR_DAMP: float = 1.0

## Speed limit for tokens, units per second (0 would disable it). Enforced inside the physics
## step, so it is part of the simulation, not a visual trick. It is defense in depth, not the
## tunnelling fix (ray CCD is): with CCD on, no tunnelling was seen even with no limit. It is kept
## because it holds a token's travel to under one diameter per tick (16.7 against 28), which the
## token-against-token contact relies on, and it stops tokens becoming invisible streaks on a
## tall board. Without CCD, 8 unit polylines tunnel from about 1100 (docs/PHYSICS.md).
const MAX_TOKEN_SPEED: float = 1000.0

## Continuous collision detection for tokens: ray mode. Observed tunnelling justifies it: even at
## the speed limit, 4 unit polygon plates and tapering wedges are tunnelled by 5 to 17 percent of
## tokens without it, and none with it (docs/PHYSICS.md). Shape-cast mode did not help.
const TOKEN_CCD_MODE: int = RigidBody2D.CCD_MODE_CAST_RAY

# --- Static geometry ---
const WALL_FRICTION: float = 0.5
const WALL_BOUNCE: float = 0.1

## A pin's handle knob is a solid disc of this many pin thicknesses in radius. Presentation draws
## the same disc, so what you see is what collides.
const PIN_KNOB_RADIUS_FACTOR: float = 1.2

## Hard ceiling on dynamic bodies in one world. LevelSchema.MAX_SPAWNS equals this; both exist so
## that a definition built by code and never validated still cannot flood the physics server.
const MAX_DYNAMIC_BODIES: int = 150

# --- Level design guidance, measured in Prompt 03 (docs/PHYSICS.md). Advice for authors and the
# --- future editor; the validator does not enforce it, tests keep it true.

## An opening a crowd of tokens must pass should be at least this many token diameters wide.
## A crowd of 36 passed completely in 20 of 20 runs at 3.5 and 10 of 10 at 3.0; at 2.5 one run in
## 10 jammed, at 2.0 eight in 10 jammed, and at 1.5 or less no run ever passed completely.
const RELIABLE_OPENING_DIAMETERS: float = 3.5

## Ramps flatter than this crawl: median time to roll 700 units is 4.2 s at 10 degrees, 6.6 s at
## 5, 9.6 s at 3 and 13 s at 2; at 1 degree tokens still roll but need over 20 s.
const COMFORTABLE_SLOPE_DEGREES: float = 5.0


## Converts a duration to the nearest whole number of fixed ticks.
## Non-finite or non-positive durations return 0.
static func ticks_for_seconds(seconds: float) -> int:
	if not is_finite(seconds) or seconds <= 0.0:
		return 0
	return roundi(seconds * float(TICK_RATE))


## Converts a tick count to seconds. Negative counts return 0.0.
static func seconds_for_ticks(ticks: int) -> float:
	if ticks <= 0:
		return 0.0
	return float(ticks) / float(TICK_RATE)
