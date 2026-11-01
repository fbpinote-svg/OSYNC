# Master-Watch.ps1 - MASTER only (ClientSetup\MASTER-Start-All.bat). Runs hidden from logon and:
#   1 keeps every launcher open (Riot, Steam, Epic, EA app, HoYoPlay, Garena, Ubisoft, Rockstar, Modrinth)
#     so games update by themselves
#   2 installs a waiting Riot Client self-update (restarts Riot Client) so clients do not each install it
#   3 when an update / install / uninstall has finished, and every hour anyway, runs MASTER-Update-All
#     (Riot, EA, Epic, EAC data + menu list) so clients open the new version straight away, without REPAIR
# -Register: autostart at logon (HKCU Run "OSYNC-Master") + start now.  -Unregister: stop and remove autostart.
# Log: C:\Users\Public\OSYNC-Master-Watch.log
param([switch]$Register, [switch]$Unregister, [int]$CheckSeconds = 60, [int]$SettleMinutes = 2, [int]$EveryMinutes = 60)
. (Join-Path $PSScriptRoot 'Settings.ps1')
$osync     = Split-Path -Parent $KitRoot
$updateAll = Join-Path $osync '_system\Update-All.ps1'
$vbs       = Join-Path $PSScriptRoot 'Master-Watch.vbs'
$runKey    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$mutexName = 'Local\OSYNC-Master-Watch'
$logFile   = 'C:\Users\Public\OSYNC-Master-Watch.log'
$stateFile = 'C:\Users\Public\OSYNC-Master-Watch.state'

function Log([string]$m) {
    if ((Test-Path -LiteralPath $logFile) -and (Get-Item -LiteralPath $logFile).Length -gt 2MB) { Move-Item -LiteralPath $logFile "$logFile.old" -Force }
    Add-Content -LiteralPath $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $m) -Encoding UTF8
}

function Get-Apps {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
    @(
        @{ Name = 'Riot Client'; Proc = 'RiotClientServices', 'Riot Client'; Exe = "$KitRoot\RiotClient\RiotClientServices.exe"; Args = '' }
        @{ Name = 'Steam';       Proc = 'steam';                             Exe = $(if ($steam) { $steam -replace '/', '\' }); Args = '-silent' }
        @{ Name = 'Epic';        Proc = 'EpicGamesLauncher';                 Exe = "$KitRoot\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"; Args = '-silent' }
        @{ Name = 'EA app';      Proc = 'EADesktop', 'EALauncher';           Exe = "$KitRoot\EA Desktop\EA Desktop\EALauncher.exe"; Args = '-silentOs' }
        @{ Name = 'HoYoPlay';    Proc = 'HYP';                               Exe = "$KitRoot\HoYoPlay\launcher.exe"; Args = '' }
        @{ Name = 'Garena';      Proc = 'Garena';                            Exe = "$KitRoot\Garena\Garena.exe"; Args = '' }
        @{ Name = 'Ubisoft';     Proc = 'upc', 'UbisoftConnect';             Exe = "$KitRoot\Ubisoft\Ubisoft Game Launcher\upc.exe"; Args = '' }
        @{ Name = 'Rockstar';    Proc = 'Launcher', 'LauncherPatcher';       Exe = "$KitRoot\Rockstar Games Launcher\LauncherPatcher.exe"; Args = '' }
        @{ Name = 'Modrinth';    Proc = 'Modrinth App';                      Exe = "$KitRoot\Modrinth App\Modrinth App.exe"; Args = '' }
    )
}
function Test-Running($app) { [bool](Get-Process -Name $app.Proc -ErrorAction SilentlyContinue) }
function Start-App($app) {
    $p = @{ FilePath = $app.Exe; WorkingDirectory = (Split-Path -Parent $app.Exe) }
    if ($app.Args) { $p.ArgumentList = $app.Args }
    Start-Process @p
}

if ($Unregister) {
    Remove-ItemProperty -Path $runKey -Name 'OSYNC-Master' -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like '*Master-Watch.ps1*' -and $_.CommandLine -notlike '*-Unregister*' -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Log 'watcher stopped, autostart removed'
    'autostart at logon: OFF   watcher: stopped   (launchers that are open stay open)'
    exit 0
}

if ($Register) {
    Set-ItemProperty -Path $runKey -Name 'OSYNC-Master' -Value ('wscript.exe "{0}"' -f $vbs)
    'autostart at logon: ON  (HKCU Run OSYNC-Master)'
    $m = $null
    if ([Threading.Mutex]::TryOpenExisting($mutexName, [ref]$m)) { $m.Dispose(); 'watcher: already running' }
    else { Start-Process wscript.exe -ArgumentList ('"{0}"' -f $vbs); 'watcher: started' }
    Start-Sleep -Seconds 8
    ''
    foreach ($a in Get-Apps) {
        $s = if (-not $a.Exe -or -not (Test-Path -LiteralPath $a.Exe)) { 'not installed' } elseif (Test-Running $a) { 'open' } else { 'opening...' }
        '{0,-12} {1}' -f $a.Name, $s
    }
    ''
    "Games update on this PC by themselves; client data is refreshed automatically when an update is done."
    "Log: $logFile"
    exit 0
}

# ---------------- watcher loop ----------------
$mutex = New-Object Threading.Mutex($false, $mutexName)
if (-not $mutex.WaitOne(0)) { exit 0 }

# what MASTER-Update-All copies for clients (Riot / Epic / EA), plus which Steam games are installed
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
    $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steamPath) {
        $libs = @($steamPath)
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) { $libs += [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' } }
        foreach ($l in $libs | Sort-Object -Unique) {
            Get-ChildItem -LiteralPath (Join-Path $l 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | ForEach-Object { $items.Add($_.Name) }
        }
    }
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

Log "watcher started (check every $CheckSeconds s)"
$startedAt = @{}
$riotRestartAt = [datetime]::MinValue
$failedAt = [datetime]::MinValue
$saved = if (Test-Path -LiteralPath $stateFile) { (Get-Content -LiteralPath $stateFile -Raw).Trim() } else { '' }
$lastRunAt = if (Test-Path -LiteralPath $stateFile) { (Get-Item -LiteralPath $stateFile).LastWriteTime } else { [datetime]::MinValue }
$last = ''; $stableSince = Get-Date; $waitMsg = ''

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
                $riot = (Get-Apps)[0]; $startedAt[$riot.Name] = Get-Date
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
                Log ('{0} -> MASTER-Update-All' -f $(if ($changed) { 'games changed' } else { "every $EveryMinutes min" }))
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updateAll *>&1 | ForEach-Object { if ("$_".Trim()) { Log "    $_" } }
                if ($LASTEXITCODE -eq 0) {
                    $saved = Get-State; $last = $saved; $lastRunAt = Get-Date
                    Set-Content -LiteralPath $stateFile -Value $saved -Encoding ASCII
                    Log 'client data refreshed OK'
                } else { $failedAt = Get-Date; Log "MASTER-Update-All FAILED (exit $LASTEXITCODE) - retry in 30 min" }
            }
        }
    } catch { Log "error: $($_.Exception.Message)" }
    Start-Sleep -Seconds $CheckSeconds
}
