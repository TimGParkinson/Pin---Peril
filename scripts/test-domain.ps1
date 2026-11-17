# Runs the domain test suite (tests/domain). Requires a prior import.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\test-domain.ps1

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    $result = Invoke-Godot -Arguments @('--headless', '--script', 'res://tests/runner/test_runner.gd', '--', '--suite=domain')
    exit (Complete-Check -Name 'domain tests' -Result $result)
}
catch {
    Write-Host "[domain tests] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
