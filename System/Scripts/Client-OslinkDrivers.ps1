# Client-OslinkDrivers.ps1 - CLIENT PC: OSLink's input drivers, installed silently ONLY when missing (Client-Install step 1l).
# OSLink (LDPlayer remote play, <drive>:\LDPlayer\OSLink\bin) moves the mouse, types and plays a gamepad for the remote player
# through 3 drivers of its own. Its installer puts them in with gamekey_driver.bat (devcon updateex):
#   LdVMou    "Virtual Mouse"           hardware id LdVMouse        LdVMou.inf    + ldvcnmou.cat   (\\.\LdVMouse)
#   LdVKbd    "Virtual Keyboard"        hardware id LdVKeyboard     LdVKbd.inf    + ldvkbd.cat     (\\.\LdVKeyboard)
#   LdScpVBus "Scp Virtual Bus Driver"  hardware id Root\LdScpVBus  LdScpVBus.inf + ldscpvbus.cat  (virtual Xbox gamepads)
# OSLink checks them when it starts (LDDriverHelper::CheckError). One missing = "driver error detected - click to repair";
# its Repair (LDDriverHelper::Repair) runs gamekey_driver.bat again. OSLink was installed on the master only, so a client
# image does not have them, and what Repair installs on a diskless client is gone at the next reboot.
# Here: each driver that is not loaded is installed from the OSLink folder the same way Repair does it, hidden:
#   no device yet               -> devcon install <inf> <hwid>   (creates the device, installs the driver)
#   device there, not working   -> devcon update <inf> <hwid>    (installs the driver on it again; pnputil if no devcon)
# devcon.exe is the one in the OSLink folder (gamekey_driver.bat uses it). At boot as SYSTEM, or in image mode as the admin:
# an image saved after this = a check of a few milliseconds at every boot ("loaded" = Windows runs the driver for a device:
# HKLM\SYSTEM\CurrentControlSet\Services\<driver>\Enum Count, which Windows writes when it loads the driver).
# Safety: the drivers are signed by Microsoft (Windows Hardware Compatibility Publisher): Windows trusts them, so nothing is
# added to any certificate store and nothing asks. A file is used only when its signature is valid AND made with one of the
# pinned certificates below (devcon.exe: its maker's). An OSLink update with other certificates = nothing installed and a
# line naming the file and certificate (check it, then add the thumbprint here).
# OSLink running when a driver went in: restarted (service LDRemoteSvc + ldremote, like 1j / 1k) so it checks again.
# Never on the master. -CheckOnly: report only (also on the master). -TestDir <folder>: <folder> = a copy of OSLink's bin;
# <folder>\state.json {"LdVMou":"loaded|error|missing", ...} = the drivers' state (missing ones = "missing"); nothing is
# run or changed (prints what it would run).
param([switch]$CheckOnly, [string]$TestDir)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir -and -not $CheckOnly) { Write-Host 'OSLink drivers: this is the master - nothing changed'; exit 0 }
if (-not $TestDir -and -not $CheckOnly -and -not (Test-Admin)) { Write-Host 'OSLink drivers: run as administrator.' -ForegroundColor Red; exit 1 }
$DryRun = $CheckOnly -or [bool]$TestDir

# certificates a file may be signed with (thumbprints, read 2026-11-17 from OSLink 1.3.29.5 on the master)
$PinnedDriverCerts = @(
  'FAC666005546D6BE881A31C1267717879401A950'   # Microsoft Windows Hardware Compatibility Publisher: ldvcnmou.cat, ldvkbd.cat, LdVMou.sys, LdVKbd.sys
  'C1DA308696092A9310FAEFD50EF708453CA36DF7'   # Microsoft Windows Hardware Compatibility Publisher: ldscpvbus.cat, LdScpVBus.sys, WdfCoinstaller01009.dll
  # 17 Nov, seen on KORI12 / KORI04: a client without the gamepad catalog installed reads WdfCoinstaller01009.dll's OWN signature
  # (the master's said "Hardware Compatibility" only because its catalog is installed there) - Microsoft's WDF co-installer
  '0FECD6DB0C4D9B14FAC2DB9A038D6BC437BF17A0'   # Microsoft Windows Component Publisher: WdfCoinstaller01009.dll (embedded signature)
)
$PinnedToolCerts = @(
  'C9CF5A70494E07F75A894435C96CB25F0A1E0C7B'   # Shanghai Chang Zhi Network Technology Co., Ltd.: devcon.exe in OSLink's bin (x64)
)
# 19 Nov 2026: on 11 of 20 clients devcon.exe read "signature UnknownError" at boot - its root (DigiCert Trusted Root G4) is not
# in that PC's root store yet (Windows fetches it on demand), so nothing was installed. A file whose exact content is pinned
# here AND whose signer is pinned is accepted then too (SHA256 of OSLink 1.3.29.5's devcon.exe, read on the master).
$PinnedFileHashes = @(
  'A0E6271C610F096959D047D985DC69BC8819BBF26FB4CBD12CD776A24E625FA6'   # E:\LDPlayer\OSLink\bin\devcon.exe (103752 bytes, 3 Oct 2026)
)
$Drivers = @(
  [pscustomobject]@{ Svc = 'LdVMou';    Name = 'virtual mouse';       HwId = 'LdVMouse';       Inf = 'LdVMou.inf';    Extra = @() }
  [pscustomobject]@{ Svc = 'LdVKbd';    Name = 'virtual keyboard';    HwId = 'LdVKeyboard';    Inf = 'LdVKbd.inf';    Extra = @() }
  [pscustomobject]@{ Svc = 'LdScpVBus'; Name = 'virtual gamepad bus'; HwId = 'Root\LdScpVBus'; Inf = 'LdScpVBus.inf'; Extra = @('WdfCoinstaller01009.dll') }
)

# -TestDir: the drivers' state from <folder>\state.json instead of this PC
$fake = $null
if ($TestDir) {
  $sf = Join-Path $TestDir 'state.json'
  $fake = if (Test-Path -LiteralPath $sf) { Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json } else { New-Object psobject }
}
function Get-FakeState($d) { $s = "$($fake.($d.Svc))"; if ($s) { $s } else { 'missing' } }

# loaded = Windows runs the driver for at least one device (volatile Services\<driver>\Enum, written when it loads it)
function Test-Loaded($d) {
  if ($fake) { return (Get-FakeState $d) -eq 'loaded' }
  $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Services\$($d.Svc)\Enum")
  if (-not $k) { return $false }
  try { [int]$k.GetValue('Count', 0) -ge 1 } finally { $k.Close() }
}

# ---------- fast path: all three loaded (an image saved with them) ----------
$missing = @($Drivers | Where-Object { -not (Test-Loaded $_) })
if (-not $missing.Count) { Write-Host 'OSLink drivers: virtual mouse, keyboard and gamepad bus are loaded - nothing to do' -ForegroundColor Green; exit 0 }

# ---------- OSLink's bin folder ----------
function Find-OslinkBin {
  # the folder of the OSLink service's program, else what OSLink's installer wrote, else <shared drive>:\LDPlayer\OSLink\bin
  $c = New-Object System.Collections.Generic.List[string]
  $ip = "$((Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\LDRemoteSvc' -ErrorAction SilentlyContinue).ImagePath)"
  $m = [regex]::Match($ip, '^\s*"?([^"]+?\.exe)')
  if ($m.Success) { $c.Add((Split-Path -Parent $m.Groups[1].Value)) }
  foreach ($k in 'HKLM:\SOFTWARE\XuanZhi\OSLink', 'HKLM:\SOFTWARE\WOW6432Node\XuanZhi\OSLink') {
    $v = "$((Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue).InstallDir)"
    if ($v) { $c.Add($v.TrimEnd('\')) }
  }
  foreach ($d in (Get-SharedDrives).ToCharArray()) { $c.Add("${d}:\LDPlayer\OSLink\bin") }
  $c | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'LdVMou.inf')) } | Select-Object -First 1
}
$bin = if ($TestDir) { $TestDir } else { Find-OslinkBin }
if (-not $bin) { Write-Host "OSLink drivers: OSLink not found (no LDRemoteSvc / LDPlayer\OSLink\bin with LdVMou.inf) - skipped ($(@($missing | ForEach-Object Name) -join ', ') not loaded)"; exit 0 }

# '' = valid signature made with a pinned certificate; else why not
function Test-PinnedSignature([string]$File, [string[]]$Pins) {
  if (-not (Test-Path -LiteralPath $File)) { return "$(Split-Path -Leaf $File) is missing" }
  $s = Get-AuthenticodeSignature -LiteralPath $File
  if ($s.Status -eq 'UnknownError' -and $s.SignerCertificate -and $Pins -contains $s.SignerCertificate.Thumbprint -and
      $PinnedFileHashes -contains (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash) {
    Write-Host "  $(Split-Path -Leaf $File): signature $($s.Status) (root not on this PC yet) - accepted: pinned signer and pinned file content"
    return ''
  }
  if ($s.Status -ne 'Valid') { return "$(Split-Path -Leaf $File): signature $($s.Status)" }
  if ($Pins -notcontains $s.SignerCertificate.Thumbprint) { return "$(Split-Path -Leaf $File): signed by a certificate that is not pinned ($($s.SignerCertificate.Subject -replace ',.*$', '') $($s.SignerCertificate.Thumbprint))" }
  ''
}

# ---------- what is wrong with each missing driver ----------
$pnp = @()
if (-not $fake) { try { $pnp = @(Get-PnpDevice -ErrorAction Stop) } catch { Write-Host "  (device list not available: $($_.Exception.Message))" } }
$repo = Join-Path $env:SystemRoot 'System32\DriverStore\FileRepository'
foreach ($d in $missing) {
  # (the device list is kept in a variable: PowerShell 5.1 unrolls a one-item list in $( ) and has no .Count on one object)
  if ($fake) {
    $st = Get-FakeState $d
    $devs = @(); if ($st -eq 'error') { $devs = @([pscustomobject]@{ InstanceId = "ROOT\TEST\$($d.Svc)"; Status = 'Error'; Problem = 'CM_PROB_FAILED_INSTALL'; Present = $true }) }
    $inStore = $st -eq 'error'
  } else {
    $devs = @($pnp | Where-Object { $_.Present -and (@($_.HardwareID) -contains $d.HwId) })
    $inStore = [bool](Get-ChildItem -LiteralPath $repo -Directory -Filter "$($d.Inf.ToLower())_*" -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $d.Inf) } | Select-Object -First 1)
  }
  $d | Add-Member -NotePropertyName Devices -NotePropertyValue $devs
  $d | Add-Member -NotePropertyName InStore -NotePropertyValue $inStore
  $dev = if (@($d.Devices).Count) { ($d.Devices | ForEach-Object { "$($_.InstanceId) $($_.Status) $(if ("$($_.Problem)" -and "$($_.Problem)" -ne 'CM_PROB_NONE') { $_.Problem })".Trim() }) -join ' + ' } else { 'no device' }
  Write-Host "  $($d.Name) ($($d.Svc)) not loaded: $dev; driver package $(if ($d.InStore) { 'in' } else { 'NOT in' }) the driver store"
}

# ---------- files: the drivers and devcon, signed with the pinned certificates only ----------
$devcon = Join-Path $bin 'devcon.exe'
$devconWhy = Test-PinnedSignature $devcon $PinnedToolCerts
if ($devconWhy) { Write-Host "  devcon not used: $devconWhy" }
$plan = New-Object System.Collections.Generic.List[object]
$fail = New-Object System.Collections.Generic.List[string]
foreach ($d in $missing) {
  $inf = Join-Path $bin $d.Inf
  if (-not (Test-Path -LiteralPath $inf)) { $fail.Add("$($d.Name): $($d.Inf) is missing in $bin"); continue }
  $catName = [regex]::Match([IO.File]::ReadAllText($inf), '(?im)^\s*CatalogFile\s*=\s*([^\s;]+)').Groups[1].Value
  if (-not $catName) { $fail.Add("$($d.Name): $($d.Inf) names no catalog (unsigned package)"); continue }
  $why = @(@($catName, "$($d.Svc).sys") + $d.Extra | ForEach-Object { Test-PinnedSignature (Join-Path $bin $_) $PinnedDriverCerts } | Where-Object { $_ })
  if ($why.Count) { $fail.Add("$($d.Name) NOT installed: $($why -join '; ')"); continue }
  if (@($d.Devices).Count) {
    if (-not $devconWhy) { $plan.Add([pscustomobject]@{ D = $d; Exe = $devcon; Args = "update `"$inf`" `"$($d.HwId)`"" }) }
    else { $plan.Add([pscustomobject]@{ D = $d; Exe = (Join-Path $env:SystemRoot 'System32\pnputil.exe'); Args = "/add-driver `"$inf`" /install" }) }
  } elseif (-not $devconWhy) {
    $plan.Add([pscustomobject]@{ D = $d; Exe = $devcon; Args = "install `"$inf`" `"$($d.HwId)`"" })
  } else {
    $fail.Add("$($d.Name): no device yet, and making one needs OSLink's devcon.exe ($devconWhy)")
  }
}

if ($DryRun) {
  foreach ($p in $plan) { Write-Host "  would run: `"$($p.Exe)`" $($p.Args)" }
  $msg = "OSLink drivers: $(@($missing | ForEach-Object Name) -join ', ') not loaded - would install $(if ($plan.Count) { @($plan | ForEach-Object { $_.D.Name }) -join ', ' } else { 'nothing' }) from $bin"
  if ($fail.Count) { Write-Host "$msg; CANNOT: $($fail -join '; ')" -ForegroundColor Red; exit 1 }
  Write-Host $msg; exit 0
}

# ---------- install (hidden, at most 90 s each) ----------
function Invoke-Tool([string]$Exe, [string]$Arguments, [int]$Seconds = 90) {
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe; $psi.Arguments = $Arguments; $psi.WorkingDirectory = $bin
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $p = [Diagnostics.Process]::Start($psi)
  $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
  if (-not $p.WaitForExit($Seconds * 1000)) {
    & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /T /F /PID $p.Id 2>$null | Out-Null
    return [pscustomobject]@{ Code = $null; Out = "still running after $Seconds s - stopped" }
  }
  $p.WaitForExit()
  $text = (("$($o.Result)`n$($e.Result)") -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' | '
  [pscustomobject]@{ Code = $p.ExitCode; Out = $text }
}
$done = New-Object System.Collections.Generic.List[string]
foreach ($p in $plan) {
  Show-Live "  installing OSLink $($p.D.Name) ..."
  $r = Invoke-Tool $p.Exe $p.Args
  Show-Live ''
  Write-Host "  $(Split-Path -Leaf $p.Exe) $($p.Args -replace [regex]::Escape("$bin\"), '') -> exit $(if ($null -eq $r.Code) { '-' } else { $r.Code }): $($r.Out)"
  # Windows loads the driver a moment after the install: wait up to 15 s
  for ($i = 0; $i -lt 30 -and -not (Test-Loaded $p.D); $i++) { Start-Sleep -Milliseconds 500 }
  if (Test-Loaded $p.D) { $done.Add($p.D.Name) }
  else {
    $now = @(try { Get-PnpDevice -ErrorAction Stop | Where-Object { $_.Present -and (@($_.HardwareID) -contains $p.D.HwId) } } catch { })
    $fail.Add("$($p.D.Name) still not loaded ($(if ($now.Count) { ($now | ForEach-Object { "$($_.InstanceId) $($_.Status) $($_.Problem)" }) -join ' + ' } else { 'no device' })$(if ($r.Code -eq 1) { '; devcon says a restart is needed' }))")
  }
}

# ---------- OSLink checks its drivers when it starts: restart it when it is already running ----------
$note = ''
if ($done.Count -and @(Get-Process ldremote -ErrorAction SilentlyContinue).Count) {
  $svc = Get-Service -Name 'LDRemoteSvc' -ErrorAction SilentlyContinue
  $mode = if ($svc) { "$((Get-CimInstance Win32_Service -Filter "Name='LDRemoteSvc'" -ErrorAction SilentlyContinue).StartMode)" } else { '' }
  if ($svc -and ($svc.Status -eq 'Running' -or $mode -eq 'Auto')) {
    if ($svc.Status -eq 'Running') {
      try { Stop-Service -Name 'LDRemoteSvc' -Force -ErrorAction Stop } catch { Write-Host "  stop LDRemoteSvc: $($_.Exception.Message)" }
      for ($i = 0; $i -lt 30 -and (Get-Service -Name 'LDRemoteSvc' -ErrorAction SilentlyContinue).Status -ne 'Stopped'; $i++) { Start-Sleep -Milliseconds 500 }
    }
    Get-Process ldremote, ldremoteevent -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    try { Start-Service -Name 'LDRemoteSvc' -ErrorAction Stop; $note = ' - OSLink restarted (LDRemoteSvc starts it again) so it finds them' }
    catch { $note = " - LDRemoteSvc did NOT start ($($_.Exception.Message))"; $fail.Add('LDRemoteSvc did not start') }
  } else { $note = ' - OSLink is open without its service: close and open it once to clear its driver warning' }
}

$msg = "OSLink drivers: installed $(if ($done.Count) { $done -join ', ' } else { 'nothing' }) from $bin$note"
if ($fail.Count) { Write-Host "$msg; FAILED: $($fail -join '; ')" -ForegroundColor Red; exit 1 }
Write-Host $msg -ForegroundColor Green
exit 0
