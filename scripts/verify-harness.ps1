# Proves the checks can fail. Runs the runner and parse check against deliberately bad
# inputs and succeeds only if every one of them is detected as a failure.
# Requires a prior import. Temporary files are removed even on error.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\verify-harness.ps1

. (Join-Path $PSScriptRoot 'lib\godot.ps1')

$runner = 'res://tests/runner/test_runner.gd'
$problems = @()

# Each case must produce a failure (nonzero exit, or engine error output).
function Assert-Detected {
    param([string] $Case, [string[]] $GodotArgs, [string] $ExpectOutputContains = '')
    $result = Invoke-Godot -Arguments $GodotArgs -Quiet
    $failed = $result.TimedOut -or ($result.ExitCode -ne 0) -or ($result.ErrorLines.Count -gt 0)
    if ($failed) {
        Write-Host "[harness] detected: $Case (exit $($result.ExitCode), error lines $($result.ErrorLines.Count))" -ForegroundColor Green
    }
    else {
        Write-Host "[harness] MISSED: $Case (exit 0 and no error output)" -ForegroundColor Red
        $script:problems += $Case
    }
}

try {
    Assert-Detected 'failing assertion' @('--headless', '--script', $runner, '--', '--dir=res://tests/harness_fixtures/failing')
    Assert-Detected 'test with no assertions' @('--headless', '--script', $runner, '--', '--dir=res://tests/harness_fixtures/no_assertions')
    Assert-Detected 'runtime script error inside a test' @('--headless', '--script', $runner, '--', '--dir=res://tests/harness_fixtures/script_error')
    Assert-Detected 'missing test directory' @('--headless', '--script', $runner, '--', '--dir=res://tests/harness_fixtures/does_not_exist')
    Assert-Detected 'unknown suite' @('--headless', '--script', $runner, '--', '--suite=nope')

    $broken = Join-Path (Get-ProjectRoot) 'tests\harness_fixtures\_broken_parse.gd'
    try {
        Set-Content -LiteralPath $broken -Value "extends Node`nfunc broken( -> void:`n`tthis is not valid gdscript`n" -Encoding ascii
        Assert-Detected 'script with a parse error' @('--headless', '--script', 'res://tests/runner/parse_check.gd')
    }
    finally {
        Remove-Item -LiteralPath $broken, "$broken.uid" -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Host "[harness] FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 10
}

if ($problems.Count -gt 0) {
    Write-Host "[harness] FAIL: undetected failures: $($problems -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "[harness] PASS: all deliberate failures were detected" -ForegroundColor Green
exit 0
