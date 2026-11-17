# Runs the scene test suite (tests/scene) against the real scenes. Requires a prior import.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\test-scenes.ps1 [-Windowed]
#   -Windowed  runs with a real window and the real OpenGL renderer instead of --headless.
#              A window appears briefly. Input is still synthetic; this is not a human check.
param([switch] $Windowed)

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    $godotArgs = @('--script', 'res://tests/runner/test_runner.gd', '--', '--suite=scene')
    if (-not $Windowed) { $godotArgs = @('--headless') + $godotArgs }
    $result = Invoke-Godot -Arguments $godotArgs
    exit (Complete-Check -Name 'scene tests' -Result $result)
}
catch {
    Write-Host "[scene tests] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
