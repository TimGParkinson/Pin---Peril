extends SceneTree
## Minimal explicit test runner. Exit code 0 only if every discovered test passed.
##
## Usage (after a project import):
##   godot --headless --script res://tests/runner/test_runner.gd -- --suite=domain
##   godot --headless --script res://tests/runner/test_runner.gd -- --suite=scene
##   godot --headless --script res://tests/runner/test_runner.gd -- --dir=res://some/dir
##
## Exit codes: 0 = all passed, 1 = test failure or no tests found, 2 = bad arguments.
## Failure conditions: failed assertion, test with zero assertions, test file that fails
## to load, test file that does not extend TestCase, or zero tests discovered.

const SUITES: Dictionary = {
	"domain": ["res://tests/domain"],
	"scene": ["res://tests/scene"],
	"all": ["res://tests/domain", "res://tests/scene"],
}

var _total: int = 0
var _failed: int = 0
var _load_errors: int = 0


func _init() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var directories: Array[String] = []
	if not _parse_args(directories):
		quit(2)
		return

	var files: Array[String] = []
	for directory: String in directories:
		files.append_array(_discover(directory))
	files.sort()

	if files.is_empty():
		printerr("RUNNER FAIL: no test files found in %s" % ", ".join(directories))
		quit(1)
		return

	for path: String in files:
		await _run_file(path)

	print("")
	print("Tests run: %d, failed: %d, load errors: %d" % [_total, _failed, _load_errors])
	if _total == 0:
		printerr("RUNNER FAIL: zero tests were discovered")
		quit(1)
	elif _failed > 0 or _load_errors > 0:
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


func _parse_args(directories: Array[String]) -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			var suite: String = arg.trim_prefix("--suite=")
			if not SUITES.has(suite):
				printerr("RUNNER ERROR: unknown suite '%s'. Known: %s" % [suite, ", ".join(SUITES.keys())])
				return false
			for directory: String in SUITES[suite] as Array:
				directories.append(directory)
		elif arg.begins_with("--dir="):
			directories.append(arg.trim_prefix("--dir="))
		else:
			printerr("RUNNER ERROR: unknown argument '%s'" % arg)
			return false
	if directories.is_empty():
		printerr("RUNNER ERROR: pass --suite=<domain|scene|all> or --dir=<res://path>")
		return false
	return true


func _discover(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		printerr("RUNNER FAIL: cannot open test directory %s" % directory)
		return found
	for file_name: String in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append("%s/%s" % [directory, file_name])
	return found


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		printerr("LOAD ERROR: %s" % path)
		_load_errors += 1
		return
	var instance: TestCase = script.new() as TestCase
	if instance == null:
		printerr("LOAD ERROR: %s does not extend TestCase" % path)
		_load_errors += 1
		return
	instance.tree = self

	var method_names: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"] as String
		if method_name.begins_with("test_"):
			method_names.append(method_name)
	method_names.sort()

	if method_names.is_empty():
		printerr("LOAD ERROR: %s declares no test_* methods" % path)
		_load_errors += 1
		return

	for method_name: String in method_names:
		instance.failures.clear()
		instance.assertion_count = 0
		await instance.before_each()
		await instance.call(method_name)
		await instance.after_each()

		_total += 1
		var label: String = "%s::%s" % [path.get_file(), method_name]
		if instance.assertion_count == 0:
			instance.failures.append("test made no assertions (script error or empty test)")
		if instance.failures.is_empty():
			print("  PASS  %s (%d assertions)" % [label, instance.assertion_count])
		else:
			_failed += 1
			print("  FAIL  %s" % label)
			for message: String in instance.failures:
				print("        %s" % message)
