# Reports prerequisites. Exit 0 if required tools are present; export templates are only
# required from the Windows export stage, so a missing template is a warning unless
# -RequireTemplates is passed.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\check-env.ps1 [-RequireTemplates]
param([switch] $RequireTemplates)

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

$pinned = Get-PinnedEngineVersion
$status = 0
Write-Host "Pinned engine: Godot $pinned (standard build, not .NET)"

try {
    $exe = Get-GodotExe
    Write-Host "[ok] Godot: $exe ($((& $exe --version | Select-Object -First 1).Trim()))" -ForegroundColor Green
}
catch {
    Write-Host "[missing] $($_.Exception.Message)" -ForegroundColor Red
    $status = 1
}

$templateDir = Join-Path $env:APPDATA ("Godot\export_templates\" + ($pinned -replace '-', '.'))
$needed = @('windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'version.txt')
$absent = @($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $templateDir $_)) })
if ($absent.Count -eq 0) {
    Write-Host "[ok] Export templates: $templateDir" -ForegroundColor Green
}
else {
    $level = if ($RequireTemplates) { 'missing' } else { 'warn' }
    Write-Host "[$level] Export templates for $pinned not installed (missing: $($absent -join ', ')). Expected in $templateDir" -ForegroundColor Yellow
    Write-Host "         Install via Godot editor: Editor > Manage Export Templates > Install From File," -ForegroundColor Yellow
    Write-Host "         using Godot_v$pinned`_export_templates.tpz. See README.md." -ForegroundColor Yellow
    if ($RequireTemplates) { $status = 1 }
}
exit $status
