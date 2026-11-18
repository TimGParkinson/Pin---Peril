# Runs the physics test suite (tests/physics): real 2D physics, stepped one fixed tick per frame.
# Requires a prior import. --fixed-fps 60 makes each frame exactly one 1/60 s tick without
# waiting for the clock, so thousands of ticks take seconds instead of minutes.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\test-physics.ps1 [-Windowed]
#   -Windowed  uses the real window and renderer instead of --headless (physics is identical).
#              Passes --disable-vsync, otherwise each tick would wait for the display refresh.
param([switch] $Windowed)

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    $godotArgs = @('--fixed-fps', '60', '--script', 'res://tests/runner/test_runner.gd', '--', '--suite=physics')
    if (-not $Windowed) { $godotArgs = @('--headless') + $godotArgs } else { $godotArgs = @('--disable-vsync') + $godotArgs }
    $result = Invoke-Godot -Arguments $godotArgs -TimeoutSeconds 900
    exit (Complete-Check -Name 'physics tests' -Result $result)
}
catch {
    Write-Host "[physics tests] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
