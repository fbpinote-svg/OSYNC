# EAC-Install.ps1 - install EasyAntiCheat (EOS) on a CLIENT PC for every game on the shared disks that uses it
# (Dead by Daylight, Rust, Chivalry 2, VRChat, Fortnite ...). Steam/Epic install it only on the PC that installed
# the game, so on clients these games may refuse to start or ask for admin rights.
# Run ONCE as administrator in super-workstation (image edit) mode, then save the image.
#   EAC-Install.ps1             install
#   EAC-Install.ps1 -DryRun     list games only
#   EAC-Install.ps1 -Snapshot   MASTER: save the EAC product ids installed here (e.g. Fortnite, whose id is not in
#                               a Settings.json) to _system\eac-products.txt so clients install them too
param([switch]$DryRun, [switch]$Snapshot)
. (Join-Path $PSScriptRoot 'Settings.ps1')
$ErrorActionPreference = 'Stop'
$idFile = Join-Path $KitSystem 'eac-products.txt'
if ($Snapshot) {
  $ids = @("$((Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\EasyAntiCheat_EOS' -ErrorAction SilentlyContinue).ProductsInstalled)" -split ';' | Where-Object { $_ -match '^[0-9a-f]{32}$' })
  [IO.File]::WriteAllLines($idFile, [string[]]$ids)
  Write-Output "EasyAntiCheat products on this master: $($ids.Count) -> $idFile"
  return
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run as administrator.' }

# game folders: Steam libraries, Epic games (install list from the master), X:\Online, X:\Mobile, X:\PvP, X:\EPIC
$roots = New-Object System.Collections.Generic.List[string]
foreach ($d in (Get-SharedDrives).ToCharArray()) {
  foreach ($p in "${d}:\SteamLibrary\steamapps\common", "${d}:\Online", "${d}:\Mobile", "${d}:\PvP", "${d}:\EPIC") {
    Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { $roots.Add($_.FullName) }
  }
}
foreach ($f in Get-ChildItem (Join-Path $KitSystem 'Epic-InstallData\Manifests') -Filter *.item -ErrorAction SilentlyContinue) {
  $loc = (Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json).InstallLocation
  if ($loc -and (Test-Path -LiteralPath $loc)) { $roots.Add($loc.TrimEnd('\')) }
}

$found = @()
foreach ($r in $roots | Sort-Object -Unique) {
  foreach ($s in Get-ChildItem -LiteralPath $r -Filter 'Settings.json' -Recurse -Depth 6 -File -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq 'EasyAntiCheat' }) {
    $id = try { (Get-Content -LiteralPath $s.FullName -Raw | ConvertFrom-Json).productid } catch { $null }
    if (-not $id) { continue }
    $setup = Get-ChildItem -LiteralPath $s.DirectoryName -Filter 'EasyAntiCheat_EOS_Setup.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $found += [pscustomobject]@{ Game = Split-Path -Leaf $r; ProductId = $id; Setup = $(if ($setup) { $setup.FullName } else { '' }) }
  }
}
# products the master installed (e.g. Fortnite through Epic)
if (Test-Path -LiteralPath $idFile) {
  foreach ($id in Get-Content -LiteralPath $idFile | Where-Object { $_ -match '^[0-9a-f]{32}$' }) {
    if (-not ($found | Where-Object ProductId -eq $id)) { $found += [pscustomobject]@{ Game = '(master)'; ProductId = $id; Setup = '' } }
  }
}
if (-not $found) { Write-Output 'No EasyAntiCheat games found on the shared disks.'; return }
# games without their own setup use the newest one found
$newest = $found | Where-Object Setup | Sort-Object { (Get-Item -LiteralPath $_.Setup).LastWriteTime } -Descending | Select-Object -First 1 -ExpandProperty Setup
if (-not $newest) {   # only games like Fortnite, whose EAC setup has no Settings.json next to it
  $newest = $roots | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter 'EasyAntiCheat_EOS_Setup.exe' -Recurse -Depth 6 -File -ErrorAction SilentlyContinue } |
    Select-Object -First 1 -ExpandProperty FullName
}
$found = @($found | Sort-Object ProductId -Unique | ForEach-Object { if (-not $_.Setup) { $_.Setup = $newest }; $_ })
$found | ForEach-Object { Write-Output ('{0,-22} {1}' -f $_.Game, $_.ProductId) }
if (-not $newest) { Write-Output 'WARNING no EasyAntiCheat_EOS_Setup.exe found'; exit 1 }
if ($DryRun) { Write-Output 'DryRun: nothing installed.'; return }

$fail = 0
foreach ($g in $found) {
  $p = Start-Process -FilePath $g.Setup -ArgumentList 'install', $g.ProductId -WorkingDirectory (Split-Path -Parent $g.Setup) -Wait -PassThru -WindowStyle Hidden
  Write-Output ('{0,-22} exit {1}' -f $g.Game, $p.ExitCode)
  if ($p.ExitCode -ne 0) { $fail++ }
}
$svc = Get-CimInstance Win32_Service -Filter "Name='EasyAntiCheat_EOS'"
Write-Output $(if ($svc) { "EasyAntiCheat_EOS: $($svc.StartMode)  $($svc.PathName)" } else { 'ERROR EasyAntiCheat_EOS service was not created' })
if ($fail -or -not $svc) { exit 1 }
