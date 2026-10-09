# Snapshot-Epic.ps1 - run on the MASTER after installing/updating an Epic game.
# Copies the Epic install list (C:\ProgramData\Epic) into _system\Epic-InstallData for EpicStart.ps1 on clients.
. (Join-Path $PSScriptRoot 'Settings.ps1')
$ErrorActionPreference = 'Stop'
$src = Join-Path $env:ProgramData 'Epic'
$dst = Join-Path $KitSystem 'Epic-InstallData'
New-Item -ItemType Directory -Force -Path (Join-Path $dst 'Manifests') | Out-Null
& robocopy.exe (Join-Path $src 'EpicGamesLauncher\Data\Manifests') (Join-Path $dst 'Manifests') *.item /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $src 'UnrealEngineLauncher\LauncherInstalled.dat') -Destination $dst -Force
$shared = Get-SharedDrives
foreach ($f in Get-ChildItem (Join-Path $dst 'Manifests') -Filter *.item) {
  $m = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
  $ok = $shared.Contains($m.InstallLocation.Substring(0, 1).ToUpper())
  '{0,-30} {1}{2}' -f $m.DisplayName, $m.InstallLocation, $(if ($ok) { '' } else { "   WARNING: drive not in SharedDrives=$shared (clients cannot see it)" })
}
"saved -> $dst"
