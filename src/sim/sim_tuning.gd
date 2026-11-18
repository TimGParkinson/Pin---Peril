class_name SimTuning
extends RefCounted
## The adjustable physics numbers for one SimWorld, defaulting to the values in SimConfig.
##
## Live play and replay use the defaults. Tests and the profiling tool pass variants (for
## example the speed limit switched off) to show why each safeguard exists. Gravity, sleep and
## solver settings are project-wide and are not here (see docs/PHYSICS.md).

var token_mass: float = SimConfig.TOKEN_MASS
var token_friction: float = SimConfig.TOKEN_FRICTION
var token_bounce: float = SimConfig.TOKEN_BOUNCE
var token_linear_damp: float = SimConfig.TOKEN_LINEAR_DAMP
var token_angular_damp: float = SimConfig.TOKEN_ANGULAR_DAMP
var token_ccd_mode: int = SimConfig.TOKEN_CCD_MODE
## Units per second; 0 or less disables the limit.
var max_token_speed: float = SimConfig.MAX_TOKEN_SPEED
var wall_friction: float = SimConfig.WALL_FRICTION
var wall_bounce: float = SimConfig.WALL_BOUNCE
var max_dynamic_bodies: int = SimConfig.MAX_DYNAMIC_BODIES


## Text form of every number, recorded with replay results so a change is visible.
func signature() -> String:
	return "v%d mass=%.4f friction=%.4f bounce=%.4f ldamp=%.4f adamp=%.4f ccd=%d vmax=%.1f wfriction=%.4f wbounce=%.4f bodies=%d" % [
		SimConfig.CONFIG_VERSION, token_mass, token_friction, token_bounce, token_linear_damp,
		token_angular_damp, token_ccd_mode, max_token_speed, wall_friction, wall_bounce, max_dynamic_bodies,
	]
