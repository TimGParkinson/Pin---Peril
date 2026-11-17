extends TestCase
## Harness fixture. A test with no assertions MUST be reported as a failure.


func test_makes_no_assertions() -> void:
	var _unused: int = 1 + 1
