# EAAntiCheat-Install.ps1 - install EA AntiCheat (Javelin) on a CLIENT PC for every EA game on the shared disks.
# Apex / Battlefield start through EAAntiCheat.GameServiceLauncher.exe, which needs the EAAntiCheatService
# (C:\Program Files\EA\AC) on the PC itself. The EA app installs it only on the PC that installed the game
# (the master), so on clients the splash shows "Checking for updates..." and closes.
# Run ONCE as administrator in super-workstation (image edit) mode, then save the image.
#   EAAntiCheat-Install.ps1           install
#   EAAntiCheat-Install.ps1 -DryRun   list games / titles only
param([switch]$DryRun)
. (Join-Path $PSScriptRoot 'Settings.ps1')
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run as administrator.' }

# game folders: Steam libraries + EA app installs ("Install Dir" registry values) on the shared disks
$dirs = New-Object System.Collections.Generic.List[string]
foreach ($d in (Get-SharedDrives).ToCharArray()) {
  Get-ChildItem "${d}:\SteamLibrary\steamapps\common" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $dirs.Add($_.FullName) }
}
foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node', 'HKLM:\SOFTWARE') {
  foreach ($pub in Get-ChildItem $root -ErrorAction SilentlyContinue) {
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
  $inst = @((Join-Path $dir '__Installer\customcomponent\Javelin\EAAntiCheat.Installer.exe'), (Join-Path $dir 'EAAntiCheat.Installer.exe')) |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $inst) { Write-Output "WARNING no EAAntiCheat.Installer.exe in $dir"; continue }
  $jobs += [pscustomobject]@{ Title = $title; Installer = $inst; Dir = $dir }
}
if (-not $jobs) { Write-Output 'No EA AntiCheat games found on the shared disks.'; return }
# one run per title, with the newest installer (Steam and EA-app copies of a game may differ in version)
$jobs = @($jobs | Group-Object Title | ForEach-Object { $_.Group | Sort-Object { [version](Get-Item -LiteralPath $_.Installer).VersionInfo.FileVersion } -Descending | Select-Object -First 1 })
$jobs | ForEach-Object { Write-Output ('{0,-6} {1}' -f $_.Title, $_.Installer) }
if ($DryRun) { Write-Output 'DryRun: nothing installed.'; return }

$fail = 0
foreach ($j in $jobs) {
  $p = Start-Process -FilePath $j.Installer -ArgumentList '--noui', '--install', '--title', $j.Title -WorkingDirectory (Split-Path -Parent $j.Installer) -Wait -PassThru -WindowStyle Hidden
  Write-Output ('{0,-6} exit {1}' -f $j.Title, $p.ExitCode)
  if ($p.ExitCode -ne 0) { $fail++ }
}
$svc = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'"
Write-Output $(if ($svc) { "EAAntiCheatService: $($svc.StartMode)  $($svc.PathName)" } else { 'ERROR EAAntiCheatService was not created' })
if ($fail -or -not $svc) { exit 1 }
Write-Output 'Done. Save the image, then start Apex / Battlefield from the menu.'
