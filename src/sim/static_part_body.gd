class_name StaticPartBody
extends StaticBody2D
## An immovable piece of board geometry (a wall or, until Prompt 04 makes them pullable, a pin).

const KIND_WALL: String = "wall"
const KIND_PIN: String = "pin"

## Stable id from the level data, for example "wall.outer" or "pin.a".
var part_id: String = ""

## KIND_WALL or KIND_PIN.
var part_kind: String = KIND_WALL
