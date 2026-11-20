# Client-OslinkReset.ps1 - CLIENT PC: OSLink signs in with the shop's support account as THIS PC (Client-Install step 1j).
# What OSLink keeps, and why every client looked like one device:
#   - the account (accounts\<uid>\userinfo.config with autoLogin + loginKey, lastuser.data) - next to the program on the
#     game disk (<drive>:\LDPlayer\OSLink\userData), so clients get the master's sign-in. It is the shop's support account
#     and STAYS (the user: it is meant to be signed in).
#   - the network MAC (accounts\settings.config "cacheIpAdress") - also on the game disk = the master's MAC on every client
#     (the master's OSLink writes it back by itself)
#   - the device id the OSLink server gave out (registry rcmac in HKLM\SOFTWARE\ld\OSLink and HKCU\Software\ld\OSLink) -
#     comes with the client image = the same on every client
# Test 2026-11-16 on AT9COM22 with only the MAC removed: OSLink asked "new computer?", then "sign in again". So now both
# the MAC and the device id go, and OSLink registers this PC as a device of its own with the support account. On a client:
#   1 stop service LDRemoteSvc (it starts ldremote.exe --fromserver) and ldremote / ldremoteevent - a running OSLink
#     writes its settings back when it closes
#   2 settings.config: remove only "cacheIpAdress"; every other value stays, written without a BOM like the agent does
#     (a BOM / lost values make OSLink pop its "Update" / "New feature" windows)
#   3 registry: remove the value rcmac (machine + every user; a user not logged on: NTUSER.DAT loaded for a moment)
#   4 start LDRemoteSvc again (when it was running or is set to start automatically)
# The client writes into its own copy of the game disk / C: (diskless, gone at reboot): nothing on the master changes.
# Not touched: the account files, userData\data\setting.ini, the program.
# Never on the master. -CheckOnly: show only. -TestDir <folder>: <folder> = the OSLink folder (with userData\), registry =
# HKCU\Software\OSYNC-OslinkTest\m (machine) and \u (user), no service or program touched (tests on the master).
param([switch]$CheckOnly, [string]$TestDir)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir -and -not $CheckOnly) { Write-Host 'OSLink: this is the master - nothing changed'; exit 0 }
if (-not $TestDir -and -not $CheckOnly -and -not (Test-Admin)) { Write-Host 'OSLink: run as administrator.' -ForegroundColor Red; exit 1 }

$SvcName = 'LDRemoteSvc'
# the OSLink folder: from the service's program path, else <shared drive>:\LDPlayer\OSLink
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
if (-not $olRoot) { Write-Host 'OSLink: not found (no LDRemoteSvc / LDPlayer\OSLink\userData) - skipped'; exit 0 }
$settings = Join-Path $olRoot 'userData\accounts\settings.config'

# ---------- the MAC in settings.config ----------
$map = $null; $hasMac = $false; $hasBom = $false; $raw = ''
if (Test-Path -LiteralPath $settings) {
  $bytes = [IO.File]::ReadAllBytes($settings)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $raw = ([Text.Encoding]::UTF8.GetString($bytes)).Trim([char]0xFEFF).Trim()
  if ($raw) {
    try {
      $map = [ordered]@{}
      foreach ($p in ($raw | ConvertFrom-Json).PSObject.Properties) { if ($p.Name -ieq 'cacheIpAdress') { $hasMac = $true } else { $map[$p.Name] = $p.Value } }
    } catch { Write-Host "  settings.config not readable - left as it is ($($_.Exception.Message))"; $map = $null; $hasMac = $false; $hasBom = $false }
  } else { $hasBom = $false }
}

# ---------- the device id (rcmac) in the registry ----------
function Get-Profiles {
  $list = New-Object System.Collections.Generic.List[object]
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
  foreach ($k in @(Get-ChildItem -LiteralPath $pl -ErrorAction SilentlyContinue)) {
    $sid = $k.PSChildName
    if ($sid -notmatch '^S-1-5-21-[\d-]+$') { continue }
    $p = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath)")
    if ($p -and (Test-Path -LiteralPath $p)) { $list.Add([pscustomobject]@{ Name = (Split-Path -Leaf $p); Path = $p; Sid = $sid }) }
  }
  $list
}
# every place a rcmac can be: @(@(<RegistryKey root>, <sub key>, <who>)); users not logged on: hive loaded for the call
$script:mounted = New-Object System.Collections.Generic.List[string]
function Get-RcmacPlaces([bool]$loadHives) {
  $pl = New-Object System.Collections.Generic.List[object]
  if ($TestDir) {
    $pl.Add(@([Microsoft.Win32.Registry]::CurrentUser, 'Software\OSYNC-OslinkTest\m\SOFTWARE\ld\OSLink', 'machine'))
    $pl.Add(@([Microsoft.Win32.Registry]::CurrentUser, 'Software\OSYNC-OslinkTest\u\Software\ld\OSLink', 'test'))
    return , $pl
  }
  $pl.Add(@([Microsoft.Win32.Registry]::LocalMachine, 'SOFTWARE\ld\OSLink', 'machine'))
  $pl.Add(@([Microsoft.Win32.Registry]::LocalMachine, 'SOFTWARE\WOW6432Node\ld\OSLink', 'machine'))
  $n = 0
  foreach ($p in Get-Profiles) {
    if (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)") { $pl.Add(@([Microsoft.Win32.Registry]::Users, "$($p.Sid)\Software\ld\OSLink", $p.Name)); continue }
    if (-not $loadHives) { continue }
    $dat = Join-Path $p.Path 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $dat)) { continue }
    $mount = "OSYNC_OL_$n"; $n++
    & reg.exe load "HKU\$mount" "$dat" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $script:mounted.Add($mount); $pl.Add(@([Microsoft.Win32.Registry]::Users, "$mount\Software\ld\OSLink", $p.Name)) }
  }
  , $pl
}
function Close-Hives { if ($script:mounted.Count) { [GC]::Collect(); [GC]::WaitForPendingFinalizers(); foreach ($m in $script:mounted) { & reg.exe unload "HKU\$m" 2>$null | Out-Null }; $script:mounted.Clear() } }
# who has a rcmac (and delete it when $delete)
function Use-Rcmac([bool]$delete) {
  $who = @(); $fail = @()
  try {
    foreach ($pl in (Get-RcmacPlaces (-not $CheckOnly))) {
      $k = $pl[0].OpenSubKey($pl[1], $delete)
      if (-not $k) { continue }
      try {
        if ($null -eq $k.GetValue('rcmac')) { continue }
        if ($delete) { try { $k.DeleteValue('rcmac', $false); $who += $pl[2] } catch { $fail += "$($pl[2]) ($($_.Exception.Message))" } } else { $who += $pl[2] }
      } finally { $k.Close() }
    }
  } finally { Close-Hives }
  @{ Who = @($who | Select-Object -Unique); Fail = $fail }
}

$rc = Use-Rcmac $false
$todo = @()
if ($hasMac) { $todo += 'the saved MAC (cacheIpAdress)' }
if ($hasBom -and $map) { $todo += 'the settings BOM' }
if ($rc.Who.Count) { $todo += "the device id (rcmac: $($rc.Who -join ', '))" }
if (-not $todo.Count) { Write-Host "OSLink: no saved MAC or device id - OSLink registers this PC itself ($olRoot)"; exit 0 }
if ($CheckOnly) { Write-Host "OSLink: would remove $($todo -join ', ') ($olRoot)"; exit 0 }

# 1 stop OSLink (service + programs) so it does not write the old values back when it closes
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
  # read again: a closing OSLink may have just written its settings
  if (Test-Path -LiteralPath $settings) {
    try {
      $raw2 = ([IO.File]::ReadAllText($settings)).Trim([char]0xFEFF).Trim()
      if ($raw2 -and $raw2 -ne $raw) { $map = [ordered]@{}; $hasMac = $false; foreach ($p in ($raw2 | ConvertFrom-Json).PSObject.Properties) { if ($p.Name -ieq 'cacheIpAdress') { $hasMac = $true } else { $map[$p.Name] = $p.Value } } }
    } catch { }
  }
}

# 2 settings.config without cacheIpAdress, no BOM
$done = @(); $fail = @()
if ($map -and ($hasMac -or $hasBom)) {
  try { [IO.File]::WriteAllText($settings, (ConvertTo-Json -InputObject $map -Depth 5), (New-Object Text.UTF8Encoding($false))); $done += $(if ($hasMac) { 'the saved MAC (cacheIpAdress)' } else { 'the settings BOM' }) }
  catch { $fail += "settings.config ($($_.Exception.Message))" }
}
# 3 rcmac (again after the stop: a closing OSLink may have written it)
$rc = Use-Rcmac $true
if ($rc.Who.Count) { $done += "the device id (rcmac: $($rc.Who -join ', '))" }
$fail += $rc.Fail

# 4 OSLink back on (support account; registers this PC with its own MAC)
$svcNote = ''
if ($svcObj -and ($wasRunning -or $startMode -eq 'Auto')) {
  try { Start-Service -Name $SvcName -ErrorAction Stop; $svcNote = " - $SvcName started" } catch { $svcNote = " - $SvcName did NOT start ($($_.Exception.Message))" }
}
if ($fail.Count) { Write-Host "OSLink: removed $(if ($done.Count) { $done -join ', ' } else { 'nothing' }); FAILED: $($fail -join '; ')$svcNote" -ForegroundColor Red; exit 1 }
Write-Host "OSLink: removed $($done -join ', ') - this PC registers as itself, the support account stays signed in$svcNote" -ForegroundColor Green
exit 0
