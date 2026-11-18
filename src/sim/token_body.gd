class_name TokenBody
extends RigidBody2D
## One brass token: a dynamic circle with a stable material id.
##
## Created and configured by SimWorld. The only code here is the speed limit and a record of the
## fastest speed the solver produced, for tests and the debug overlay.

## Stable id from the level data (spawn id), for example "token.3".
var material_id: String = ""

## Speed limit in units per second; 0 or less means unlimited.
var max_speed: float = 0.0

## Fastest speed seen at the start of any tick, before the limit was applied.
var peak_speed: float = 0.0


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var speed: float = state.linear_velocity.length()
	if speed > peak_speed:
		peak_speed = speed
	if max_speed > 0.0 and speed > max_speed:
		state.linear_velocity = state.linear_velocity * (max_speed / speed)
