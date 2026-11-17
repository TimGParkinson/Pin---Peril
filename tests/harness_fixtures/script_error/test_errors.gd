extends TestCase
## Harness fixture. The runner sees an assertion pass, then a runtime script error aborts
## the method. scripts/verify-harness.ps1 asserts the wrapper still fails (it scans engine
## output for SCRIPT ERROR).


func test_runtime_error_after_passing_assertion() -> void:
	assert_true(true)
	var missing: Node = null
	missing.queue_free()
