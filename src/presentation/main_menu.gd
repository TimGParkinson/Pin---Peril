class_name MainMenu
extends Control
## Title screen. Emits request signals only; AppRoot performs transitions.

signal play_requested
signal quit_requested

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_play_button.pressed.connect(func() -> void: play_requested.emit())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_play_button.grab_focus()
