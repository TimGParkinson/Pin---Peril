# Loads every .gd/.tscn/.tres in the project and fails on any load or parse error.
# Requires a prior import (scripts\import.ps1).
# Usage: powershell -ExecutionPolicy Bypass -File scripts\check-parse.ps1

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    $result = Invoke-Godot -Arguments @('--headless', '--script', 'res://tests/runner/parse_check.gd')
    exit (Complete-Check -Name 'parse' -Result $result)
}
catch {
    Write-Host "[parse] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
