# Master-Move-BlueStacks.ps1 - MASTER: move BlueStacks 5 (BlueStacks_nxt) off the system drive onto a drive the clients see,
# put it in the game menu, and give the clients what they need to start it from the game disk (20 Nov 2026, the owner).
#   <target>\Program   was C:\Program Files\BlueStacks_nxt   (InstallDir)
#   <target>\Data      was C:\ProgramData\BlueStacks_nxt     (UserDefinedDir: Engine\<instance>\Data.vhdx, Root.vhd, logs)
# Default target: <shared drive with the most free space>:\Emulator\BlueStacks (the game list scans X:\Emulator too).
# Repointed: HKLM\SOFTWARE\BlueStacks_nxt, every registry value under CLSID / TypeLib / CurrentVersion / HKCU that names the
# old folders (its COM server BstkSVC.exe, BstkC.dll, BstkProxyStub.dll, uninstall entry), the absolute paths inside its
# engine files (Engine\Manager\BstkGlobal.xml, Engine\<instance>\<instance>.bstk), the kernel driver service
# BlueStacksDrv_nxt, shortcuts, firewall rules. The old folders go to C:\_<delete-ok>\ (nothing is deleted).
# For the clients: System\Data\BlueStacks\bluestacks.reg (the registry above + its 224 COM interfaces and ProgIDs, as on
# this master) and bluestacks.txt; Client-BlueStacks.ps1 imports them at boot and starts the driver from the game disk.
# The menu card "BlueStacks 5" goes into Settings\extra-games.json (category Mobile).
#   Master-Move-BlueStacks.ps1 -DryRun          show what would happen
#   Master-Move-BlueStacks.ps1                  do it (administrator; BlueStacks is closed first)
#   -Target X:\Emulator\BlueStacks              another place     -ExportOnly   only remake System\Data\BlueStacks (+ menu card)
param([string]$Target = '', [switch]$DryRun, [switch]$ExportOnly)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:PUBLIC 'OSYNC-Move-BlueStacks.log'
if (-not $DryRun) { try { Start-Transcript -Path $log -Append | Out-Null } catch { } }
trap { Write-Host "ERROR: $_" -ForegroundColor Red; if (-not $DryRun) { try { Stop-Transcript | Out-Null } catch { } }; exit 1 }
$regPath = 'HKLM:\SOFTWARE\BlueStacks_nxt'
$r = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
if (-not $r) { Write-Host 'BlueStacks 5 (BlueStacks_nxt) is not installed on this PC - nothing to do'; exit 0 }
$oldProg = "$($r.InstallDir)".TrimEnd('\'); $oldData = "$($r.UserDefinedDir)".TrimEnd('\')
if (-not $Target) {
  $sys = $env:SystemDrive.Substring(0, 1).ToUpper()
  if ($oldProg -and $oldProg.Substring(0, 1).ToUpper() -ne $sys -and (Split-Path -Leaf $oldProg) -ieq 'Program') { $Target = Split-Path -Parent $oldProg }   # moved before
  else {
    $best = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $l = $_.DeviceID.Substring(0, 1).ToUpper(); $l -ne $sys -and (Get-SharedDrives).Contains($l) } | Sort-Object FreeSpace -Descending)[0]
    if (-not $best) { throw 'no drive the clients see (Settings SharedDrives)' }
    $Target = "$($best.DeviceID)\Emulator\BlueStacks"
  }
}
$Target = $Target.TrimEnd('\')
$newProg = Join-Path $Target 'Program'; $newData = Join-Path $Target 'Data'
$moved = ($oldProg -ieq $newProg) -and ($oldData -ieq $newData)
$outDir = Join-Path $DataDir 'BlueStacks'
Write-Host "BlueStacks $($r.Version)" -ForegroundColor Cyan
Write-Host "  program: $oldProg  ->  $newProg"
Write-Host "  data:    $oldData  ->  $newData"

# ---------- helpers ----------
function Get-Size([string]$d) { $f = @(Get-ChildItem -LiteralPath $d -Recurse -File -Force -ErrorAction SilentlyContinue); [pscustomobject]@{ Count = $f.Count; Bytes = [double](($f | Measure-Object Length -Sum).Sum) } }
# registry keys (reg.exe paths) under these roots with a value that names one of the folders
function Find-RegKeys([string[]]$needles) {
  $keys = New-Object System.Collections.Generic.List[string]
  foreach ($root in 'HKLM\SOFTWARE\BlueStacks_nxt', 'HKLM\SOFTWARE\Classes\CLSID', 'HKLM\SOFTWARE\Classes\TypeLib', 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKCU\Software\BlueStacks_nxt', 'HKCU\Software\BlueStacksInstaller', 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run') {   # targeted: a search of all HKCU\Software takes many minutes
    foreach ($n in $needles) {
      foreach ($l in @(& reg.exe query $root /s /f $n /d 2>$null)) { if ($l -match '^HKEY_' -and -not $keys.Contains($l)) { $keys.Add($l) } }
    }
  }
  $keys
}
# one registry key: every string value that names an old folder gets the new one (same value kind)
function Update-RegKey([string]$regExePath, [hashtable]$map) {
  $hive = if ($regExePath -like 'HKEY_CURRENT_USER*') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }
  $sub = $regExePath -replace '^HKEY_(LOCAL_MACHINE|CURRENT_USER)\\', ''
  $k = $hive.OpenSubKey($sub, $true); if (-not $k) { return 0 }
  $n = 0
  try {
    foreach ($name in $k.GetValueNames()) {
      $kind = $k.GetValueKind($name)
      if ($kind -ne 'String' -and $kind -ne 'ExpandString') { continue }
      $v = [string]$k.GetValue($name, '', 'DoNotExpandEnvironmentNames'); $nv = $v
      foreach ($o in $map.Keys) { $nv = [regex]::Replace($nv, [regex]::Escape($o), ($map[$o] -replace '\$', '$$$$'), 'IgnoreCase') }
      if ($nv -ne $v) { $k.SetValue($name, $nv, $kind); $n++ }
    }
  } finally { $k.Close() }
  $n
}
# the instance names (Engine\Manager\BstkGlobal.xml MachineEntry ...\<name>\<name>.bstk), first one = the menu card's
function Get-Instances([string]$data) {
  $x = Join-Path $data 'Engine\Manager\BstkGlobal.xml'
  if (-not (Test-Path -LiteralPath $x)) { return @() }
  @([regex]::Matches([IO.File]::ReadAllText($x), 'src="[^"]*\\([^\\"]+)\.bstk"') | ForEach-Object { $_.Groups[1].Value })
}
# System\Data\BlueStacks\bluestacks.reg for the clients: HKLM\SOFTWARE\BlueStacks_nxt, its COM classes (found by the program
# path), their ProgIDs and TypeLib, and every Interface whose proxy stub is BlueStacks' - exported from this (working) master
function Export-ForClients {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $prog = "$((Get-ItemProperty -Path $regPath).InstallDir)".TrimEnd('\')
  $keys = New-Object System.Collections.Generic.List[string]
  $keys.Add('HKLM\SOFTWARE\BlueStacks_nxt')
  $clsids = @()
  foreach ($l in @(& reg.exe query 'HKLM\SOFTWARE\Classes\CLSID' /s /f $prog /d 2>$null)) { if ($l -match '^HKEY_LOCAL_MACHINE\\SOFTWARE\\Classes\\CLSID\\(\{[^}]+\})') { if ($clsids -notcontains $Matches[1]) { $clsids += $Matches[1] } } }
  foreach ($c in $clsids) {
    $keys.Add("HKLM\SOFTWARE\Classes\CLSID\$c")
    $ck = Get-Item -LiteralPath "HKLM:\SOFTWARE\Classes\CLSID\$c" -ErrorAction SilentlyContinue
    foreach ($pn in 'ProgId', 'VersionIndependentProgID') { $pid0 = "$((Get-Item -LiteralPath "HKLM:\SOFTWARE\Classes\CLSID\$c\$pn" -ErrorAction SilentlyContinue).GetValue(''))"; if ($pid0 -and -not $keys.Contains("HKLM\SOFTWARE\Classes\$pid0")) { $keys.Add("HKLM\SOFTWARE\Classes\$pid0") } }
    $tl = "$((Get-Item -LiteralPath "HKLM:\SOFTWARE\Classes\CLSID\$c\TypeLib" -ErrorAction SilentlyContinue).GetValue(''))"
    if ($tl -and -not $keys.Contains("HKLM\SOFTWARE\Classes\TypeLib\$tl")) { $keys.Add("HKLM\SOFTWARE\Classes\TypeLib\$tl") }
  }
  foreach ($l in @(& reg.exe query 'HKLM\SOFTWARE\Classes\TypeLib' /s /f $prog /d 2>$null)) { if ($l -match '^HKEY_LOCAL_MACHINE\\SOFTWARE\\Classes\\TypeLib\\(\{[^}]+\})') { $t = "HKLM\SOFTWARE\Classes\TypeLib\$($Matches[1])"; if (-not $keys.Contains($t)) { $keys.Add($t) } } }
  $ps = @($clsids | Where-Object { "$((Get-Item -LiteralPath "HKLM:\SOFTWARE\Classes\CLSID\$_" -ErrorAction SilentlyContinue).GetValue(''))" -eq 'PSFactoryBuffer' })
  $nIf = 0
  foreach ($p in $ps) { foreach ($l in @(& reg.exe query 'HKLM\SOFTWARE\Classes\Interface' /s /f $p /d 2>$null)) { if ($l -match '^HKEY_LOCAL_MACHINE\\SOFTWARE\\Classes\\Interface\\(\{[^}]+\})\\ProxyStubClsid32$') { $keys.Add("HKLM\SOFTWARE\Classes\Interface\$($Matches[1])"); $nIf++ } } }
  # one .reg file (reg export writes UTF-16 with the header line; the header once, then every key)
  $tmp = Join-Path $env:TEMP "osync-bs-$PID.reg"
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('Windows Registry Editor Version 5.00')
  foreach ($k in $keys) {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    & reg.exe export $k $tmp /y 2>$null | Out-Null
    if (-not (Test-Path -LiteralPath $tmp)) { continue }
    $body = [IO.File]::ReadAllText($tmp, [Text.Encoding]::Unicode) -replace '^\uFEFF?Windows Registry Editor Version 5\.00\s*', ''
    [void]$sb.AppendLine(''); [void]$sb.Append($body.TrimEnd()); [void]$sb.AppendLine()
  }
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
  [IO.File]::WriteAllText((Join-Path $outDir 'bluestacks.reg'), $sb.ToString(), [Text.Encoding]::Unicode)
  [IO.File]::WriteAllLines((Join-Path $outDir 'bluestacks.txt'), [string[]]@($prog, "$((Get-ItemProperty -Path $regPath).Version)", (Get-Date -Format 'yyyy-MM-dd HH:mm')), (New-Object Text.UTF8Encoding $false))
  Write-Host "  for the clients: $outDir\bluestacks.reg ($($keys.Count) keys: $($clsids.Count) COM classes, $nIf interfaces)"
}
# the menu card (Settings\extra-games.json "games"), written once; text inserted so the file keeps its own layout
function Add-MenuCard([string]$prog, [string]$root, [string]$instance) {
  $f = $ExtraGamesFile; $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
  if ($t -match '"id"\s*:\s*"app-bluestacks"') { Write-Host '  menu card app-bluestacks: already in Settings\extra-games.json'; return }
  $esc = { param($s) $s.Replace('\', '\\') }
  $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
  $args0 = if ($instance) { "--instance $instance" } else { '' }
  $entry = (@('    {', '      "id": "app-bluestacks",', '      "title": "BlueStacks 5",', '      "cat": "Mobile",', '      "platform": "Android",', ('      "exe": "' + (& $esc (Join-Path $prog 'HD-Player.exe')) + '",'), ('      "args": "' + $args0 + '",'), ('      "root": "' + (& $esc $root) + '",'), ('      "icon": "' + (& $esc (Join-Path $prog 'HD-Player.exe')) + '"'), '    },') -join $nl) + $nl
  $m = [regex]::Match($t, '"games"\s*:\s*\[\s*\r?\n')
  if (-not $m.Success) { Write-Host '  menu card: "games" list not found in extra-games.json - add it by hand' -ForegroundColor Yellow; return }
  $t2 = $t.Insert($m.Index + $m.Length, $entry)
  [void]($t2 | ConvertFrom-Json)
  [IO.File]::WriteAllText($f, $t2, (New-Object Text.UTF8Encoding $false))
  Write-Host "  menu card: BlueStacks 5 (Mobile) -> $prog\HD-Player.exe $args0"
}

if ($ExportOnly -or $moved) {
  if (-not $moved) { Write-Host '  -ExportOnly: BlueStacks is not moved yet (the clients cannot use the system drive) - run this without -ExportOnly' -ForegroundColor Yellow; exit 1 }
  Write-Host '  already on the game drive' -ForegroundColor Green
  if ($DryRun) { Write-Host '  (DryRun) would remake System\Data\BlueStacks and check the menu card' -ForegroundColor DarkGray; exit 0 }
  if (-not (Test-Admin)) { throw 'Run as administrator (OSYNC.bat asks for it).' }
  Export-ForClients
  $inst = @(Get-Instances $newData); Add-MenuCard $newProg $Target $(if ($inst) { $inst[0] } else { '' })
  exit 0
}

# ---------- the plan ----------
foreach ($d in $oldProg, $oldData) { if (-not (Test-Path -LiteralPath $d)) { throw "not found: $d" } }
foreach ($d in $newProg, $newData) { if ((Test-Path -LiteralPath $d) -and @(Get-ChildItem -LiteralPath $d -Force | Select-Object -First 1).Count) { throw "$d is not empty - choose another -Target" } }
$sp = Get-Size $oldProg; $sd = Get-Size $oldData
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($Target.Substring(0, 2))'"
if (-not $drive) { throw "no drive $($Target.Substring(0, 2))" }
if (-not (Get-SharedDrives).Contains($Target.Substring(0, 1).ToUpper())) { Write-Host "  WARNING $($Target.Substring(0, 2)) is not in SharedDrives - the clients will not see it" -ForegroundColor Yellow }
Write-Host ("  size: program {0:N0} MB ({1} files) + data {2:N0} MB ({3} files) | free on {4} {5:N0} GB" -f ($sp.Bytes / 1MB), $sp.Count, ($sd.Bytes / 1MB), $sd.Count, $drive.DeviceID, ($drive.FreeSpace / 1GB))
if ($drive.FreeSpace -lt ($sp.Bytes + $sd.Bytes) * 1.2 + 2GB) { throw "not enough free space on $($drive.DeviceID)" }
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { (($_.Path -and $_.Path.StartsWith($oldProg + '\', [StringComparison]::OrdinalIgnoreCase)) -or ($_.Name -match '^(HD-|Bstk)')) })   # not BlueStacksServices / BlueStacks X (other programs of the maker)
Write-Host "  running now: $(if ($procs) { ($procs | ForEach-Object Name | Sort-Object -Unique) -join ', ' } else { 'nothing' }) (closed first)"
$drv = Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'" -ErrorAction SilentlyContinue
Write-Host "  driver BlueStacksDrv_nxt: $(if ($drv) { "$($drv.State) $($drv.StartMode) $($drv.PathName)" } else { 'not installed' })"
$map = [ordered]@{ $oldProg = $newProg; $oldData = $newData }
$regKeys = @(Find-RegKeys @($oldProg, $oldData))
Write-Host "  registry keys that name the old folders: $($regKeys.Count)"
$regKeys | Select-Object -First 12 | ForEach-Object { Write-Host "    $_" }
Write-Host "  then: engine files repointed, driver from $newProg, shortcuts, firewall rules, old folders -> C:\_<delete-ok>, files for the clients, menu card"
if ($DryRun) { Write-Host '  (DryRun) nothing changed' -ForegroundColor DarkGray; exit 0 }
if (-not (Test-Admin)) { throw 'Run as administrator (OSYNC.bat asks for it).' }

# ---------- do it ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($p in $procs) { try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Host "  closed $($p.Name)" } catch { } }
Start-Sleep -Seconds 3
if ($drv -and $drv.State -eq 'Running') { & sc.exe stop BlueStacksDrv_nxt 2>&1 | Out-Null; Start-Sleep -Seconds 2; Write-Host "  driver stopped: $((Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'").State)" }
foreach ($pair in @(@($oldProg, $newProg), @($oldData, $newData))) {
  New-Item -ItemType Directory -Force -Path $pair[1] | Out-Null
  & robocopy.exe $pair[0] $pair[1] /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE): $($pair[0]) - nothing else changed, the old folders are still in use" }
  $a = Get-Size $pair[0]; $b = Get-Size $pair[1]
  if ($a.Count -ne $b.Count -or $a.Bytes -ne $b.Bytes) { throw "copy differs: $($pair[0]) $($a.Count) files / $($a.Bytes) bytes vs $($b.Count) / $($b.Bytes) - nothing else changed" }
  Write-Host "  copied $($pair[0]) -> $($pair[1]) ($($b.Count) files, checked)"
}
# engine / config text files with absolute paths
$nt = 0
foreach ($f in @(Get-ChildItem -LiteralPath $newData, $newProg -Recurse -File -Force -Include *.xml, *.bstk, *.conf, *.json, *.cfg, *.ini -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 20MB })) {
  $sr = New-Object IO.StreamReader($f.FullName, $true); $text = $sr.ReadToEnd(); $encd = $sr.CurrentEncoding; $sr.Close()
  $new = $text
  foreach ($o in $map.Keys) { foreach ($v in @(@($o, $map[$o]), @($o.Replace('\', '/'), $map[$o].Replace('\', '/')), @($o.Replace('\', '\\'), $map[$o].Replace('\', '\\')))) { $new = [regex]::Replace($new, [regex]::Escape($v[0]), ($v[1] -replace '\$', '$$$$'), 'IgnoreCase') } }
  if ($new -ne $text) { $hb = [IO.File]::ReadAllBytes($f.FullName); $bom = $hb.Length -ge 3 -and $hb[0] -eq 0xEF -and $hb[1] -eq 0xBB -and $hb[2] -eq 0xBF; $we = if ($encd -is [Text.UTF8Encoding]) { New-Object Text.UTF8Encoding $bom } else { $encd }; [IO.File]::WriteAllText($f.FullName, $new, $we); $nt++; Write-Host "  repointed $($f.FullName.Substring($Target.Length + 1))" }
}
Write-Host "  engine / config files repointed: $nt"
# registry (BlueStacks' own key first, then everything that named the old folders)
$nv = 0; foreach ($k in $regKeys) { $nv += Update-RegKey $k $map }
Set-ItemProperty -Path $regPath -Name 'InstallDir' -Value ($newProg + '\'); Set-ItemProperty -Path $regPath -Name 'UserDefinedDir' -Value $newData
Set-ItemProperty -Path $regPath -Name 'DataDir' -Value ((Join-Path $newData 'Engine') + '\'); Set-ItemProperty -Path $regPath -Name 'LogDir' -Value ((Join-Path $newData 'Logs') + '\')
$left = @(Find-RegKeys @($oldProg, $oldData))
Write-Host "  registry values repointed: $nv | still naming the old folders: $($left.Count)$(if ($left) { ' (' + ($left -join '; ') + ')' })"
# kernel driver from the new place
if ($drv) {
  & sc.exe config BlueStacksDrv_nxt binPath= "\??\$newProg\BstkDrv_nxt.sys" 2>&1 | Out-Null
  & sc.exe start BlueStacksDrv_nxt 2>&1 | Out-Null; Start-Sleep -Seconds 2
  $d2 = Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'"
  Write-Host "  driver BlueStacksDrv_nxt: $($d2.State) $($d2.PathName)"
}
# shortcuts and firewall rules
$sh = New-Object -ComObject WScript.Shell; $ns = 0
foreach ($l in @(Get-ChildItem 'C:\Users\Public\Desktop', 'C:\Users\*\Desktop', 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu' -Recurse -Filter *.lnk -Force -ErrorAction SilentlyContinue)) {
  $s = $sh.CreateShortcut($l.FullName)
  if ("$($s.TargetPath)" -notlike "$oldProg\*") { continue }
  $s.TargetPath = $newProg + $s.TargetPath.Substring($oldProg.Length)
  if ("$($s.WorkingDirectory)" -like "$oldProg*") { $s.WorkingDirectory = $newProg + $s.WorkingDirectory.Substring($oldProg.Length) }
  if ("$($s.IconLocation)" -like "$oldProg*") { $s.IconLocation = $newProg + $s.IconLocation.Substring($oldProg.Length) }
  $s.Save(); $ns++
}
$nf = 0
foreach ($af in @(Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue | Where-Object { "$($_.Program)" -like "$oldProg\*" })) { try { Set-NetFirewallApplicationFilter -InputObject $af -Program ($newProg + $af.Program.Substring($oldProg.Length)) -ErrorAction Stop; $nf++ } catch { } }
Write-Host "  shortcuts repointed: $ns | firewall rules: $nf"
# old folders aside (same drive = a rename): C:\_<delete-ok>\BlueStacks_nxt-<Program|Data>-<time>
$trash = Join-Path ($oldProg.Substring(0, 3)) ('_' + [string]::new([char[]](0x0E25, 0x0E1A, 0x0E44, 0x0E14, 0x0E49)))
New-Item -ItemType Directory -Force -Path $trash | Out-Null
foreach ($pair in @(@($oldProg, "BlueStacks_nxt-Program-$stamp"), @($oldData, "BlueStacks_nxt-Data-$stamp"))) {
  try { Move-Item -LiteralPath $pair[0] -Destination (Join-Path $trash $pair[1]) -ErrorAction Stop; Write-Host "  old $($pair[0]) -> $trash\$($pair[1])" }
  catch { Write-Host "  old $($pair[0]) could not be moved ($($_.Exception.Message)) - left where it is" -ForegroundColor Yellow }
}
Export-ForClients
$inst = @(Get-Instances $newData); Add-MenuCard $newProg $Target $(if ($inst) { $inst[0] } else { '' })
Write-Host "`nDone. Start BlueStacks 5 on this PC once (desktop icon) to check it, then OSYNC.bat > 1 (game list) and reboot the clients." -ForegroundColor Green
Write-Host "The old folders are in $trash - delete them after the check to free the system drive."
try { Stop-Transcript | Out-Null } catch { }
