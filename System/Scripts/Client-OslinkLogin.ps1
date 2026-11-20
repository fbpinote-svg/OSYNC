# Client-OslinkLogin.ps1 - CLIENT (Client-Install step 1k, at boot as SYSTEM): OSLink signed in with the support account
# that is signed in on the master, as THIS PC, without anyone signing in on the client (16 Nov, user chose "automatic").
# OSLink's sign-in key belongs to one PC (tests on AT9COM22, 16 Nov): with the master's key and the master's MAC every client
# looked like the master (could not connect / dropped); without the MAC, OSLink asked "new computer?", registered the PC
# with a NEW key - and the next diskless boot lost it ("please sign in again").
# So each PC's own key is kept on the master (Master-OslinkLogins.ps1, http://<MasterIP>:<OslinkLoginPort>/oslink-login,
# chosen by this PC's IP) and put back here before OSLink starts:
#   record on the master  -> restore this PC's own account files (accounts\<uid>\userinfo.config, user.ini, lastuser.data),
#                            its own MAC (settings.config "cacheIpAdress") and its own device id (registry rcmac)
#   no record yet         -> first time: only the master's MAC is removed, the master's sign-in stays, so OSLink registers
#                            this PC as a computer of its own; the logon helper (Client-OslinkHelper.ps1, task
#                            OSYNC-OslinkHelper) answers OSLink's "new computer?" with "yes" and sends the new key to the master
#   master not reachable  -> nothing changed (OSLink as before)
# OSLink (service LDRemoteSvc + ldremote) is stopped while the files change and started again. Writes land in this PC's own
# copy of the game disk / C: (diskless) - nothing on the master changes from here.
# Never on the master. -CheckOnly: ask the master and report only. -TestDir <folder>: <folder>\userData = a fake OSLink,
# registry = HKCU\Software\OSYNC-OslinkLoginTest\m (machine) and \u (user), no service / task touched.
# -Master <host:port> overrides MasterIP + OslinkLoginPort (tests).
param([switch]$CheckOnly, [string]$TestDir, [string]$Master)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir -and -not $CheckOnly) { Write-Host 'OSLink login: this is the master - nothing changed'; exit 0 }
if (-not $TestDir -and -not $CheckOnly -and -not (Test-Admin)) { Write-Host 'OSLink login: run as administrator.' -ForegroundColor Red; exit 1 }

$SvcName = 'LDRemoteSvc'
$port = Get-Setting 'OslinkLoginPort' '4669'
$hostPort = if ($Master) { $Master } else { "$(Get-Setting 'MasterIP' ''):$port" }
$stateFile = if ($TestDir) { Join-Path $TestDir 'state.json' } else { Join-Path $env:PUBLIC 'OSYNC-OslinkLogin.state.json' }

function Find-OslinkRoot {
  $svc = Get-CimInstance Win32_Service -Filter "Name='$SvcName'" -ErrorAction SilentlyContinue
  if ($svc -and $svc.PathName) {
    $m = [regex]::Match($svc.PathName, '^\s*"([^"]+)"'); if (-not $m.Success) { $m = [regex]::Match($svc.PathName, '^\s*(\S+?\.exe)') }
    if ($m.Success) { $r = Split-Path -Parent (Split-Path -Parent $m.Groups[1].Value); if (Test-Path -LiteralPath (Join-Path $r 'userData')) { return $r } }
  }
  foreach ($d in (Get-SharedDrives).ToCharArray()) { $r = "${d}:\LDPlayer\OSLink"; if (Test-Path -LiteralPath (Join-Path $r 'userData')) { return $r } }
  ''
}
$olRoot = if ($TestDir) { $TestDir } else { Find-OslinkRoot }
if (-not $olRoot) { Write-Host 'OSLink login: OSLink not found (no LDPlayer\OSLink\userData) - skipped'; exit 0 }
$acc = Join-Path $olRoot 'userData\accounts'
$settings = Join-Path $acc 'settings.config'
if (-not ($hostPort -match '^[^:]+:\d+$') -or $hostPort.StartsWith(':')) { Write-Host 'OSLink login: no MasterIP in settings - skipped'; exit 0 }

# ---------- ask the master for this PC's record ----------
function Get-Record {
  for ($i = 0; $i -lt 8; $i++) {
    try {
      $rq = [Net.HttpWebRequest]::Create("http://$hostPort/oslink-login"); $rq.Timeout = 3000; $rq.ReadWriteTimeout = 3000
      $rs = $rq.GetResponse(); $sr = New-Object IO.StreamReader($rs.GetResponseStream(), [Text.Encoding]::UTF8); $t = $sr.ReadToEnd(); $rs.Close()
      return @{ State = 'found'; Record = ($t | ConvertFrom-Json) }
    } catch [Net.WebException] {
      $r = $_.Exception.Response
      if ($r -and [int]$r.StatusCode -eq 404) { return @{ State = 'none' } }
      if ($r) { return @{ State = 'error'; Why = "HTTP $([int]$r.StatusCode)" } }
    } catch { }
    Start-Sleep -Seconds 2   # network may not be up yet right after boot
  }
  @{ State = 'unreachable' }
}
$got = Get-Record
if ($CheckOnly) {
  switch ($got.State) {
    'found' { Write-Host "OSLink login: the master has this PC's own sign-in ($($got.Record.pc), saved $($got.Record.at)) - would restore it" }
    'none' { Write-Host 'OSLink login: no own sign-in on the master yet - would prepare the first sign-in (remove the master''s MAC)' }
    default { Write-Host "OSLink login: master $hostPort not reachable ($($got.State) $($got.Why)) - would change nothing" }
  }
  exit 0
}
if ($got.State -ne 'found' -and $got.State -ne 'none') {
  Write-Host "OSLink login: master $hostPort not reachable ($($got.State) $($got.Why)) - OSLink left as it is"
  [IO.File]::WriteAllText($stateFile, (ConvertTo-Json @{ mode = 'none'; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); pc = $env:COMPUTERNAME; master = $hostPort }), (New-Object Text.UTF8Encoding($false)))
  exit 0
}

# ---------- registry helpers (machine + every user's hive incl. Default; hives of users not logged on loaded for a moment) ----------
$script:mounted = New-Object System.Collections.Generic.List[string]
function Get-RcmacKeys {
  $l = New-Object System.Collections.Generic.List[object]
  if ($TestDir) {
    $l.Add(@([Microsoft.Win32.Registry]::CurrentUser, 'Software\OSYNC-OslinkLoginTest\m\SOFTWARE\ld\OSLink', 'machine'))
    $l.Add(@([Microsoft.Win32.Registry]::CurrentUser, 'Software\OSYNC-OslinkLoginTest\u\Software\ld\OSLink', 'user'))
    return , $l
  }
  $l.Add(@([Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64'), 'SOFTWARE\ld\OSLink', 'machine'))
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
  $profiles = @(foreach ($k in @(Get-ChildItem -LiteralPath $pl -ErrorAction SilentlyContinue)) {
      if ($k.PSChildName -notmatch '^S-1-5-21-[\d-]+$') { continue }
      $p = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath)")
      if ($p -and (Test-Path -LiteralPath $p)) { [pscustomobject]@{ Name = (Split-Path -Leaf $p); Path = $p; Sid = $k.PSChildName } }
    })
  $profiles += [pscustomobject]@{ Name = 'Default'; Path = (Join-Path $env:SystemDrive 'Users\Default'); Sid = '' }
  $n = 0
  foreach ($p in $profiles) {
    if ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)")) { $l.Add(@([Microsoft.Win32.Registry]::Users, "$($p.Sid)\Software\ld\OSLink", 'user')); continue }
    $dat = Join-Path $p.Path 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $dat)) { continue }
    $mount = "OSYNC_OL_$n"; $n++
    & reg.exe load "HKU\$mount" "$dat" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $script:mounted.Add($mount); $l.Add(@([Microsoft.Win32.Registry]::Users, "$mount\Software\ld\OSLink", 'user')) }
  }
  , $l
}
# rcmac as the logon helper will read it back (machine = HKLM; user = the logged-on user's HKCU - unknown at boot as SYSTEM,
# '' then, which only means the helper sends once more)
function Get-RcmacNow([string]$which) {
  $base = if ($TestDir) { [Microsoft.Win32.Registry]::CurrentUser } elseif ($which -eq 'machine') { [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64') } else { return '' }
  $sub = if ($TestDir) { if ($which -eq 'machine') { 'Software\OSYNC-OslinkLoginTest\m\SOFTWARE\ld\OSLink' } else { 'Software\OSYNC-OslinkLoginTest\u\Software\ld\OSLink' } } else { 'SOFTWARE\ld\OSLink' }
  $k = $base.OpenSubKey($sub); if (-not $k) { return '' }
  try { "$($k.GetValue('rcmac', ''))" } finally { $k.Close() }
}
function Close-Hives { if ($script:mounted.Count) { [GC]::Collect(); [GC]::WaitForPendingFinalizers(); foreach ($m in $script:mounted) { & reg.exe unload "HKU\$m" 2>$null | Out-Null }; $script:mounted.Clear() } }

function Read-Settings {
  $map = [ordered]@{}
  if (-not (Test-Path -LiteralPath $settings)) { return $map }
  $raw = ([IO.File]::ReadAllText($settings)).Trim([char]0xFEFF).Trim()
  if ($raw) { foreach ($p in ($raw | ConvertFrom-Json).PSObject.Properties) { $map[$p.Name] = $p.Value } }
  $map
}
function Write-Settings($map) { [IO.File]::WriteAllText($settings, (ConvertTo-Json -InputObject $map -Depth 5), (New-Object Text.UTF8Encoding($false))) }

# ---------- stop OSLink while its files change ----------
$svcObj = if ($TestDir) { $null } else { Get-Service -Name $SvcName -ErrorAction SilentlyContinue }
$startMode = if ($svcObj) { "$((Get-CimInstance Win32_Service -Filter "Name='$SvcName'" -ErrorAction SilentlyContinue).StartMode)" } else { '' }
$wasRunning = $svcObj -and $svcObj.Status -eq 'Running'
if (-not $TestDir) {
  if ($wasRunning) {
    try { Stop-Service -Name $SvcName -Force -ErrorAction Stop } catch { Write-Host "  stop $SvcName : $($_.Exception.Message)" }
    for ($i = 0; $i -lt 30 -and (Get-Service -Name $SvcName -ErrorAction SilentlyContinue).Status -ne 'Stopped'; $i++) { Start-Sleep -Milliseconds 500 }
  }
  $procs = @(Get-Process ldremote, ldremoteevent -ErrorAction SilentlyContinue)
  if ($procs.Count) { $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
}

$note = ''; $fail = @()
try {
  if ($got.State -eq 'found') {
    $r = $got.Record
    # this PC's own account files instead of the master's
    foreach ($f in @(Get-ChildItem -LiteralPath $acc -Force -ErrorAction SilentlyContinue)) {
      if (($f.PSIsContainer -and $f.Name -match '^\d+$') -or $f.Name -ieq 'lastuser.data') { Remove-Item -LiteralPath $f.FullName -Recurse -Force }
    }
    $nf = 0
    foreach ($p in $r.files.PSObject.Properties) {
      if ($p.Name -notmatch '^accounts/(\d{4,30}/(userinfo\.config|user\.ini)|lastuser\.data)$') { continue }
      $dest = Join-Path $acc (($p.Name -replace '^accounts/', '') -replace '/', '\')
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
      [IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String("$($p.Value)")); $nf++
    }
    $map = Read-Settings
    $map.Remove('cacheIpAdress')
    if ($r.mac) { $map['cacheIpAdress'] = "$($r.mac)" }
    Write-Settings $map
    $rk = @()
    try {
      foreach ($k in (Get-RcmacKeys)) {
        $v = if ($k[2] -eq 'machine') { "$($r.rcmac.hklm)" } else { "$($r.rcmac.hkcu)" }
        if (-not $v) { continue }
        $key = $k[0].CreateSubKey($k[1]); try { $key.SetValue('rcmac', $v, [Microsoft.Win32.RegistryValueKind]::String); $rk += $k[2] } finally { $key.Close() }
      }
    } finally { Close-Hives }
    $mode = 'restore'
    # fingerprint of what was put back (same as Client-OslinkHelper.ps1 Get-Hash, over what it reads back from disk and registry):
    # the helper sends again only when OSLink changed it (renewed key)
    $fh = @{}; foreach ($p in $r.files.PSObject.Properties) { if ($p.Name -match '^accounts/(\d{4,30}/(userinfo\.config|user\.ini)|lastuser\.data)$') { $fh[$p.Name] = "$($p.Value)" } }
    $hk = @{ hklm = $(if ($r.rcmac.hklm) { "$($r.rcmac.hklm)" } else { Get-RcmacNow 'machine' }); hkcu = $(if ($r.rcmac.hkcu) { "$($r.rcmac.hkcu)" } else { Get-RcmacNow 'user' }) }
    $t = (@($fh.Keys) | Sort-Object | ForEach-Object { "$_=$($fh[$_])" }) -join '|'
    $t += "|$($r.mac)|$($hk.hklm)|$($hk.hkcu)"
    $sha = [Security.Cryptography.SHA256]::Create(); try { $baseline = ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)) | ForEach-Object { $_.ToString('x2') }) -join '' } finally { $sha.Dispose() }
    $note = "restored this PC's own sign-in ($($r.pc), saved $($r.at)): $nf file(s), MAC $(if ($r.mac) { 'yes' } else { 'no' }), rcmac $(@($rk | Select-Object -Unique).Count) place(s)"
  } else {
    # first time: the master's sign-in stays, only the master's MAC goes, so OSLink registers this PC as a computer of its own
    $map = Read-Settings
    $had = $map.Contains('cacheIpAdress')
    $map.Remove('cacheIpAdress')
    if ($had -or (Test-Path -LiteralPath $settings)) { Write-Settings $map }
    $mode = 'first'
    $note = "no own sign-in on the master yet - first sign-in prepared (master's MAC $(if ($had) { 'removed' } else { 'was not there' }), master's account kept); the logon helper saves this PC's new key"
  }
} catch { $fail += $_.Exception.Message; $mode = 'none' }

# ---------- OSLink back on ----------
if ($svcObj -and ($wasRunning -or $startMode -eq 'Auto')) {
  try { Start-Service -Name $SvcName -ErrorAction Stop } catch { $fail += "start $SvcName : $($_.Exception.Message)" }
}
[IO.File]::WriteAllText($stateFile, (ConvertTo-Json @{ mode = $mode; at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); pc = $env:COMPUTERNAME; master = $hostPort; baseline = "$baseline" }), (New-Object Text.UTF8Encoding($false)))

# ---------- the logon helper (answers "new computer?" the first time, sends this PC's key to the master) ----------
if (-not $TestDir) {
  try {
    $vbs = Join-Path $ClientDir 'OslinkHelper.vbs'
    $ta = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')
    $tt = New-ScheduledTaskTrigger -AtLogOn
    $tp = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest   # BUILTIN\Users: whoever logs on (the shop account is an administrator)
    $ts = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 45) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName 'OSYNC-OslinkHelper' -Action $ta -Trigger $tt -Principal $tp -Settings $ts -Force | Out-Null
  } catch { $fail += "helper task: $($_.Exception.Message)" }
}

if ($fail.Count) { Write-Host "OSLink login: $note; FAILED: $($fail -join '; ')" -ForegroundColor Red; exit 1 }
Write-Host "OSLink login: $note" -ForegroundColor Green
exit 0
