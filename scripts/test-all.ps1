# Full verification: import, parse check, harness self-check, domain tests, scene tests.
# Stops at the first failing step and exits with its code.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\test-all.ps1 [-Clean]
param([switch] $Clean)

$steps = @(
    @{ Name = 'import';        Script = 'import.ps1';         Params = @{ Clean = [bool] $Clean } },
    @{ Name = 'parse';         Script = 'check-parse.ps1';    Params = @{} },
    @{ Name = 'harness';       Script = 'verify-harness.ps1'; Params = @{} },
    @{ Name = 'domain tests';  Script = 'test-domain.ps1';    Params = @{} },
    @{ Name = 'scene tests';   Script = 'test-scenes.ps1';    Params = @{} }
)

foreach ($step in $steps) {
    Write-Host ""
    Write-Host "=== $($step.Name) ===" -ForegroundColor Cyan
    $stepParams = $step.Params
    & (Join-Path $PSScriptRoot $step.Script) @stepParams
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "test-all: FAILED at step '$($step.Name)' (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
Write-Host ""
Write-Host "test-all: ALL STEPS PASSED" -ForegroundColor Green
exit 0
