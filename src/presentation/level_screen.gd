class_name LevelScreen
extends Control
## Level shell: Back and Restart controls plus the board for one level attempt.
##
## AppRoot sets `level_definition` (or `load_problem`) before adding this node. On ready the
## screen builds its OWN fresh LevelInstance and BoardView from the definition, so every
## restart starts from the authored positions and nothing is shared between attempts.
## Physics, pins and rules arrive in later stages (see docs/ARCHITECTURE.md).

## How many validation problems the screen lists when a level cannot be shown.
const MAX_SHOWN_ISSUES: int = 6

signal back_requested
signal restart_requested

## Set by AppRoot before the screen enters the tree. Never modified here.
var level_definition: LevelDefinition = null

## Explains why no level is shown, when loading or validation failed.
var load_problem: String = ""

## This attempt's runtime copy of the level, or null if none could be built.
var instance: LevelInstance = null

## The node drawing the board, or null if no level is shown.
var board_view: BoardView = null

@onready var _back_button: Button = %BackButton
@onready var _restart_button: Button = %RestartButton
@onready var _title_label: Label = %TitleLabel
@onready var _board_area: Control = %BoardArea
@onready var _placeholder_label: Label = %PlaceholderLabel
@onready var board_root: Node2D = %BoardRoot


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_board_area.resized.connect(_fit_board)
	_build_board()
	_fit_board.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()


func _build_board() -> void:
	if level_definition == null:
		_placeholder_label.text = load_problem if not load_problem.is_empty() else "No level loaded"
		return
	var report: ValidationReport = ValidationReport.new()
	instance = LevelInstance.create(level_definition, report)
	if instance == null:
		_placeholder_label.text = "Level data is invalid:\n%s" % report.summary(MAX_SHOWN_ISSUES)
		return
	_title_label.text = level_definition.title
	_placeholder_label.visible = false
	board_view = BoardView.new()
	board_view.name = "BoardView"
	board_view.setup(instance)
	board_root.add_child(board_view)


## Scales and centres the design-space board so it fits inside the board area.
func _fit_board() -> void:
	# Deferred calls can arrive after the screen was already removed (for example Play then
	# Back within one frame), when global positions are unavailable.
	if board_view == null or not is_inside_tree():
		return
	var area: Rect2 = _board_area.get_global_rect()
	var design: Vector2 = board_view.design_rect().size
	if area.size.x <= 0.0 or area.size.y <= 0.0 or design.x <= 0.0 or design.y <= 0.0:
		return
	var factor: float = minf(area.size.x / design.x, area.size.y / design.y)
	board_root.scale = Vector2(factor, factor)
	board_root.global_position = area.get_center() - design * factor * 0.5
