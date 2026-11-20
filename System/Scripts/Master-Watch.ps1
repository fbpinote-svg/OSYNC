# Master-Watch.ps1 - MASTER only (OSYNC.bat > 2). Runs hidden from logon and:
#   1 keeps every launcher in Launchers\ open (Riot, Steam, Epic, EA app, HoYoPlay, Garena, Ubisoft, Rockstar,
#     Modrinth) so games update by themselves
#   2 installs a waiting Riot Client self-update (restarts Riot Client) so clients do not each install it
#   3 when an update / install / uninstall has finished, and every hour anyway, runs Master-Update.ps1
#     (Riot, EA, Epic, EAC data + menu list) so clients open the new version straight away, without REPAIR.
#     New game folders in every game folder (GamesFolder + GameFolders) count as a change too.
#   4 online library (Settings OnlineHub set): Online-Library.ps1 -Sync every 5 min
# -Register: autostart at logon + start now. Two ways in, so one is enough: the task "OSYNC-Master-Watch" (this user,
#   not elevated, 30 s after logon) and HKCU Run "OSYNC-Master" (Windows skipped this Run entry at a reboot on
#   2026-11-14). The mutex keeps it to one watcher.
# -Unregister: stop every watcher (also one started from an older OSYNC folder) and remove both autostarts.
# -From task|run: who started it (Master-Watch.vbs passes it on); every start is written to the log.
# Log: C:\Users\Public\OSYNC-Master-Watch.log
param([switch]$Register, [switch]$Unregister, [string]$From = 'manual', [int]$CheckSeconds = 60, [int]$SettleMinutes = 2, [int]$EveryMinutes = 60)
. (Join-Path $PSScriptRoot 'Common.ps1')
$updateAll = Join-Path $ScriptsDir 'Master-Update.ps1'
$vbs       = Join-Path $ScriptsDir 'Master-Watch.vbs'
$runKey    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$taskName  = 'OSYNC-Master-Watch'
$mutexName = 'Local\OSYNC-Master-Watch'
$logFile   = 'C:\Users\Public\OSYNC-Master-Watch.log'
$stateFile = 'C:\Users\Public\OSYNC-Master-Watch.state'

function Log([string]$m) {
    if ((Test-Path -LiteralPath $logFile) -and (Get-Item -LiteralPath $logFile).Length -gt 2MB) { Move-Item -LiteralPath $logFile "$logFile.old" -Force }
    Add-Content -LiteralPath $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $m) -Encoding UTF8
}

function Get-Apps {
    foreach ($l in $LauncherTable) {
        $exe = if ($l.Key -eq 'Steam') { $d = Get-SteamDir; if ($d) { Join-Path $d 'steam.exe' } } else { Get-LauncherExe $l.Key }
        @{ Name = $l.Title; Proc = $l.Proc; Exe = $exe; Args = $l.Args }
    }
}
function Test-Running($app) { [bool](Get-Process -Name $app.Proc -ErrorAction SilentlyContinue) }
function Start-App($app) {
    $p = @{ FilePath = $app.Exe; WorkingDirectory = (Split-Path -Parent $app.Exe) }
    if ($app.Args) { $p.ArgumentList = $app.Args }
    Start-Process @p
}

if ($Unregister) {
    Remove-ItemProperty -Path $runKey -Name 'OSYNC-Master' -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like '*Master-Watch.ps1*' -and $_.CommandLine -notlike '*-Unregister*' -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Log 'watcher stopped, autostart removed'
    'autostart at logon: OFF   watcher: stopped   (launchers that are open stay open)'
    exit 0
}

if ($Register) {
    Stop-IfPreMigration 'Watcher ON'
    # a watcher from an older OSYNC folder holds the same mutex: stop it so this one takes over
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like '*Master-Watch.ps1*' -and $_.CommandLine -notlike "*$ScriptsDir*" -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force; 'stopped the watcher of an older OSYNC folder' }
    Set-ItemProperty -Path $runKey -Name 'OSYNC-Master' -Value ('wscript.exe "{0}" run' -f $vbs)
    # the task: at this user's logon, as this user and NOT elevated (the launchers it opens must not run as admin)
    try {
        $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $ta = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}" task' -f $vbs)
        $tt = New-ScheduledTaskTrigger -AtLogOn -User $me
        $tt.Delay = 'PT30S'
        $tp = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
        $ts = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $ta -Trigger $tt -Principal $tp -Settings $ts -Description "OSYNC: start the master watcher at logon ($vbs)" -Force -ErrorAction Stop | Out-Null
        "autostart at logon: ON  (task $taskName for $me + HKCU Run OSYNC-Master)"
        Log "autostart ON: task $taskName ($me) + Run entry"
    } catch {
        "autostart at logon: Run entry only - the task could not be made: $($_.Exception.Message)"
        Log "autostart: task FAILED ($($_.Exception.Message)), Run entry only"
    }
    Start-Sleep -Seconds 1
    $m = $null
    if ([Threading.Mutex]::TryOpenExisting($mutexName, [ref]$m)) { $m.Dispose(); 'watcher: already running' }
    # started from an elevated window (step B, setup): explorer starts it as the normal user, so the launchers it opens are not elevated
    elseif (Test-Admin) { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $vbs); 'watcher: started (as the logged-on user)' }
    else { Start-Process wscript.exe -ArgumentList ('"{0}"' -f $vbs); 'watcher: started' }
    Start-Sleep -Seconds 8
    ''
    foreach ($a in Get-Apps) {
        $s = if (-not $a.Exe -or -not (Test-Path -LiteralPath $a.Exe)) { 'not installed' } elseif (Test-Running $a) { 'open' } else { 'opening...' }
        '{0,-22} {1}' -f $a.Name, $s
    }
    ''
    "Games update on this PC by themselves; client data is refreshed automatically when an update is done."
    "Log: $logFile"
    exit 0
}

# ---------------- watcher loop ----------------
if ($From -notmatch '^(task|run|manual)$') { $From = 'manual' }
if (Test-PreMigration) { Log "start ($From): old layout still in use - not started"; exit 2 }
$mutex = New-Object Threading.Mutex($false, $mutexName)
if (-not $mutex.WaitOne(0)) { Log "start ($From): a watcher is already running - this one exits"; exit 0 }

# what Master-Update copies for clients (Riot / Epic / EA), which Steam games are installed, and the game folders /
# installed-apps entries (a game added by hand or by any installer shows up in the menu by itself)
function Get-State {
    $items = New-Object System.Collections.Generic.List[string]
    $riot = Join-Path $env:ProgramData 'Riot Games\Metadata'
    Get-ChildItem -LiteralPath $riot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\.(ok|manifest)$|product_settings\.yaml$' -and $_.FullName -notmatch '\\Update\\' } |
        ForEach-Object { $items.Add("$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)") }
    $epic = Join-Path $env:ProgramData 'Epic'
    @(Get-ChildItem -LiteralPath (Join-Path $epic 'EpicGamesLauncher\Data\Manifests') -Filter *.item -ErrorAction SilentlyContinue) +
      @(Get-Item -LiteralPath (Join-Path $epic 'UnrealEngineLauncher\LauncherInstalled.dat') -ErrorAction SilentlyContinue) |
        ForEach-Object { $items.Add("$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)") }
    Get-ChildItem -LiteralPath (Join-Path $env:ProgramData 'EA Desktop\InstallData') -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object { $items.Add("$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)") }
    foreach ($l in Get-SteamLibraries) {
        Get-ChildItem -LiteralPath (Join-Path $l 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | ForEach-Object { $items.Add($_.Name) }
    }
    foreach ($s in Get-GameFolderStamp) { $items.Add($s) }
    $sha = [Security.Cryptography.SHA256]::Create()
    [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes((($items | Sort-Object -Unique) -join "`n")))) -replace '-', ''
}

function Get-Busy {
    $b = @(Get-RiotBusy | Where-Object { $_ -ne 'RiotClient' } | ForEach-Object { "Riot $_" })
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests') -Filter *.item -ErrorAction SilentlyContinue) {
        if ($f.LastWriteTime -lt (Get-Date).AddHours(-3)) { continue }
        try { $m = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json; if ($m.bIsIncompleteInstall) { $b += "Epic $($m.DisplayName)" } } catch { }
    }
    $b
}

Log "watcher started from $Root by $From (check every $CheckSeconds s)"
$startedAt = @{}
$riotRestartAt = [datetime]::MinValue
$failedAt = [datetime]::MinValue
$saved = if (Test-Path -LiteralPath $stateFile) { (Get-Content -LiteralPath $stateFile -Raw).Trim() } else { '' }
$lastRunAt = if (Test-Path -LiteralPath $stateFile) { (Get-Item -LiteralPath $stateFile).LastWriteTime } else { [datetime]::MinValue }
$last = ''; $stableSince = Get-Date; $waitMsg = ''
$onlineAt = [datetime]::MinValue

while ($true) {
    try {
        # 1 keep launchers open (a launcher just started gets 10 min to show up before trying again)
        foreach ($a in Get-Apps) {
            if (-not $a.Exe -or -not (Test-Path -LiteralPath $a.Exe) -or (Test-Running $a)) { continue }
            if ($startedAt[$a.Name] -and ((Get-Date) - $startedAt[$a.Name]).TotalMinutes -lt 10) { continue }
            $startedAt[$a.Name] = Get-Date
            try { Start-App $a; Log "opened $($a.Name)" } catch { Log "cannot open $($a.Name): $($_.Exception.Message)" }
        }

        # 2 Riot Client self-update downloaded -> restart Riot Client to install it (no game patching or open)
        $upd = Join-Path $env:ProgramData 'Riot Games\Metadata\RiotClient\Update'
        if ((Test-Path -LiteralPath $upd) -and ((Get-Date) - $riotRestartAt).TotalHours -ge 6) {
            $newest = Get-ChildItem -LiteralPath $upd -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $gameOpen = Get-Process -Name 'VALORANT*', 'League of Legends', 'LeagueClient' -ErrorAction SilentlyContinue
            if ($newest -and $newest.LastWriteTime -lt (Get-Date).AddMinutes(-5) -and -not $gameOpen -and -not (Get-Busy)) {
                $riotRestartAt = Get-Date
                Log 'Riot Client update waiting -> restarting Riot Client to install it'
                Get-Process -Name 'Riot Client', 'RiotClientServices', 'RiotClientCrashHandler' -ErrorAction SilentlyContinue | Stop-Process -Force
                Start-Sleep -Seconds 5
                $riot = Get-Apps | Where-Object { $_.Name -eq 'Riot Client' } | Select-Object -First 1
                $startedAt[$riot.Name] = Get-Date
                Start-App $riot
            }
        }

        # 3 refresh client data once changes have settled, and every $EveryMinutes anyway (never while half-updated)
        $now = Get-State
        if ($now -ne $last) { $last = $now; $stableSince = Get-Date }
        $changed = $now -ne $saved -and ((Get-Date) - $stableSince).TotalMinutes -ge $SettleMinutes
        $due     = ((Get-Date) - $lastRunAt).TotalMinutes -ge $EveryMinutes
        if (($changed -or $due) -and ((Get-Date) - $failedAt).TotalMinutes -ge 30) {
            $busy = @(Get-Busy)
            if ($busy) {
                $msg = 'waiting for: ' + ($busy -join ', ')
                if ($msg -ne $waitMsg) { Log $msg; $waitMsg = $msg }
            } else {
                $waitMsg = ''
                Log ('{0} -> Master-Update' -f $(if ($changed) { 'games changed' } else { "every $EveryMinutes min" }))
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updateAll *>&1 | ForEach-Object { if ("$_".Trim()) { Log "    $_" } }
                if ($LASTEXITCODE -eq 0) {
                    $saved = Get-State; $last = $saved; $lastRunAt = Get-Date
                    Set-Content -LiteralPath $stateFile -Value $saved -Encoding ASCII
                    Log 'client data refreshed OK'
                } else { $failedAt = Get-Date; Log "Master-Update FAILED (exit $LASTEXITCODE) - retry in 30 min" }
            }
        }

        # 4 online library (only when Settings OnlineHub is set): every 5 min publish this branch's games, share games other
        #   branches asked for, move pulls on - a finished pull is a new game folder, which step 3 adds to the menu
        if ((Get-Setting 'OnlineHub' '') -and ((Get-Date) - $onlineAt).TotalMinutes -ge 5) {
            $onlineAt = Get-Date
            $o = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir 'Online-Library.ps1') -Sync 2>&1 | ForEach-Object { "$_" }
            $txt = ($o -join ' ') -replace '\s+', ' '
            if ($LASTEXITCODE -ne 0 -or $txt -match '"(served|finished)":\s*[1-9]') { Log "online library: $txt" }
        }
    } catch { Log "error: $($_.Exception.Message)" }
    Start-Sleep -Seconds $CheckSeconds
}
