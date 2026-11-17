class_name LevelScreen
extends Control
## Empty level shell with back and restart controls.
##
## Phase 0 placeholder: no level data, rules or physics yet. BoardRoot is where the
## simulation view will be mounted (see docs/ARCHITECTURE.md).

signal back_requested
signal restart_requested

@onready var _back_button: Button = %BackButton
@onready var _restart_button: Button = %RestartButton
@onready var board_root: Node2D = %BoardRoot


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
