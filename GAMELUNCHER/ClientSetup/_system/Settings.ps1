# Settings.ps1 - shared helpers, dot-sourced by the other scripts.
#   $KitSystem  ...\ClientSetup\_system      $KitSetup  ...\ClientSetup      $KitRoot  ...\GAMELUNCHER
$KitSystem = $PSScriptRoot
$KitSetup  = Split-Path -Parent $KitSystem
$KitRoot   = Split-Path -Parent $KitSetup

# Drive letters that client PCs see (same letters as on the master), from ClientSetup\settings.txt.
# Empty = every fixed drive except the system drive.
function Get-SharedDrives {
    $f = Join-Path $KitSetup 'settings.txt'
    $v = ''
    if (Test-Path -LiteralPath $f) {
        $line = Get-Content -LiteralPath $f | Where-Object { $_ -match '^\s*SharedDrives\s*=' } | Select-Object -First 1
        if ($line) { $v = (($line -split '=', 2)[1] -replace '[^A-Za-z]', '').ToUpper() }
    }
    if (-not $v) {
        $sys = $env:SystemDrive.Substring(0, 1).ToUpper()
        $v = ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID.Substring(0, 1).ToUpper() } | Where-Object { $_ -ne $sys }) -join '')
    }
    $v
}

# Live status line, redrawn in place (and in the window title) so a long install visibly moves; '' clears it.
# Never logged: with output piped (scripts run by Install-All.ps1) it goes up as a "~" line that Install-All
# draws in place with this same function.
function Show-Live([string]$text) {
    try {
        if ([Console]::IsOutputRedirected) { Write-Host "~$text"; return }
        if (-not $text -and -not $script:LiveOn) { return }
        $w = [math]::Max(20, [Console]::WindowWidth - 1)
        if ($text.Length -gt $w) { $text = $text.Substring(0, $w) }
        [Console]::Write("`r" + $text.PadRight($w) + $(if ($text) { '' } else { "`r" }))
        $script:LiveOn = [bool]$text
        if ($text) { [Console]::Title = 'OSYNC ' + $text.Trim() }
    } catch {}
}
function Format-Sec([int]$s) { '{0}:{1:00}' -f [math]::Floor($s / 60), ($s % 60) }

# Run an installer hidden and wait at most $TimeoutSec, with a live line (spinner + time) while it runs and a
# logged note when it takes longer than 15 s; on timeout kills the whole process tree (a leftover child keeps
# Windows Installer busy for the next ones). Returns @{ Code = exit code, or $null after a timeout / start error; Sec }.
function Invoke-Installer([string]$Exe, $ArgList, [string]$Label, [int]$TimeoutSec = 300) {
    $sp = @{ FilePath = $Exe; PassThru = $true; WindowStyle = 'Hidden' }
    if ($ArgList) { $sp.ArgumentList = $ArgList }
    if ([IO.Path]::IsPathRooted($Exe) -and (Test-Path -LiteralPath (Split-Path -Parent $Exe))) { $sp.WorkingDirectory = Split-Path -Parent $Exe }
    $t = [Diagnostics.Stopwatch]::StartNew()
    $code = $null
    try {
        $p = Start-Process @sp -ErrorAction Stop
        $noted = $false
        while (-not $p.WaitForExit(1000)) {
            $s = [int]$t.Elapsed.TotalSeconds
            if ($s -ge $TimeoutSec) { break }
            if ($s -ge 15 -and -not $noted) { $noted = $true; Show-Live ''; Write-Host "  ...  $Label still running" }
            Show-Live ('  {0} {1} / {2}  {3}' -f '|/-\'[$s % 4], (Format-Sec $s), (Format-Sec $TimeoutSec), $Label)
        }
        Show-Live ''
        if ($p.HasExited) { $code = $p.ExitCode }
        else {
            Start-Process taskkill.exe -ArgumentList "/PID $($p.Id) /T /F" -WindowStyle Hidden -Wait
            Write-Host ("  TIMEOUT {0} (stopped after {1})" -f $Label, (Format-Sec $TimeoutSec))
        }
    } catch { Show-Live ''; Write-Host "  FAIL $Label ($($_.Exception.Message))" }
    [pscustomobject]@{ Code = $code; Sec = [int]$t.Elapsed.TotalSeconds }
}

# Riot products still downloading/patching on this PC: <name>.manifest is written when a patch starts,
# <name>.ok when it is done. A manifest older than 3 h without an .ok is an abandoned download, not counted.
# RiotClient in the list = a Riot Client self-update is waiting (installed when Riot Client restarts).
function Get-RiotBusy {
    $meta = Join-Path $env:ProgramData 'Riot Games\Metadata'
    foreach ($d in Get-ChildItem -LiteralPath $meta -Directory -ErrorAction SilentlyContinue) {
        $man = Get-Item -LiteralPath (Join-Path $d.FullName "$($d.Name).manifest") -ErrorAction SilentlyContinue
        if (-not $man -or $man.LastWriteTime -lt (Get-Date).AddHours(-3)) { continue }
        $ok = Get-Item -LiteralPath (Join-Path $d.FullName "$($d.Name).ok") -ErrorAction SilentlyContinue
        if (-not $ok -or $man.LastWriteTime -gt $ok.LastWriteTime.AddSeconds(1)) { $d.Name }
    }
}
