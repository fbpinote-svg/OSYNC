# Client-OslinkReport.ps1 - CLIENT PC, temporary diagnosis (17 Nov 2026): what OSLink and its 3 input drivers look like on this PC,
# sent to the master (http://<MasterIP>:4670/oslink-report, LAN only) so the owner does not have to read logs on the client.
# Client-Install step 1n starts it in the background at boot (Settings ClientOslinkReport=on): a report after 2.5 and after 6 min.
#   Client-OslinkReport.ps1 -Phase <text> [-DelaySeconds <n>]     -Print = show it here instead of sending it
# -WaitSteamMinutes <n> (18 Nov 2026, Steam "Updating Steam..." at every start on clients): wait until Steam has run on this PC
#   (its bootstrap_log.txt has a line from after this boot), give it 4 more minutes, then send - nothing sent if Steam never ran.
# -WaitFiveMMinutes <n> (18 Nov 2026, do the servers' files the master fetched work on clients?): wait until FiveM on this PC has
#   joined a server (CitizenFX log from after this boot with "Downloading completed"), then send - nothing sent if it never did.
# -WaitRiotMinutes <n> (18 Nov 2026, VALORANT "UPDATING" on a client): wait until Riot Client on this PC has shown VALORANT, then send.
# -WaitApexMinutes <n> (19 Nov 2026, Apex closes at "Starting EA Javelin Anticheat..."): wait until someone starts Apex on this PC,
#   watch it for up to 3 min (did r5apex start, how long did it live), then send - nothing sent if Apex never started.
param([string]$Phase = 'manual', [int]$DelaySeconds = 0, [switch]$Print, [int]$WaitSteamMinutes = 0, [int]$WaitFiveMMinutes = 0, [int]$WaitRiotMinutes = 0, [int]$WaitApexMinutes = 0)
. (Join-Path $PSScriptRoot 'Common.ps1')
# 18 Nov 2026: the content of Steam's key files as THIS PC reads them at boot (before Steam rewrites them), compared on the master
$SteamFileList = 'package\steam_client_win64.installed', 'package\steam_client_win64.manifest', 'steam.exe', 'steamclient64.dll', 'steamui.dll', 'tier0_s64.dll', 'vstdlib_s64.dll', 'bin\cef\cef.win64\steamwebhelper.exe'
$SteamBootHashes = @()
if ($Phase -eq 'boot+150s') {
  $sdir = 'F:\steam'
  $SteamBootHashes += "taken $(Get-Date -Format 'HH:mm:ss') from $sdir"
  foreach ($rel in $SteamFileList) {
    $p = Join-Path $sdir $rel
    try { $i = Get-Item -LiteralPath $p -ErrorAction Stop; $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash; $SteamBootHashes += "$rel | $($i.Length) | $($i.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z | $h" }
    catch { $SteamBootHashes += "$rel | READ ERROR $($_.Exception.Message)" }
  }
}
if ($DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
function Get-SteamDirs {
  $d = @()
  foreach ($k in @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' })) {
    $p = (Get-ItemProperty "Registry::HKEY_USERS\$($k.PSChildName)\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if ($p) { $p = ($p -replace '/', '\').TrimEnd('\'); if ($d -notcontains $p) { $d += $p } }
  }
  $m = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
  if ($m -and $d -notcontains $m.TrimEnd('\')) { $d += $m.TrimEnd('\') }
  if (-not $d.Count -and (Test-Path -LiteralPath 'F:\steam\steam.exe')) { $d += 'F:\steam' }
  $d
}
function Get-SteamLogSinceBoot([string]$dir, [datetime]$since) {
  @(Get-Content -LiteralPath (Join-Path $dir 'logs\bootstrap_log.txt') -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]' -and [datetime]$Matches[1] -ge $since })
}
function Get-FiveMLogs([datetime]$since) {
  $roots = @(foreach ($d in (Get-SharedDrives).ToCharArray()) { Get-ChildItem "${d}:\*\FiveM\FiveM.app\logs", "${d}:\FiveM\FiveM.app\logs" -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName })
  $roots += @(Get-ChildItem 'C:\Users\*\AppData\Local\FiveM\FiveM.app\logs' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
  @(foreach ($r in ($roots | Sort-Object -Unique)) { Get-ChildItem -LiteralPath $r -Filter 'CitizenFX_log*.log' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since } }) | Sort-Object LastWriteTime
}
function Get-RiotLogs([datetime]$since) {
  @(foreach ($d in @(Resolve-Path 'C:\Users\*\AppData\Local\Riot Games\Riot Client\Logs\Riot Client Logs' -ErrorAction SilentlyContinue | ForEach-Object Path)) { Get-ChildItem -LiteralPath $d -Filter '*.log' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since } }) | Sort-Object LastWriteTime
}
if ($WaitRiotMinutes -gt 0) {
  $bootAt = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  $until = (Get-Date).AddMinutes($WaitRiotMinutes); $seen = $false
  while ((Get-Date) -lt $until -and -not $seen) {
    foreach ($lg in Get-RiotLogs $bootAt) { if (Select-String -LiteralPath $lg.FullName -Pattern 'productId: valorant' -Quiet) { $seen = $true } }
    if (-not $seen) { Start-Sleep -Seconds 30 }
  }
  if (-not $seen) { exit 0 }
  Start-Sleep -Seconds 120
}if ($WaitFiveMMinutes -gt 0) {
  $bootAt = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  $until = (Get-Date).AddMinutes($WaitFiveMMinutes); $seen = $false
  while ((Get-Date) -lt $until -and -not $seen) {
    foreach ($lg in Get-FiveMLogs $bootAt) { if (Select-String -LiteralPath $lg.FullName -Pattern 'Downloading completed' -Quiet) { $seen = $true } }
    if (-not $seen) { Start-Sleep -Seconds 30 }
  }
  if (-not $seen) { exit 0 }
  Start-Sleep -Seconds 60
}if ($WaitSteamMinutes -gt 0) {
  $bootAt = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  $until = (Get-Date).AddMinutes($WaitSteamMinutes); $seen = $false
  while ((Get-Date) -lt $until -and -not $seen) { foreach ($sd in Get-SteamDirs) { if ((Get-SteamLogSinceBoot $sd $bootAt).Count) { $seen = $true } }; if (-not $seen) { Start-Sleep -Seconds 20 } }
  if (-not $seen) { exit 0 }
  Start-Sleep -Seconds 240
}
$ApexWatch = @()
if ($WaitApexMinutes -gt 0) {
  $until = (Get-Date).AddMinutes($WaitApexMinutes); $seen = $false
  while ((Get-Date) -lt $until -and -not $seen) { if (Get-Process -Name 'EAAntiCheat.GameServiceLauncher', 'r5apex*' -ErrorAction SilentlyContinue) { $seen = $true } else { Start-Sleep -Seconds 5 } }
  if (-not $seen) { exit 0 }
  $t0 = Get-Date; $first = $null; $last = $null; $svcUp = $false
  while (((Get-Date) - $t0).TotalSeconds -lt 180) {
    if (Get-Process -Name 'r5apex*' -ErrorAction SilentlyContinue) { if (-not $first) { $first = Get-Date }; $last = Get-Date }
    if ((Get-Service -Name 'EAAntiCheatService' -ErrorAction SilentlyContinue).Status -eq 'Running') { $svcUp = $true }
    $launcher = Get-Process -Name 'EAAntiCheat.GameServiceLauncher' -ErrorAction SilentlyContinue
    if ($first -and ((Get-Date) - $first).TotalSeconds -ge 90) { break }
    if (-not $launcher -and -not (Get-Process -Name 'r5apex*' -ErrorAction SilentlyContinue) -and ((Get-Date) - $t0).TotalSeconds -gt 20) { break }
    Start-Sleep -Seconds 1
  }
  $alive = [bool](Get-Process -Name 'r5apex*' -ErrorAction SilentlyContinue)
  $ApexWatch += "Apex start seen $($t0.ToString('HH:mm:ss')) | r5apex first $(if ($first) { $first.ToString('HH:mm:ss') } else { 'never' }) last $(if ($last) { $last.ToString('HH:mm:ss') } else { '-' }) | lived about $(if ($first) { [int]($last - $first).TotalSeconds } else { 0 }) s | still running: $alive | EAAntiCheatService seen Running: $svcUp"
  $ApexWatch += "RESULT: $(if ($alive -or ($first -and ($last - $first).TotalSeconds -ge 60)) { 'APEX OK (game stayed open)' } elseif ($first) { 'APEX FAIL (game opened then closed)' } else { 'APEX FAIL (game never opened)' })"
  Start-Sleep -Seconds 5
}
$o = New-Object System.Collections.Generic.List[string]
function Add([string]$s) { $o.Add($s) }
function Sec([string]$s) { $o.Add(''); $o.Add("===== $s") }
$os = Get-CimInstance Win32_OperatingSystem
Add "OSLink report  $env:COMPUTERNAME  phase=$Phase  now=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  boot=$($os.LastBootUpTime.ToString('HH:mm:ss'))  user=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Add ("settings: " + ((Get-Content -LiteralPath $SettingsFile -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '^ClientOslink' }) -join ' | '))
$uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
Add "UAC EnableLUA=$($uac.EnableLUA) ConsentPromptBehaviorAdmin=$($uac.ConsentPromptBehaviorAdmin)"

Sec 'drivers (services)'
foreach ($n in 'LdVMou', 'LdVKbd', 'LdScpVBus') {
  $d = Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue
  $cnt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$n\Enum" -ErrorAction SilentlyContinue).Count
  Add ("{0,-10} {1}" -f $n, $(if ($d) { "state=$($d.State) start=$($d.StartMode) path=$($d.PathName) enumCount=$cnt" } else { 'NO SERVICE' }))
}
Sec 'devices'
foreach ($p in @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { ($_.HardwareID -join ' ') -match '(?i)LdVMouse|LdVKeyboard|LdScpVBus' -or $_.FriendlyName -match '(?i)Virtual Mouse|Virtual Keyboard|Scp Virtual' })) {
  $pc = (Get-PnpDeviceProperty -InstanceId $p.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data
  Add "$($p.InstanceId) | $($p.FriendlyName) | status=$($p.Status) present=$($p.Present) problem=$pc | $($p.HardwareID -join ',')"
}
Sec 'driver store'
$cur = ''
foreach ($line in (& pnputil.exe /enum-drivers 2>&1)) { if ($line -match 'Published Name') { $cur = $line.Trim() } elseif ($line -match '(?i)ldv|ldscp|scpvbus') { Add "$cur  $($line.Trim())" } }

Sec 'OSLink processes / service'
foreach ($p in @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)^ld' })) { Add "$($p.Name) pid=$($p.ProcessId) session=$($p.SessionId) start=$($p.CreationDate.ToString('HH:mm:ss')) cmd=$($p.CommandLine)" }
$svc = Get-CimInstance Win32_Service -Filter "Name='LDRemoteSvc'" -ErrorAction SilentlyContinue
Add "LDRemoteSvc: $(if ($svc) { "$($svc.State) $($svc.StartMode) $($svc.PathName)" } else { 'NOT INSTALLED' })"
foreach ($t in 'OSYNC-Client-Boot', 'OSYNC-OslinkStart', 'OSYNC-OslinkHelper') {
  $i = Get-ScheduledTaskInfo -TaskName $t -ErrorAction SilentlyContinue
  Add "task $t : $(if ($i) { "last=$($i.LastRunTime) result=0x$('{0:X}' -f $i.LastTaskResult)" } else { 'missing' })"
}

Sec 'boot log: OSLink steps (C:\Users\Public\OSYNC-Boot-Setup.log)'
$bl = @(Get-Content 'C:\Users\Public\OSYNC-Boot-Setup.log' -ErrorAction SilentlyContinue)
$in = $false
foreach ($line in $bl) { if ($line -match '^== ') { $in = $line -match 'OSLink' }; if ($in -or $line -match 'OSLink|RESULT|^1[lmjk] ') { Add $line } }
Sec 'boot setup: RESULT table + 1f Mic + 1i Logins + 1q/1r/1u Steam + 1v Battle.net + 3 EA (C:\Users\Public\OSYNC-Boot-Setup.log)'
$in = $false; $res = $false
foreach ($line in $bl) {
  if ($line -match '^== ') { $in = $line -match '^== (0|0a|1f|1i|1q|1r|1s|1t|1u|1v|3|9) ' }    # 3 = EA (18 Nov: FAIL on KORI12 / 17)
  if ($line -match '=+ RESULT =+') { $res = $true }
  if ($in -or $res) { Add $line }
}
Sec 'Rockstar sign-in data per user (18 Nov: DigitalEntitlements from the master?)'
foreach ($u in @(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(Public|All Users|Default User)$' })) {
  foreach ($rel in 'AppData\Local\DigitalEntitlements', 'AppData\Local\Rockstar Games\Launcher', 'Documents\Rockstar Games\Social Club') {
    $p = Join-Path $u.FullName $rel
    if (Test-Path -LiteralPath $p) {
      $fs = @(Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue)
      $nw = $fs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      Add "$p : $($fs.Count) files, newest $(if ($nw) { $nw.LastWriteTime.ToString('MM-dd HH:mm:ss') + ' ' + $nw.Name } else { '-' }), folder made $((Get-Item -LiteralPath $p -Force).CreationTime.ToString('MM-dd HH:mm:ss'))"
    }
  }
}
Sec 'OslinkStart.log'
Get-Content 'C:\Users\Public\OSYNC-OslinkStart.log' -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object { Add $_ }
Sec 'setupapi.dev.log (lines about the 3 drivers / devcon, last 60)'
Get-Content "$env:SystemRoot\INF\setupapi.dev.log" -ErrorAction SilentlyContinue | Select-String -Pattern '(?i)ldvmou|ldvkbd|ldscp|ldvmouse|ldvkeyboard|devcon' | Select-Object -Last 60 | ForEach-Object { Add $_.Line }
Sec 'OSLink log files (newest, lines with driver / error)'
$bin = $null
if ($svc -and $svc.PathName -match '"?([^"]+\\)ldremote') { $bin = $Matches[1] }
$roots = @(); if ($bin) { $roots += (Split-Path -Parent $bin.TrimEnd('\')) }
$roots += @(Get-ChildItem 'C:\Users\*\AppData\Roaming', 'C:\Users\*\AppData\Local', 'C:\ProgramData' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)ldremote|oslink|ldplayer|changzhi' } | ForEach-Object FullName)
foreach ($f in @(foreach ($r in $roots) { Get-ChildItem -LiteralPath $r -Recurse -Depth 5 -File -Include *.log, *.txt -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $os.LastBootUpTime } }) | Sort-Object LastWriteTime -Descending | Select-Object -First 6) {
  Add "--- $($f.FullName) ($($f.LastWriteTime.ToString('HH:mm:ss')))"
  Get-Content -LiteralPath $f.FullName -Tail 400 -ErrorAction SilentlyContinue | Select-String -Pattern '(?i)driver|error|fail|repair|vmou|vkbd|scp|gamekey' | Select-Object -Last 25 | ForEach-Object { Add "  $($_.Line)" }
}
Sec 'Sunshine already on this PC (17 Nov: a 2nd shop Sunshine must not clash with it)'
foreach ($s in @(Get-CimInstance Win32_Service | Where-Object { $_.Name -match '(?i)sunshine' -or $_.PathName -match '(?i)sunshine' })) { Add "service $($s.Name) $($s.State) $($s.StartMode) $($s.PathName)" }
$sunDirs = @(foreach ($p in @('C:\Program Files\Sunshine', 'C:\Sunshine') + @(Get-ChildItem 'C:\Users\*\Sunshine' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)) { if (Test-Path -LiteralPath (Join-Path $p 'sunshine.exe')) { $p } })
foreach ($p in @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)sunshine' -and $_.ExecutablePath } | ForEach-Object { Split-Path -Parent $_.ExecutablePath })) { if ($sunDirs -notcontains $p) { $sunDirs += $p } }
foreach ($p in $sunDirs) {
  $exe = Join-Path $p 'sunshine.exe'
  Add "install $p  version=$((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion) file=$((Get-Item -LiteralPath $exe).VersionInfo.FileVersion)"
  $conf = Join-Path $p 'config\sunshine.conf'
  if (Test-Path -LiteralPath $conf) { Get-Content -LiteralPath $conf -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*(port|output_name|adapter_name|encoder|shop_start_with_system|shop_apply_all_ips|upnp|locale|mouse_backend|mic_backend|display_device_prep)\s*=' } | ForEach-Object { Add "  conf $($_.Trim())" } }
}
foreach ($p in @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)sunshine' })) {
  $ports = @(Get-NetTCPConnection -State Listen -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue | ForEach-Object LocalPort | Sort-Object -Unique)
  Add "process $($p.Name) pid=$($p.ProcessId) session=$($p.SessionId) listen=$($ports -join ',') cmd=$($p.CommandLine)"
}
foreach ($d in @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match '(?i)zako|virtual display|IddCx|parsec virtual|vigem|virtual gamepad' })) { Add "display/input device: $($d.FriendlyName) | $($d.InstanceId) | $($d.Status)" }
Add ("firewall: " + ((Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ' '))
foreach ($r in @(Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue | Where-Object { $_.Program -match '(?i)sunshine' })) { $rule = $r | Get-NetFirewallRule -ErrorAction SilentlyContinue; Add "  fw rule '$($rule.DisplayName)' $($rule.Direction) $($rule.Action) enabled=$($rule.Enabled) -> $($r.Program)" }

Sec 'Riot / VALORANT (18 Nov: "UPDATING" on a client while the master is up to date)'
foreach ($n in 'vgc', 'vgk') { $s = Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue; if (-not $s) { $s = Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue }; Add "Vanguard $n : $(if ($s) { "$($s.State) $($s.StartMode) $($s.PathName)" } else { 'NOT INSTALLED' })" }
$rm = 'C:\ProgramData\Riot Games\Metadata\valorant.live'
Add ("metadata valorant.live: " + ((Get-ChildItem -LiteralPath $rm -File -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name) $($_.LastWriteTime.ToString('MM-dd HH:mm'))" }) -join ', '))
Add ("RiotClientInstalls.json: " + ((Get-Content 'C:\ProgramData\Riot Games\RiotClientInstalls.json' -Raw -ErrorAction SilentlyContinue) -replace '\s+', ' '))
foreach ($lg in Get-RiotLogs $os.LastBootUpTime) {
  Add "--- $($lg.FullName) ($($lg.LastWriteTime.ToString('HH:mm:ss')))"
  Get-Content -LiteralPath $lg.FullName -ErrorAction SilentlyContinue | Where-Object { $_ -match '(?i)valorant|vanguard|vgk|vgc' -and $_ -match '(?i)status|update|patch|repair|depend|verif|error|fail|install|release|reboot|restart' -and $_ -notmatch 'telemetry' } | Select-Object -Last 25 | ForEach-Object { Add "  $($_.Substring(0, [Math]::Min(230, $_.Length)))" }
}Sec 'FiveM servers joined since this boot (18 Nov: are the master''s server files used here or downloaded again?)'
$cache = @(foreach ($d in (Get-SharedDrives).ToCharArray()) { Get-ChildItem "${d}:\*\FiveM\FiveM.app\data\server-cache-priv" -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName }) | Select-Object -First 1
if ($cache) { $cf = @(Get-ChildItem -LiteralPath $cache -File -Filter 'cache_*' -ErrorAction SilentlyContinue); Add "server-cache-priv $cache : $($cf.Count) files, $([math]::Round((($cf | Measure-Object Length -Sum).Sum)/1MB)) MB, newer than boot: $(@($cf | Where-Object { $_.LastWriteTime -gt $os.LastBootUpTime }).Count)" }
foreach ($lg in Get-FiveMLogs $os.LastBootUpTime) {
  $lines = @(Get-Content -LiteralPath $lg.FullName -ErrorAction SilentlyContinue)
  $all = ($lines -join "`n")
  $ep = ([regex]::Match($all, '\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{2,5})\b(?<!192\.168\.\d+\.\d+:\d+)')).Value
  $dl = @{}; $mt = @{}; $total = 0
  foreach ($x in $lines) {
    if ($x -match 'OnConnectionProgress: Downloading (?!completed)(\S+) \((\d+) of (\d+) - [\d\.]+/([\d\.]+) MiB\)') { $dl[$Matches[1]] = [double]$Matches[4]; $total = [int]$Matches[3] }
    elseif ($x -match 'OnConnectionProgress: Mounted (\S+) \((\d+) of (\d+)\)') { $mt[$Matches[1]] = 1; $total = [int]$Matches[3] }
  }
  $mib = [math]::Round((($dl.Values | Measure-Object -Sum).Sum), 1)
  Add "$($lg.Name) $($lg.LastWriteTime.ToString('HH:mm:ss')) server $ep : resources $total, downloaded here $($dl.Count) ($mib MiB), mounted $($mt.Count), completed=$([bool]($all -match 'Downloading completed')), connected=$([bool]($all -match 'Network connected'))"
}Add '--- FiveM share (C:\Users\Public\OSYNC-FiveMShare.log, last 8)'
Get-Content 'C:\Users\Public\OSYNC-FiveMShare.log' -Tail 8 -ErrorAction SilentlyContinue | ForEach-Object { Add "  $_" }
Sec 'Steam (18 Nov: "Updating Steam..." at every start on clients)'
foreach ($sd in Get-SteamDirs) {
  $inst = Get-Item -LiteralPath (Join-Path $sd 'package\steam_client_win64.installed') -ErrorAction SilentlyContinue
  $man = Join-Path $sd 'package\steam_client_win64.manifest'
  $ver = ''; if (Test-Path -LiteralPath $man) { $ver = ([regex]::Match([IO.File]::ReadAllText($man), '"version"\s+"(\d+)"')).Groups[1].Value }
  $exe = Get-Item -LiteralPath (Join-Path $sd 'steam.exe') -ErrorAction SilentlyContinue
  Add "dir $sd | manifest version $ver | .installed $(if ($inst) { "$($inst.Length) $($inst.LastWriteTime.ToString('MM-dd HH:mm'))" } else { 'missing' }) | steam.exe $(if ($exe) { "$($exe.VersionInfo.FileVersion) $($exe.Length)" } else { 'missing' }) | steam.cfg $(Test-Path -LiteralPath (Join-Path $sd 'steam.cfg'))"
  $all = @(Get-Content -LiteralPath (Join-Path $sd 'logs\bootstrap_log.txt') -ErrorAction SilentlyContinue)
  $since = @(Get-SteamLogSinceBoot $sd $os.LastBootUpTime)
  Add "  bootstrap_log: $($all.Count) lines, $($since.Count) since this boot"
  $all | Where-Object { $_ -notmatch '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]' -or [datetime]$Matches[1] -lt $os.LastBootUpTime } | Select-Object -Last 6 | ForEach-Object { Add "  (before boot) $_" }
  $since | Select-Object -First 150 | ForEach-Object { Add "  $_" }
  foreach ($cl in @(Get-ChildItem -LiteralPath (Join-Path $sd 'logs') -Filter 'connection_log*.txt' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $os.LastBootUpTime } | Select-Object -First 1)) { Add "  --- $($cl.Name)"; Get-Content -LiteralPath $cl.FullName -Tail 12 -ErrorAction SilentlyContinue | ForEach-Object { Add "  $_" } }
  # 18 Nov 2026 ("PLAY does nothing"): what Steam did with each game start since this boot
  $gl = @(Get-Content -LiteralPath (Join-Path $sd 'logs\console_log.txt') -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]' -and [datetime]$Matches[1] -ge $os.LastBootUpTime -and $_ -match '(?i)GameAction|Game process|ExecuteSteamURL|steam ?service' })
  if ($gl.Count) { Add "  --- console_log.txt (game starts, last 40 of $($gl.Count))"; $gl | Select-Object -Last 40 | ForEach-Object { Add "  $_" } }
  # how each game ended (exit code -1073741701 = 0xC000007B = a damaged game file, OW2 18 Nov)
  $ge = @(Get-Content -LiteralPath (Join-Path $sd 'logs\gameprocess_log.txt') -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]' -and [datetime]$Matches[1] -ge $os.LastBootUpTime -and $_ -match 'adding PID|exit code' })
  if ($ge.Count) { Add "  --- gameprocess_log.txt (last 30 of $($ge.Count))"; $ge | Select-Object -Last 30 | ForEach-Object { Add "  $_" } }
}
foreach ($p in @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)^steam' })) { Add "process $($p.Name) pid=$($p.ProcessId) start=$($p.CreationDate.ToString('HH:mm:ss')) $($p.ExecutablePath)" }
if ($SteamBootHashes.Count) { Add 'Steam files as read at boot (SHA256):'; $SteamBootHashes | ForEach-Object { Add "  $_" } }
$ss = Get-Service -Name 'Steam Client Service' -ErrorAction SilentlyContinue; Add "Steam Client Service: $(if ($ss) { "$($ss.Status) $($ss.StartType)" } else { 'not installed' })"
# 18 Nov 2026 (Apex closes at "Starting EA Javelin Anticheat..."): what EA Javelin / Windows logged about it since this boot
Sec 'EA Javelin Anticheat / Apex (18 Nov: Apex closes at "Starting EA Javelin Anticheat...")'
$es = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'" -ErrorAction SilentlyContinue
if ($es) { $ex = [regex]::Match("$($es.PathName)", '^"?([^"]+?\.exe)').Groups[1].Value; Add "EAAntiCheatService: $($es.State) $($es.StartMode) $ex $((Get-Item -LiteralPath $ex -ErrorAction SilentlyContinue).VersionInfo.FileVersion)" } else { Add 'EAAntiCheatService: not installed' }
try { Add "Secure Boot: $(Confirm-SecureBootUEFI -ErrorAction Stop)" } catch { Add "Secure Boot: unknown ($($_.Exception.Message))" }
# 19 Nov 2026: the watch result (-WaitApexMinutes), EA AC's own state keys, Steam's install-script marks, crash dumps, the folder
foreach ($l in $ApexWatch) { Add $l }
foreach ($kp in 'HKLM:\SOFTWARE\EA\AC', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam\Apps\1172470', 'HKLM:\SOFTWARE\Valve\Steam\Apps\1172470') {
  $k = Get-Item -LiteralPath $kp -ErrorAction SilentlyContinue
  if ($k) { Add "$($kp -replace '^HKLM:\\', 'HKLM\'): $(($k.GetValueNames() | ForEach-Object { "$_=$($k.GetValue($_))" }) -join '; ')" }
  foreach ($sk in @(Get-ChildItem -LiteralPath $kp -Recurse -ErrorAction SilentlyContinue)) { Add "  $($sk.Name -replace '^HKEY_LOCAL_MACHINE\\', ''): $(($sk.GetValueNames() | ForEach-Object { "$_=$($sk.GetValue($_))" }) -join '; ')" }
}
foreach ($f in @(Get-ChildItem -LiteralPath 'C:\ProgramData\eaanticheat' -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 8)) { Add "file $($f.FullName) $($f.Length) $($f.LastWriteTime.ToString('MM-dd HH:mm:ss'))" }
$ag = 'E:\SteamLibrary\steamapps\common\Apex Legends'
if (Test-Path -LiteralPath $ag) { Add "Apex folder as this PC sees it: $((Get-ChildItem -LiteralPath $ag -Force -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', ')" }
foreach ($sd in Get-SteamDirs) { Get-Content -LiteralPath (Join-Path $sd 'logs\gameprocess_log.txt') -Tail 200 -ErrorAction SilentlyContinue | Where-Object { $_ -match '1172470' -and $_ -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]' -and [datetime]$Matches[1] -ge $os.LastBootUpTime } | Select-Object -Last 10 | ForEach-Object { Add "gp $_" } }
$ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $os.LastBootUpTime } -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match '(?i)javelin|anticheat' -or ($_.Id -in 1000, 1001, 1026 -and $_.Message -match '(?i)r5apex|EAAntiCheat|Javelin') })
$ev += @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $os.LastBootUpTime } -ErrorAction SilentlyContinue | Where-Object { $_.Message -match '(?i)EAAntiCheat|Javelin' })
# kernel drivers running now that are not Microsoft's (a kernel anti-cheat refuses some: vulnerable / test-signed drivers)
foreach ($d in @(Get-CimInstance Win32_SystemDriver -Filter "State='Running'" -ErrorAction SilentlyContinue)) {
  $p = [Environment]::ExpandEnvironmentVariables(("$($d.PathName)" -replace '^\\\?\?\\', '' -replace '^(?i)\\SystemRoot', $env:SystemRoot -replace '^(?i)system32', "$env:SystemRoot\System32"))
  $vi = (Get-Item -LiteralPath $p -ErrorAction SilentlyContinue).VersionInfo
  if ($vi -and "$($vi.CompanyName)" -match '(?i)microsoft') { continue }
  Add ("driver {0,-22} {1} | {2} {3}" -f $d.Name, $p, $vi.CompanyName, $vi.FileVersion)
}
try { $bcd = (& bcdedit.exe /enum '{current}' 2>$null) -match '(?i)testsigning|nointegritychecks|debug|hypervisorlaunchtype'; Add "bcdedit: $(if ($bcd) { ($bcd | ForEach-Object { $_.Trim() -replace '\s+', ' ' }) -join ' | ' } else { 'no testsigning / debug lines' })" } catch { }if (-not $ev.Count) { Add 'no Javelin / Apex events since this boot' }
foreach ($e in @($ev | Sort-Object TimeCreated | Select-Object -Last 15)) { $m = "$($e.Message)" -replace '\s+', ' '; if ($m.Length -gt 400) { $m = $m.Substring(0, 400) }; Add ("{0:HH:mm:ss} {1} {2} id={3}: {4}" -f $e.TimeCreated, $e.LogName, $e.ProviderName, $e.Id, $m) }

Sec 'ldremote logs (last 30 lines each, unfiltered: why ldremote --pcstart exits)'
if ($bin) {
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $bin 'log') -Filter 'ldremote*.log' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'service' -and $_.LastWriteTime -gt $os.LastBootUpTime })) {
    Add "--- $($f.Name) ($($f.LastWriteTime.ToString('HH:mm:ss')))"
    Get-Content -LiteralPath $f.FullName -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object { Add "  $_" }
  }
}

Sec 'sound / mic of our menu system + game starts (20 Nov 2026: Client-Mic default watch, Client-GameStart)'
foreach ($lf in 'OSYNC-AudioDefaults.log', 'OSYNC-GameStart.log') {
  $lp = Join-Path $env:PUBLIC $lf
  if (Test-Path -LiteralPath $lp) { Add "--- $lf"; Get-Content -LiteralPath $lp -Tail 12 -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { Add "  $_" } } else { Add "${lf}: none yet" }
}
# 20 Nov 2026 (owner: Sunshine does not find VB-CABLE): what Sunshine 0JAYSHOP said about the remote player's mic (0JayMic)
foreach ($sl in @((Join-Path $ToolsDir 'Sunshine0J\config\sunshine.log'))) {
  if (Test-Path -LiteralPath $sl) { Add "--- $sl (mic lines, last 12)"; Get-Content -LiteralPath $sl -Tail 4000 -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '(?i)0JayMic|Mic sink|mic redirect|mic_backend|virtual audio sink' } | Select-Object -Last 12 | ForEach-Object { Add "  $_" } } else { Add "no $sl" }
}
Add ("speakers / mics now: {0}" -f ((@(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue) | ForEach-Object { "$($_.FriendlyName) [$($_.Status)]" }) -join ', '))
# 20 Nov 2026: on one Win10 image (KORI02/06/08/11/13/17/18/19/20/24) WO Mic stays "NOT installed" (devcon install exit 1,
# no working device) while Win11 boots install it fine - read-only look at OUR two drivers only (WO Mic, VB-CABLE)
Add 'WO Mic / VB-CABLE device nodes (any state):'
foreach ($d in @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { "$($_.HardwareID)" -match '(?i)WOMic|VBAudio' -or "$($_.FriendlyName)" -match '(?i)WO Mic|VB-Audio' })) {
  $pcode = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data
  $dinf = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue).Data
  Add ("  {0} | {1} | class={2} status={3} present={4} problem={5} inf={6}" -f $d.InstanceId, $d.FriendlyName, $d.Class, $d.Status, $d.Present, $pcode, $dinf)
}
$wv = Get-CimInstance Win32_SystemDriver -Filter "Name='WOVAD'" -ErrorAction SilentlyContinue
if ($wv) { Add ("WOVAD service: state={0} start={1} path={2}" -f $wv.State, $wv.StartMode, $wv.PathName) } else { Add 'WOVAD service: none' }
$wsys = Join-Path $env:SystemRoot 'System32\drivers\womic.sys'
if (Test-Path -LiteralPath $wsys) {
  $wi = Get-Item -LiteralPath $wsys; $sg = Get-AuthenticodeSignature -LiteralPath $wsys -ErrorAction SilentlyContinue
  Add ("womic.sys: {0} bytes, version {1}, {2:yyyy-MM-dd HH:mm}, signature {3} ({4})" -f $wi.Length, $wi.VersionInfo.FileVersion, $wi.LastWriteTime, $sg.Status, $(if ($sg.SignerCertificate) { $sg.SignerCertificate.Subject } else { '-' }))
} else { Add 'womic.sys: not in System32\drivers' }
try { Add ("Secure Boot: {0}" -f (Confirm-SecureBootUEFI -ErrorAction Stop)) } catch { Add "Secure Boot: unknown ($($_.Exception.Message))" }
$pe = @(pnputil /enum-drivers 2>$null)
for ($i = 0; $i -lt $pe.Count; $i++) { if ($pe[$i] -match '(?i)womic\.inf|vbmmecable|vbaudio') { Add ('driver store: ' + (($pe[[Math]::Max(0, $i - 1)..[Math]::Min($pe.Count - 1, $i + 5)] | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' | ')) } }
$sa = Join-Path $env:SystemRoot 'INF\setupapi.dev.log'
if (Test-Path -LiteralPath $sa) {
  $sl = @(Get-Content -LiteralPath $sa -Tail 4000 -ErrorAction SilentlyContinue)
  $st = -1; for ($i = $sl.Count - 1; $i -ge 0; $i--) { if ($sl[$i] -match '(?i)^>>>.*womic') { $st = $i; break } }
  if ($st -ge 0) {
    Add '--- setupapi.dev.log: last WO Mic install (section lines, errors, reboot / problem lines - max 30)'
    $sl[$st..([Math]::Min($sl.Count - 1, $st + 500))] | Where-Object { $_ -match '^(>>>|<<<)|!!!|^\s+!\s|(?i)reboot|restart|problem|exit status|signature|code \d' } | Select-Object -First 30 | ForEach-Object { Add "  $_" }
  } else { Add 'setupapi.dev.log: no WO Mic install section in the last 4000 lines' }
}

$text = $o -join "`r`n"
if ($Print) { $text; exit 0 }
$ip = Get-Setting 'MasterIP' ''
if (-not $ip) { exit 0 }
try { Invoke-WebRequest -Uri "http://${ip}:4670/oslink-report" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($text)) -ContentType 'text/plain; charset=utf-8' -UseBasicParsing -TimeoutSec 15 | Out-Null } catch { }
exit 0
