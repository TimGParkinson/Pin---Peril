extends TestCase
## Harness fixture. This test MUST fail. scripts/verify-harness.ps1 asserts the runner
## exits nonzero for it. Never add this directory to a real suite.


func test_deliberate_failure() -> void:
	assert_eq(1 + 1, 3, "deliberately wrong arithmetic")
