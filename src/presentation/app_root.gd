class_name AppRoot
extends Node
## Owns the single active screen and performs screen transitions.
##
## Screens never reference each other; they emit request signals and this node
## decides what happens. Every transition frees the old screen and instantiates a
## fresh one, so restart can never carry stale state forward.

enum Screen { NONE, MENU, LEVEL }

const MENU_SCENE: PackedScene = preload("res://scenes/menu/main_menu.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/level/level_screen.tscn")

signal screen_changed(screen: Screen)

var current_screen: Screen = Screen.NONE

## The active screen node, or null before the first transition.
var current_node: Node:
	get:
		return _current

var _current: Node = null
var _level_definition: LevelDefinition = null
var _level_problem: String = ""


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	_switch_to(Screen.MENU)


## Loads the default level from data, then shows it. The loaded definition is reused by
## restart_level; each screen still builds its own fresh LevelInstance from it.
func show_level() -> void:
	var result: LevelLoader.LoadResult = LevelLibrary.load_builtin(LevelLibrary.DEFAULT_LEVEL_ID)
	if result.is_ok():
		_level_definition = result.definition
		_level_problem = ""
	else:
		_level_definition = null
		_level_problem = "Could not load level:\n%s" % result.report.summary()
	_switch_to(Screen.LEVEL)


## Replaces the level with a freshly instantiated one. Ignored outside the level screen.
func restart_level() -> void:
	if current_screen != Screen.LEVEL:
		return
	_switch_to(Screen.LEVEL)


func quit_game() -> void:
	get_tree().quit()


func _switch_to(screen: Screen) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
		_current = null

	match screen:
		Screen.MENU:
			var menu: MainMenu = MENU_SCENE.instantiate() as MainMenu
			menu.play_requested.connect(show_level)
			menu.quit_requested.connect(quit_game)
			_current = menu
		Screen.LEVEL:
			var level: LevelScreen = LEVEL_SCENE.instantiate() as LevelScreen
			level.level_definition = _level_definition
			level.load_problem = _level_problem
			level.back_requested.connect(show_menu)
			level.restart_requested.connect(restart_level)
			_current = level
		_:
			push_error("AppRoot: cannot switch to screen %d" % screen)
			return

	current_screen = screen
	add_child(_current)
	screen_changed.emit(screen)
