# Client-Epic-Start.ps1 - start an Epic game on a client PC (works on the master too). System\Client\Epic.vbs runs it.
# A client boots with its own C:, so it does not know which Epic games are installed on the game disks.
# This copies the master's Epic install list (System\Data\Epic, made by Master-Snapshot-Epic.ps1) into
# C:\ProgramData\Epic when this PC's copy is missing or older, then asks the Epic launcher in Launchers\Epic
# to start the game. The player signs in to their own Epic account the first time.
#   Client-Epic-Start.ps1 -App Fortnite        (AppName from the manifest)
param([Parameter(Mandatory = $true)][string]$App)
. (Join-Path $PSScriptRoot 'Common.ps1')
$data = Join-Path $DataDir 'Epic'
$log  = Join-Path $env:TEMP 'EpicStart.log'
function Log($m) { Add-Content -LiteralPath $log -Value ('{0:HH:mm:ss} {1}' -f (Get-Date), $m) }
Log "start app=$App root=$Root"

$pd = Join-Path $env:ProgramData 'Epic'
# /XO: never overwrite a newer copy (the master's own live files stay untouched)
& robocopy.exe (Join-Path $data 'Manifests') (Join-Path $pd 'EpicGamesLauncher\Data\Manifests') *.item /XO /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
Log "manifests (robocopy $LASTEXITCODE)"
& robocopy.exe $data (Join-Path $pd 'UnrealEngineLauncher') LauncherInstalled.dat /XO /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
Log "LauncherInstalled.dat (robocopy $LASTEXITCODE)"

$exe = Get-LauncherExe 'Epic'
if (-not (Test-Path -LiteralPath $exe)) { Log "ERROR Epic launcher not found: $exe"; exit 1 }
$m = Get-ChildItem -LiteralPath (Join-Path $data 'Manifests') -Filter *.item -ErrorAction SilentlyContinue |
  ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json } | Where-Object AppName -eq $App | Select-Object -First 1
$id = if ($m) { '{0}%3A{1}%3A{2}' -f $m.CatalogNamespace, $m.CatalogItemId, $m.AppName } else { $App }
Start-Process -FilePath $exe -ArgumentList "com.epicgames.launcher://apps/${id}?action=launch&silent=true"
Log "launched $App"
