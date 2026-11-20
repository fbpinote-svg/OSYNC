# Tool-Check.ps1 - READ ONLY system check (OSYNC.bat > 6, or OSYNC.bat check). Changes nothing.
# Finds out whether this PC is the master or a client and lists every item as OK / WARN / FAIL with what to do.
#   Tool-Check.ps1                 auto (master = has C:\lwserver or the watcher autostart)
#   Tool-Check.ps1 -Mode client    check as a client
# Result also in C:\Users\Public\OSYNC-Check.log. Exit code 1 when something is FAIL.
param([ValidateSet('auto', 'master', 'client')][string]$Mode = 'auto')
. (Join-Path $PSScriptRoot 'Common.ps1')
$isMaster = if ($Mode -eq 'auto') { Test-IsMaster } else { $Mode -eq 'master' }
$rows = New-Object System.Collections.Generic.List[object]
function Add([string]$level, [string]$item, [string]$detail, [string]$fix = '') { $rows.Add([pscustomobject]@{ Level = $level; Item = $item; Detail = $detail; Fix = $fix }) }
function Age([datetime]$t) { $h = ((Get-Date) - $t).TotalHours; if ($h -lt 1) { '{0:N0} min ago' -f ($h * 60) } elseif ($h -lt 48) { '{0:N0} h ago' -f $h } else { '{0:N0} days ago' -f ($h / 24) } }
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

# ---------- both ----------
$missing = @('OSYNC.bat', 'Settings\settings.txt', 'System\Client\Boot.ps1', 'System\Client\Riot.vbs', 'System\Client\Epic.vbs', 'System\Client\Menu.vbs') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) }
if ($missing) { Add 'FAIL' 'OSYNC files' ("missing: " + ($missing -join ', ')) 'copy the OSYNC folder again' } else { Add 'OK' 'OSYNC files' $Root }
$shared = Get-SharedDrives
$noDrive = @($shared.ToCharArray() | Where-Object { -not (Test-Path "${_}:\") })
if ($noDrive) { Add 'FAIL' 'Shared drives' "SharedDrives=$shared but not on this PC: $($noDrive -join ', ')" 'fix Settings\settings.txt (letters the clients see)' }
else { Add 'OK' 'Shared drives' "SharedDrives=$shared" }
if ($shared.IndexOf($Root.Substring(0, 1).ToUpper()) -lt 0) { Add 'FAIL' 'OSYNC drive' "$Root is not on a shared drive ($shared)" 'clients cannot see it: put OSYNC on a shared game drive' }
try { [void](Read-ExtraGames); Add 'OK' 'extra-games.json' 'valid' } catch { Add 'FAIL' 'extra-games.json' $_.Exception.Message 'fix the JSON in Settings\extra-games.json (a missing comma or quote)' }

# ---------- master ----------
if ($isMaster) {
    # launchers: in Launchers\, or installed somewhere else (registry), or not installed
    $oldGl = $OldLauncherRoot
    $inL = @(); $outside = @(); $inOld = @()
    foreach ($l in $LauncherTable) {
        $exe = Get-LauncherExe $l.Key
        $w = Get-LauncherInstallPath $l.Key
        if (Test-Path -LiteralPath $exe) { $inL += $l.Title }
        elseif ($w -and $w.StartsWith($oldGl + '\', [StringComparison]::OrdinalIgnoreCase)) { $inOld += $l.Title }
        elseif ($w) { $outside += "$($l.Title) ($w)" }
    }
    if ($inL) { Add 'OK' 'Launchers' ("in $Launchers : " + ($inL -join ', ')) }
    if ($inOld) { Add 'WARN' 'Launchers in old folder' ("$oldGl : " + ($inOld -join ', ')) 'step B moves them (OSYNC.bat > 7 Tools > 17, shop closed)' }
    if ($outside) { Add 'WARN' 'Launchers outside' ($outside -join '; ') 'move them into Launchers: OSYNC.bat > 7 Tools > 1 (clients cannot use a launcher on C:)' }
    if (-not $inL -and -not $outside -and -not $inOld) { Add 'FAIL' 'Launchers' 'no launcher found' 'install Steam / Riot / EA / Epic, then OSYNC.bat > 4 First-time setup' }

    # Steam libraries
    $libs = @(Get-SteamLibraries)
    if ($libs) {
        $txt = ($libs | ForEach-Object { '{0} ({1} games)' -f $_, @(Get-ChildItem -LiteralPath (Join-Path $_ 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue).Count }) -join '; '
        Add 'OK' 'Steam libraries' $txt
        $sd = Get-SteamDir
        $inside = @(Get-ChildItem -LiteralPath (Join-Path $sd 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_228980\.acf$' }).Count
        if ($sd -and $inside) { Add 'WARN' 'Steam games inside Launchers' "$inside games are in $sd\steamapps" "better in $GamesRoot\Steam: OSYNC.bat > 7 Tools > 2 (works as it is)" }
    } elseif (Get-SteamDir) { Add 'WARN' 'Steam libraries' 'no Steam library on a shared drive' "move them: OSYNC.bat > 7 Tools > 2 (adds $GamesRoot\Steam to Steam)" }

    # watcher
    $run = (Get-ItemProperty $runKey -ErrorAction SilentlyContinue).'OSYNC-Master'
    $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*Master-Watch.ps1*' -and $_.CommandLine -notlike '*-Register*' })
    # two ways in at logon: the task OSYNC-Master-Watch and the Run entry (Windows once skipped the Run entry)
    $wt = $null; try { $wt = Get-ScheduledTask -TaskName 'OSYNC-Master-Watch' -ErrorAction Stop } catch { }
    $wtArg = if ($wt) { [string]$wt.Actions[0].Arguments } else { '' }
    if (-not $run -and -not $wt) { Add 'WARN' 'Watcher autostart' 'OFF' 'OSYNC.bat > 2 (keeps launchers open and updates clients by itself)' }
    elseif (($run -and $run -notlike "*$ScriptsDir*") -or ($wt -and $wtArg -notlike "*$ScriptsDir*")) { Add 'WARN' 'Watcher autostart' "points at another folder: $run $wtArg" 'OSYNC.bat > 2 here (after step B)' }
    elseif (-not $wt) { Add 'WARN' 'Watcher autostart' 'Run entry only (no logon task)' 'OSYNC.bat > 2 adds the logon task (Windows skipped the Run entry at a reboot)' }
    elseif ($wt.State -eq 'Disabled') { Add 'WARN' 'Watcher autostart' 'logon task is disabled' 'enable OSYNC-Master-Watch in Task Scheduler, or OSYNC.bat > 2' }
    else { Add 'OK' 'Watcher autostart' $(if ($run) { 'ON (logon task + Run entry)' } else { 'ON (logon task)' }) }
    if ($procs) {
        $from = ($procs | ForEach-Object { if ($_.CommandLine -match '-File\s+"?([^"]+Master-Watch\.ps1)') { $Matches[1] } }) -join ', '
        Add $(if ($from -like "*$ScriptsDir*") { 'OK' } else { 'WARN' }) 'Watcher running' $from $(if ($from -notlike "*$ScriptsDir*") { 'the running watcher is from another OSYNC folder' })
    } else { Add 'WARN' 'Watcher running' 'not running' 'OSYNC.bat > 2' }
    $log = 'C:\Users\Public\OSYNC-Master-Watch.log'
    if (Test-Path -LiteralPath $log) {
        $last = Get-Content -LiteralPath $log -Tail 300 -Encoding UTF8 | Where-Object { $_ -match 'client data refreshed OK|FAILED' } | Select-Object -Last 1
        if ($last -match 'FAILED') { Add 'FAIL' 'Last client update' $last 'run OSYNC.bat > 1 and read the red lines' }
        elseif ($last) { Add 'OK' 'Last client update' $last.Substring(0, 19) }
    }

    # branch runner (folder 2, C:\AT9-Branch) - only branches need it; the main shop's web wakes its own PCs
    $bState = Join-Path $env:SystemDrive 'AT9-Branch\state.json'
    $oldB = Join-Path $env:ProgramData 'CooperBranch\state.json'
    if (Test-Path -LiteralPath $bState) {
        try {
            $bs = Get-Content -LiteralPath $bState -Raw | ConvertFrom-Json
            $age = [int](([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [int64]$bs.updatedAt) / 1000)
            if ($age -gt 150) { Add 'FAIL' 'Branch runner' "not running (no news for $age s)" 'restart this PC, or OSYNC.bat > 7 Tools > 21' }
            elseif ($bs.connected) { Add 'OK' 'Branch runner' "connected as branch '$($bs.branch)' ($($bs.server))" }
            else { Add 'WARN' 'Branch runner' "not connected: $($bs.lastError)" 'it retries by itself - OSYNC.bat > 7 Tools > 21' }
        } catch { Add 'WARN' 'Branch runner' "cannot read $bState" 'OSYNC.bat > 7 Tools > 21' }
    } elseif (Test-Path -LiteralPath $oldB) { Add 'WARN' 'Branch runner' "older copy in $(Split-Path $oldB)" 'move it to C:\AT9-Branch: OSYNC.bat > 7 Tools > 20 (new install line from admin page > Branches)' }
    else { Add 'OK' 'Branch runner' 'not installed (only branches need it: OSYNC.bat > 7 Tools > 20)' }

    # data for clients
    $riotMeta = Join-Path $DataDir 'Riot\Metadata'
    if (Test-Path -LiteralPath (Get-LauncherExe 'Riot')) {
        if (-not (Test-Path -LiteralPath $riotMeta)) { Add 'FAIL' 'Riot data' 'System\Data\Riot missing' 'OSYNC.bat > 1' }
        else {
            $src = Get-ChildItem (Join-Path $env:ProgramData 'Riot Games\Metadata') -Recurse -File -Filter '*.ok' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $dst = Get-ChildItem $riotMeta -Recurse -File -Filter '*.ok' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($src -and (-not $dst -or $src.LastWriteTime -gt $dst.LastWriteTime.AddSeconds(2))) { Add 'WARN' 'Riot data' 'a Riot game was updated after the last copy' 'OSYNC.bat > 1 (or wait for the watcher)' }
            else { Add 'OK' 'Riot data' ("up to date (last Riot game update " + $(if ($dst) { Age $dst.LastWriteTime } else { '?' }) + ')') }
            $busy = @(Get-RiotBusy); if ($busy) { Add 'WARN' 'Riot updating' ($busy -join ', ') 'wait until Riot Client shows Play' }
        }
    }
    # Roblox: newest version on the game disk; on the master its per-user Versions folder must be the junction to it
    $rbx = Get-RobloxExe
    if ($rbx) {
        $rv = Split-Path -Leaf (Split-Path -Parent $rbx)
        $j = Get-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Force -ErrorAction SilentlyContinue
        $jOk = $j -and ($j.LinkType -eq 'Junction') -and ("$($j.Target)".TrimEnd('\') -ieq (Join-Path $Launchers 'Roblox\Versions'))
        if ($isMaster -and -not $jOk) { Add 'WARN' 'Roblox' "$rv on the game disk, but Roblox on this PC updates into C: (no junction)" 'see HOW-IT-WORKS: Roblox' }
        else { Add 'OK' 'Roblox' "$rv on the game disk$(if ($isMaster) { ' (updates land there)' })" }
    }
    # FiveM / RedM: CitizenFX.ini next to them must point at a usable GTA V Legacy / RDR2 folder, or clients get a file dialog
    foreach ($s in @(Get-CfxStatus)) {
        if ($s.HaveOk) { Add 'OK' $s.Name "game folder: $($s.Have)" }
        elseif ($s.Want) { Add 'WARN' $s.Name "not pointed at $($s.Game) ($(if ($s.Have) { "IVPath=$($s.Have) is not usable" } else { 'no IVPath' })) - clients get a file dialog" "OSYNC.bat > 1 (points it at $($s.Want))" }
        else { Add 'WARN' $s.Name "$($s.Game) not found on the drives the clients see - clients get a file dialog" "install $($s.Game) on the game disk (Steam)$(if ($s.Name -eq 'FiveM') { ' - FiveM cannot use GTA V Enhanced' })" }
    }
    if (Test-Path -LiteralPath (Join-Path (Get-LauncherDir 'EA') 'EA Desktop')) {
        $f = Join-Path $DataDir 'EA\ea-client.reg'
        if (Test-Path -LiteralPath $f) { Add 'OK' 'EA data' ("made " + (Age (Get-Item $f).LastWriteTime)) } else { Add 'FAIL' 'EA data' 'System\Data\EA missing' 'OSYNC.bat > 1' }
    }

    # menu (before step B it is still GCafe\)
    $mi = Get-MenuInfo
    $menuPending = -not (Test-Path -LiteralPath $Menu) -and (Test-Path -LiteralPath $OldMenuDir)
    if ($menuPending) { Add 'WARN' 'Menu' "still in $OldMenuDir" 'step B renames it to Menu\ (OSYNC.bat > 7 Tools > 17, shop closed)' }
    elseif (-not $mi.Config) { Add 'FAIL' 'Menu config' "$Menu\config.json missing or not valid" 'fix the JSON (shop name / logo)' } else { Add 'OK' 'Menu config' "shop name: $($mi.Config.brandName)" }
    if ($menuPending) { }
    elseif (Test-Path -LiteralPath $mi.Exe) {
        Add 'OK' 'Menu program' $mi.Exe
        $src = Join-Path $Menu 'source'
        if (Test-Path -LiteralPath $src) {
            $newest = Get-ChildItem (Join-Path $src 'src'), (Join-Path $src 'electron') -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($newest -and $newest.LastWriteTime -gt (Get-Item $mi.Exe).LastWriteTime) { Add 'WARN' 'Menu program' "source changed after the build ($($newest.Name))" 'OSYNC.bat > 7 Tools > 3 (close the menu first)' }
        }
    } else { Add 'FAIL' 'Menu program' "not built: $($mi.Exe)" 'OSYNC.bat > 7 Tools > 3' }
    $gj = Join-Path $Menu 'data\games.json'
    if ($menuPending) { }
    elseif (-not (Test-Path -LiteralPath $gj)) { Add 'FAIL' 'Game list' 'Menu\data\games.json missing' 'OSYNC.bat > 1' }
    else {
        try {
            $list = @((Get-Content -LiteralPath $gj -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })
            Add 'OK' 'Game list' (("{0} games: " -f $list.Count) + (($list | Group-Object cat | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', '))
            $bad = @(foreach ($g in $list) {
                $m = [regex]::Match("$($g.cmd)", '"([A-Za-z]:\\[^"]+\.(exe|vbs|bat))"')
                if ($m.Success -and -not (Test-Path -LiteralPath $m.Groups[1].Value)) { "$($g.title) -> $($m.Groups[1].Value)" }
            })
            if ($bad) { Add 'FAIL' 'Game list paths' ($bad -join '; ') 'OSYNC.bat > 1 (scan again)' }
            $old = @($list | Where-Object { $_.cmd -notlike "*$Root*" -and ($_.cmd -match 'GAMELUNCHER|\\ClientSetup\\') })
            if ($old) { Add 'WARN' 'Game list paths' "$($old.Count) games still start from the old folder" 'OSYNC.bat > 1 after step B' }
        } catch { Add 'FAIL' 'Game list' "not valid JSON: $($_.Exception.Message)" 'OSYNC.bat > 1' }
    }
    if (Test-Path -LiteralPath $OldLauncherRoot) { Add 'WARN' 'Old layout' "$Root still runs the old layout (GAMELUNCHER, GCafe, old buttons)" 'step B: OSYNC.bat > 7 Tools > 17 when the shop is closed' }
    # loose files a launcher installer dropped straight into the launchers folder (no folder of its own)
    foreach ($lr in @($OldLauncherRoot, (Join-Path $Root 'Launchers'))) {
        $loose = @(Get-ChildItem -LiteralPath $lr -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(exe|dll)$' })
        if ($loose) { Add 'WARN' 'Loose launcher files' "$($loose.Count) exe/dll straight in $lr (e.g. $($loose[0].Name))" 'an installer used the folder itself - gather them into a folder of their own' }
    }
}

# ---------- client ----------
if (-not $isMaster) {
    $task = Get-ScheduledTask -TaskName 'OSYNC-Client-Boot' -ErrorAction SilentlyContinue
    if (-not $task) { Add 'WARN' 'Boot setup task' 'missing' 'OSYNC.bat > 5 in super workstation mode, then save the image' }
    else {
        $argsTxt = "$($task.Actions[0].Arguments)"
        $cmd = if ($argsTxt -match '-EncodedCommand\s+(\S+)') { [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1])) } else { $argsTxt }
        if ($cmd -like "*$ClientDir*") { Add 'OK' 'Boot setup task' 'points at this folder' } else { Add 'FAIL' 'Boot setup task' "points elsewhere: $cmd" 'OSYNC.bat > 5 in super workstation mode, then save the image' }
    }
    $rs = (Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).RiotStart
    if (-not $rs) { Add 'WARN' 'Riot at logon' 'not set' 'OSYNC.bat > 5' } elseif ($rs -like "*$ClientDir*") { Add 'OK' 'Riot at logon' 'set' } else { Add 'FAIL' 'Riot at logon' "points elsewhere: $rs" 'OSYNC.bat > 5' }
    if (Get-Service vgc -ErrorAction SilentlyContinue) { Add 'OK' 'Riot Vanguard' 'installed' } else { Add 'WARN' 'Riot Vanguard' 'not installed' 'install Vanguard in super workstation mode, save the image' }
    $sh = New-Object -ComObject WScript.Shell
    $lnk = Get-ChildItem (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp') -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $s = $sh.CreateShortcut($_.FullName); "$($s.TargetPath) $($s.Arguments)" -match 'Menu\.vbs|\\app\\[^\\]+\.exe' } | Select-Object -First 1
    if (-not $lnk) { Add 'WARN' 'Menu at logon' 'no shortcut' 'OSYNC.bat > 5' }
    else { $s = $sh.CreateShortcut($lnk.FullName); $t = "$($s.TargetPath) $($s.Arguments)"; if ($t -like "*$ClientDir*") { Add 'OK' 'Menu at logon' $lnk.Name } else { Add 'FAIL' 'Menu at logon' "old shortcut: $t" 'OSYNC.bat > 5' } }
    $ea = Get-CimInstance Win32_Service -Filter "Name='EABackgroundService'" -ErrorAction SilentlyContinue
    if ($ea) { if ($ea.PathName -like "*$Launchers*") { Add 'OK' 'EA service' 'points at Launchers' } else { Add 'WARN' 'EA service' "points elsewhere: $($ea.PathName)" 'OSYNC.bat > 5' } }
    $acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP
    if ($acp -eq '874') { Add 'OK' 'Thai text' 'code page 874' } else { Add 'WARN' 'Thai text' "code page $acp (Thai in old games shows as alien letters)" 'OSYNC.bat > 7 Tools > 8' }
    $bl = Join-Path $env:PUBLIC 'OSYNC-Boot-Setup.log'
    if (Test-Path -LiteralPath $bl) {
        $fails = @(Get-Content -LiteralPath $bl -Encoding UTF8 | Where-Object { $_ -match '^\d .{30,}\s+\d+ s\s+FAIL' })
        if ($fails) { Add 'WARN' 'Last boot setup' ($fails -join '; ') "read $bl" } else { Add 'OK' 'Last boot setup' ("no failures, " + (Age (Get-Item $bl).LastWriteTime)) }
    }
}

# ---------- print ----------
$color = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }
$head = "OSYNC check  {0}  {1} = {2}  {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $env:COMPUTERNAME, $(if ($isMaster) { 'MASTER' } else { 'CLIENT' }), $Root
Write-Host $head -ForegroundColor Cyan
$lines = New-Object System.Collections.Generic.List[string]; $lines.Add($head)
foreach ($r in $rows) {
    $l = '[{0,-4}] {1,-28} {2}' -f $r.Level, $r.Item, $r.Detail
    Write-Host $l -ForegroundColor $color[$r.Level]; $lines.Add($l)
    if ($r.Fix -and $r.Level -ne 'OK') { Write-Host ('{0,36}-> {1}' -f '', $r.Fix) -ForegroundColor DarkGray; $lines.Add(('{0,36}-> {1}' -f '', $r.Fix)) }
}
$sum = 'OK {0}   WARN {1}   FAIL {2}' -f @($rows | Where-Object Level -eq 'OK').Count, @($rows | Where-Object Level -eq 'WARN').Count, @($rows | Where-Object Level -eq 'FAIL').Count
Write-Host $sum -ForegroundColor Cyan; $lines.Add($sum)
try { [IO.File]::WriteAllLines((Join-Path $env:PUBLIC 'OSYNC-Check.log'), $lines) } catch {}
if ($rows | Where-Object Level -eq 'FAIL') { exit 1 }
