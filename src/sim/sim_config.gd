class_name SimConfig
extends RefCounted
## Fixed-step simulation constants shared by live play and (later) headless replay.
##
## Changing any value here changes physics outcomes. Bump CONFIG_VERSION and
## revalidate every known solution (see docs/ARCHITECTURE.md, "Versioning").

## Version of the simulation rules and tuning. Recorded with every replay result.
const CONFIG_VERSION: int = 1

## Fixed physics ticks per second. Must equal project setting
## physics/common/physics_ticks_per_second (checked by tests/domain/test_project_config.gd).
const TICK_RATE: int = 60

## Seconds per fixed tick.
const TICK_DELTA: float = 1.0 / 60.0


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
