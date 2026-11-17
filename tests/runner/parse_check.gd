extends SceneTree
## Loads every script, scene and resource under res:// and fails if any cannot load.
##
## Usage (after a project import):
##   godot --headless --script res://tests/runner/parse_check.gd
##
## Exit codes: 0 = everything loaded, 1 = at least one failure.
## Godot prints parse errors but can still exit 0, so this check reports explicitly.

const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
const SKIPPED_DIRECTORIES: PackedStringArray = ["addons", "builds", "logs"]

var _checked: int = 0
var _failures: Array[String] = []


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_walk("res://")
	print("Parse check: %d files, %d failures" % [_checked, _failures.size()])
	for path: String in _failures:
		printerr("PARSE FAIL: %s" % path)
	if _checked == 0:
		printerr("PARSE FAIL: no files were found, check the project path")
		quit(1)
	elif _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL")
		quit(1)


func _walk(directory: String) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		_failures.append("%s (cannot open directory)" % directory)
		return
	for sub: String in dir.get_directories():
		if sub.begins_with(".") or SKIPPED_DIRECTORIES.has(sub):
			continue
		_walk(directory.path_join(sub))
	for file_name: String in dir.get_files():
		if EXTENSIONS.has(file_name.get_extension()):
			_check(directory.path_join(file_name))


func _check(path: String) -> void:
	_checked += 1
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null:
		_failures.append(path)
		return
	if resource is GDScript:
		var script: GDScript = resource as GDScript
		if not script.can_instantiate() and not script.is_abstract():
			_failures.append("%s (script cannot be instantiated)" % path)
