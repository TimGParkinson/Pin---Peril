# Headless project import. Builds .godot/ (class cache, imported resources).
# Usage: powershell -ExecutionPolicy Bypass -File scripts\import.ps1 [-Clean]
#   -Clean  deletes .godot/ first to prove a clean checkout imports.
param([switch] $Clean)

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

try {
    if ($Clean) {
        $cache = Join-Path (Get-ProjectRoot) '.godot'
        if (Test-Path -LiteralPath $cache) {
            Remove-Item -LiteralPath $cache -Recurse -Force
            Write-Host "Removed $cache"
        }
    }
    $result = Invoke-Godot -Arguments @('--headless', '--import') -TimeoutSeconds 600
    $code = Complete-Check -Name 'import' -Result $result
    if ($code -eq 0 -and -not (Test-Path -LiteralPath (Join-Path (Get-ProjectRoot) '.godot\global_script_class_cache.cfg'))) {
        Write-Host '[import] FAIL: .godot/global_script_class_cache.cfg was not created' -ForegroundColor Red
        $code = 4
    }
    exit $code
}
catch {
    Write-Host "[import] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}
