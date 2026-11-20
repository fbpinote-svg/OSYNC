# Master-Snapshot-Epic.ps1 - MASTER, after installing/updating an Epic game (Master-Update.ps1 runs it).
# Copies the Epic install list (C:\ProgramData\Epic) into System\Data\Epic for Client-Epic-Start.ps1 on clients.
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
$src = Join-Path $env:ProgramData 'Epic'
$dst = Join-Path $DataDir 'Epic'
New-Item -ItemType Directory -Force -Path (Join-Path $dst 'Manifests') | Out-Null
$srcMan = Join-Path $src 'EpicGamesLauncher\Data\Manifests'
$srcDat = Join-Path $src 'UnrealEngineLauncher\LauncherInstalled.dat'
if (-not (Test-Path -LiteralPath $srcMan)) {
  # Epic launcher installed but no Epic game yet (or never opened): nothing for clients, not an error
  Get-ChildItem -LiteralPath (Join-Path $dst 'Manifests') -Filter *.item -ErrorAction SilentlyContinue | Remove-Item -Force
  Remove-Item -LiteralPath (Join-Path $dst 'LauncherInstalled.dat') -Force -ErrorAction SilentlyContinue
  "no Epic games on this master ($srcMan missing) - nothing to copy"
  exit 0
}
& robocopy.exe $srcMan (Join-Path $dst 'Manifests') *.item /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE)" }
if (Test-Path -LiteralPath $srcDat) { Copy-Item -LiteralPath $srcDat -Destination $dst -Force }
else { Remove-Item -LiteralPath (Join-Path $dst 'LauncherInstalled.dat') -Force -ErrorAction SilentlyContinue; 'no LauncherInstalled.dat yet (no Epic game installed)' }
$shared = Get-SharedDrives
foreach ($f in Get-ChildItem (Join-Path $dst 'Manifests') -Filter *.item) {
  $m = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
  $ok = $shared.Contains($m.InstallLocation.Substring(0, 1).ToUpper())
  '{0,-30} {1}{2}' -f $m.DisplayName, $m.InstallLocation, $(if ($ok) { '' } else { "   WARNING: drive not in SharedDrives=$shared (clients cannot see it)" })
}
"saved -> $dst"
