# Client-EA-AntiCheat.ps1 - install EA AntiCheat (Javelin) on a CLIENT PC for every EA game on the shared disks.
# Apex / Battlefield start through EAAntiCheat.GameServiceLauncher.exe, which needs the EAAntiCheatService
# (C:\Program Files\EA\AC) on the PC itself. The EA app installs it only on the PC that installed the game
# (the master), so on clients the splash shows "Checking for updates..." and closes.
# Run as administrator in super-workstation (image edit) mode, then save the image (Client-EA.ps1 runs it).
#   Client-EA-AntiCheat.ps1           install
#   Client-EA-AntiCheat.ps1 -DryRun   list games / titles only
param([switch]$DryRun)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
if (-not $DryRun -and -not (Test-Admin)) { throw 'Run as administrator.' }

# game folders: Steam libraries + EA app installs ("Install Dir" registry values) on the shared disks
$dirs = New-Object System.Collections.Generic.List[string]
foreach ($lib in Get-SteamLibraries) {
  Get-ChildItem (Join-Path $lib 'steamapps\common') -Directory -ErrorAction SilentlyContinue | ForEach-Object { $dirs.Add($_.FullName) }
}
foreach ($hive in 'HKLM:\SOFTWARE\WOW6432Node', 'HKLM:\SOFTWARE') {
  foreach ($pub in Get-ChildItem $hive -ErrorAction SilentlyContinue) {
    foreach ($k in Get-ChildItem $pub.PSPath -ErrorAction SilentlyContinue) {
      $p = "$($k.GetValue('Install Dir'))"
      if ($p -and (Test-Path -LiteralPath $p)) { $dirs.Add($p.TrimEnd('\')) }
    }
  }
}

$jobs = @()
foreach ($dir in $dirs | Sort-Object -Unique) {
  $cfg = Join-Path $dir 'EAAntiCheat.cfg'
  if (-not (Test-Path -LiteralPath $cfg)) { continue }
  # the cfg lists "default <game exe> <title>"
  $text = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($cfg)) -replace '[^\x20-\x7e]', '|'
  $m = [regex]::Match($text, 'default\|+[^|]+\.exe\|+([A-Za-z0-9_]+)')
  if (-not $m.Success) { Write-Output "WARNING no title in $cfg"; continue }
  $title = $m.Groups[1].Value
  # 18 Nov 2026: BOTH places count - Steam's Apex kept an old __Installer copy (1.0.15546623) next to its current
  # EAAntiCheat.Installer.exe (1.0.16556144); taking the __Installer one first gave clients the old EA AntiCheat and Apex
  # closed at "Starting EA Javelin Anticheat..."
  $inst = @((Join-Path $dir '__Installer\customcomponent\Javelin\EAAntiCheat.Installer.exe'), (Join-Path $dir 'EAAntiCheat.Installer.exe')) |
    Where-Object { Test-Path -LiteralPath $_ }
  if (-not $inst) { Write-Output "WARNING no EAAntiCheat.Installer.exe in $dir"; continue }
  foreach ($i in $inst) { $jobs += [pscustomobject]@{ Title = $title; Installer = $i; Dir = $dir } }
}
if (-not $jobs) { Write-Output 'No EA AntiCheat games found on the shared disks.'; return }
function Get-Ver([string]$p) { $v = "$((Get-Item -LiteralPath $p -ErrorAction SilentlyContinue).VersionInfo.FileVersion)"; if ($v -as [version]) { [version]$v } else { [version]'0.0' } }
# one run per title, with the newest installer (Steam and EA-app copies of a game may differ in version); oldest first, so
# the newest EA AntiCheat is the one left installed (one service for all titles)
$jobs = @($jobs | Group-Object Title | ForEach-Object { $_.Group | Sort-Object { Get-Ver $_.Installer } -Descending | Select-Object -First 1 } | Sort-Object { Get-Ver $_.Installer })
$jobs | ForEach-Object { Write-Output ('{0,-6} {1}' -f $_.Title, $_.Installer) }
if ($DryRun) { Write-Output 'DryRun: nothing installed.'; return }

# installed before on this PC with the same installer version = skip (keeps every boot fast, Client-Install.ps1 -Boot)
$marks = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64').CreateSubKey('SOFTWARE\OSYNC\EAAntiCheat')
$svcBefore = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'"
# version of the EA AntiCheat service on this PC now (the image may carry an older one than the game disk needs)
function Get-SvcVer { $s = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'"; if ($s) { Get-Ver ([regex]::Match("$($s.PathName)", '^"?([^"]+?\.exe)').Groups[1].Value) } else { [version]'0.0' } }
$fail = 0
foreach ($j in $jobs) {
  $sig = "$($j.Title)|$((Get-Item -LiteralPath $j.Installer).VersionInfo.FileVersion)"
  $sv = Get-SvcVer
  if ($svcBefore -and $marks.GetValue($sig) -and $sv -ge (Get-Ver $j.Installer)) { Write-Output ('{0,-6} already installed (service {1})' -f $j.Title, $sv); continue }
  if ($sv -gt [version]'0.0') { Write-Output ('{0,-6} service {1} -> installer {2}' -f $j.Title, $sv, (Get-Ver $j.Installer)) }
  $r = Invoke-Installer $j.Installer @('--noui', '--install', '--title', $j.Title) "EA AntiCheat $($j.Title)"
  if ($null -eq $r.Code) { $fail++; continue }
  Write-Output ('{0,-6} exit {1}, {2} s' -f $j.Title, $r.Code, $r.Sec)
  if ($r.Code -ne 0) { $fail++ } else { $marks.SetValue($sig, 1, 'DWord') }
}
$svc = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'"
Write-Output $(if ($svc) { "EAAntiCheatService: $($svc.StartMode)  $($svc.PathName)" } else { 'ERROR EAAntiCheatService was not created' })
if ($fail -or -not $svc) { exit 1 }
Write-Output 'Done. Save the image, then start Apex / Battlefield from the menu.'
