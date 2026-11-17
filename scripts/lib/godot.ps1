# Shared helpers for the project scripts. Dot-source this file; do not run it directly.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

Set-StrictMode -Version Latest

$script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:EngineVersionFile = Join-Path $PSScriptRoot '..\engine-version.txt'

# Engine output lines that mean something went wrong even when the exit code is 0.
$script:ErrorPattern = '(?m)^(SCRIPT ERROR|USER ERROR|ERROR|Parse Error|LOAD ERROR|PARSE FAIL|RUNNER FAIL|RUNNER ERROR)\b'

function Get-ProjectRoot {
    return $script:ProjectRoot
}

# Pinned version such as "4.6.2-stable".
function Get-PinnedEngineVersion {
    return (Get-Content -LiteralPath $script:EngineVersionFile -TotalCount 1).Trim()
}

# Finds the Godot executable. If $env:GODOT_BIN is set it is the ONLY candidate (an invalid
# value fails loudly instead of silently using another binary); otherwise PATH is searched.
# Verifies it is the pinned standard (non-.NET) build. Throws with an actionable message.
function Get-GodotExe {
    $candidates = @()
    if ($env:GODOT_BIN) {
        $candidates += $env:GODOT_BIN
    }
    else {
        foreach ($name in @('godot.exe', 'godot')) {
            $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) { $candidates += $cmd.Source }
        }
    }
    if ($candidates.Count -eq 0) {
        throw "Godot not found. Install Godot $(Get-PinnedEngineVersion) (standard build, not .NET) and either put it on PATH or set GODOT_BIN to the full path of godot.exe. See README.md."
    }

    $expected = (Get-PinnedEngineVersion) -replace '-', '.'
    $seen = @()
    foreach ($exe in $candidates) {
        if (-not (Test-Path -LiteralPath $exe)) { $seen += "$exe (missing)"; continue }
        $reported = (& $exe --version | Select-Object -First 1).Trim()
        if ($reported -like "$expected.*" -and $reported -notlike '*mono*') { return $exe }
        $seen += "$exe reports '$reported'"
    }
    throw "No Godot matching pinned version '$expected' (standard build). Found: $($seen -join '; '). Install the pinned version or set GODOT_BIN."
}

# Runs Godot in the project root, echoes its output, and returns
# @{ ExitCode; ErrorLines; TimedOut }. Never throws on a nonzero exit.
function Invoke-Godot {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [int] $TimeoutSeconds = 300,
        [switch] $Quiet
    )
    $exe = Get-GodotExe
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $exe -ArgumentList $Arguments -WorkingDirectory $script:ProjectRoot `
            -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $proc.Handle  # keeps ExitCode readable on Windows PowerShell 5.1
        $timedOut = $false
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try { $proc.Kill() } catch { }
        }
        $proc.WaitForExit()
        $exitCode = if ($timedOut) { 124 } else { $proc.ExitCode }

        $ansi = '\x1b\[[0-9;]*m'
        $stdout = (Get-Content -LiteralPath $outFile -Raw) -replace $ansi, ''
        $stderr = (Get-Content -LiteralPath $errFile -Raw) -replace $ansi, ''
        if (-not $Quiet) {
            if ($stdout) { Write-Host $stdout.TrimEnd() }
            if ($stderr) { Write-Host $stderr.TrimEnd() }
        }

        $combined = "$stdout`n$stderr"
        $errorLines = @([regex]::Matches($combined, $script:ErrorPattern + '.*') | ForEach-Object { $_.Value })
        return [pscustomobject]@{ ExitCode = $exitCode; ErrorLines = $errorLines; TimedOut = $timedOut }
    }
    finally {
        Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

# Converts an Invoke-Godot result into a script exit code and prints a one-line verdict.
# Fails on nonzero exit, timeout, or any engine error line in the output.
function Complete-Check {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] $Result
    )
    if ($Result.TimedOut) {
        Write-Host "[$Name] FAIL: timed out" -ForegroundColor Red
        return 124
    }
    if ($Result.ExitCode -ne 0) {
        Write-Host "[$Name] FAIL: godot exit code $($Result.ExitCode)" -ForegroundColor Red
        return $Result.ExitCode
    }
    if ($Result.ErrorLines.Count -gt 0) {
        Write-Host "[$Name] FAIL: exit code 0 but engine reported $($Result.ErrorLines.Count) error line(s):" -ForegroundColor Red
        $Result.ErrorLines | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        return 3
    }
    Write-Host "[$Name] PASS" -ForegroundColor Green
    return 0
}
