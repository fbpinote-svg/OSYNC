# Update-All.ps1 - MASTER: after installing / updating / removing games, refresh everything clients use
# (MASTER-Update-All.bat). Close Riot Client first if a Riot game is still downloading.
#   1 Riot : install state of VALORANT / LoL / TFT        2 EA  : EA app + EA games registration
#   3 Epic : Epic games list (Fortnite ...)               4 EAC : EasyAntiCheat products installed here
#   5 Menu : rescan all games -> GCafe\data\games.json
$root = Split-Path -Parent $PSScriptRoot
$sys  = Join-Path $root 'GAMELUNCHER\ClientSetup\_system'
Write-Host "OSYNC master update on $env:COMPUTERNAME  ($root)" -ForegroundColor Cyan

$results = New-Object System.Collections.Generic.List[object]
function Step([string]$name, [string]$file, [string[]]$extra = @()) {
  Write-Host "`n== $name" -ForegroundColor Yellow
  if (-not (Test-Path -LiteralPath $file)) { $results.Add([pscustomobject]@{ Step = $name; Result = 'SKIP (script missing)' }); return }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @extra 2>&1 | ForEach-Object { "    $_" } | Out-Host
  $results.Add([pscustomobject]@{ Step = $name; Result = $(if ($LASTEXITCODE -eq 0) { 'OK' } else { "FAIL (exit $LASTEXITCODE)" }) })
}

if (Get-Process -Name 'RiotClientServices' -ErrorAction SilentlyContinue) { Write-Host 'Riot Client is running - if a game is still updating, let it finish first.' -ForegroundColor DarkYellow }
Step '1 Riot - VALORANT / LoL / TFT'   (Join-Path $sys 'Snapshot-Metadata.ps1')
Step '2 EA   - EA app + games'          (Join-Path $sys 'Snapshot-EA.ps1')
Step '3 Epic - Epic games'              (Join-Path $sys 'Snapshot-Epic.ps1')
Step '4 EAC  - EasyAntiCheat products'  (Join-Path $sys 'EAC-Install.ps1') @('-Snapshot')
Step '5 Menu - game list'               (Join-Path $root 'GCafe\tools\_system\Build-GameList.ps1')

Write-Host "`n================ RESULT ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ('{0,-36} {1}' -f $_.Step, $_.Result) -ForegroundColor $(if ($_.Result -eq 'OK') { 'Green' } elseif ($_.Result -like 'SKIP*') { 'DarkYellow' } else { 'Red' }) }
Write-Host "`nClients pick this up after a reboot. Installed a new game? Also run CLIENT-Install-All.bat on one client in image mode, then save the image." -ForegroundColor Cyan
if ($results | Where-Object { $_.Result -like 'FAIL*' }) { exit 1 }
