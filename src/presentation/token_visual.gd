class_name TokenVisual
extends Node2D
## Draws one brass token. BoardView moves it to follow the token's physics body each tick.
##
## The disc and its outline stay inside the body's collision radius, so the drawing never
## shows more than the physics has. The notch makes rolling visible. Placeholder art until
## Prompt 07.

const NOTCH_COLOR: Color = Color(0.45, 0.3, 0.05, 1.0)

var radius: float = 14.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, BoardView.TOKEN_COLOR)
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 24, BoardView.BOARD_EDGE_COLOR, 2.0)
	draw_line(Vector2.ZERO, Vector2(radius * 0.7, 0.0), NOTCH_COLOR, 3.0)
