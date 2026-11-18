# Prints how long the physics tick takes at several body counts (see docs/PHYSICS.md).
# Usage: powershell -ExecutionPolicy Bypass -File scripts\profile-physics.ps1 [-Windowed]
#   -Windowed  uses the real window and renderer instead of --headless. A window appears briefly.
# Timings depend on the machine; record them with the machine description when you cite them.
param([switch] $Windowed)

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    $godotArgs = @('--fixed-fps', '60', '--script', 'res://tests/physics/profile_physics.gd')
    if (-not $Windowed) { $godotArgs = @('--headless') + $godotArgs } else { $godotArgs = @('--disable-vsync') + $godotArgs }
    $result = Invoke-Godot -Arguments $godotArgs -TimeoutSeconds 900
    exit (Complete-Check -Name 'physics profile' -Result $result)
}
catch {
    Write-Host "[physics profile] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
