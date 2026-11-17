class_name TestCase
extends RefCounted
## Base class for tests. Subclass it, name methods test_*, and make assertions.
##
## Test methods may use `await` (for example to wait a frame). A test that makes no
## assertions is reported as a failure, because a script error aborts a method
## silently from the runner's point of view.

const OWN_SOURCE: String = "res://tests/runner/test_case.gd"

## Set by the runner before each test. Use for process_frame/physics_frame/root access.
var tree: SceneTree

var failures: Array[String] = []
var assertion_count: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertion_count += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected %s but got %s" % [var_to_str(expected), var_to_str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertion_count += 1
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("expected a value different from %s" % var_to_str(unexpected), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	assertion_count += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %s +/- %s but got %s" % [expected, tolerance, actual], message)


func assert_not_null(value: Variant, message: String = "") -> void:
	assertion_count += 1
	if value == null:
		_fail("expected a non-null value", message)


func assert_null(value: Variant, message: String = "") -> void:
	assertion_count += 1
	if value != null:
		_fail("expected null but got %s" % var_to_str(value), message)


func fail(message: String) -> void:
	assertion_count += 1
	_fail("explicit failure", message)


func _fail(detail: String, message: String) -> void:
	var text: String = detail if message.is_empty() else "%s (%s)" % [detail, message]
	failures.append("%s%s" % [_caller_location(), text])


## Returns "file:line: " for the first stack frame outside this base class.
func _caller_location() -> String:
	for frame: Dictionary in get_stack():
		var source: String = frame.get("source", "") as String
		if source != OWN_SOURCE:
			return "%s:%d: " % [source, frame.get("line", 0) as int]
	return ""
