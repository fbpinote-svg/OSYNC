# Master-Update.ps1 - MASTER: after installing / updating / removing games, refresh everything clients use
# (OSYNC.bat > 1; the watcher Master-Watch.ps1 runs it by itself after updates and every hour).
# Riot Client may stay open; while a Riot game is still patching, step 1 fails - run again when it is done.
#   1 Riot : install state of VALORANT / LoL / TFT -> System\Data\Riot     2 EA  : EA app + games -> System\Data\EA
#   3 Epic : Epic games list -> System\Data\Epic                             4 EAC : EasyAntiCheat products -> System\Data\EAC
#   4b BNet: Battle.net Update Agent (C:\ProgramData\Battle.net\Agent) -> System\Data\BattleNet (Battle.net, Overwatch on Steam)
#   5 Menu : rescan all games -> Menu\data\games.json
#   6 Cfx : FiveM -> GTA V Legacy, RedM -> RDR2 (CitizenFX.ini next to them on the game disk, so clients never ask)
#   7 OSLink: which OSLink files the clients may trust (signatures checked here) -> System\Data\Oslink\trusted.txt
param([string]$GameListOut = '')     # tests: write the game list somewhere else instead of Menu\data\games.json
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $GameListOut) { Stop-IfPreMigration 'Update clients' }
Write-Host "OSYNC master update on $env:COMPUTERNAME  ($Root)" -ForegroundColor Cyan

# one run at a time: the watcher and the button can start this together
$lock = New-Object Threading.Mutex($false, 'Local\OSYNC-Update-All')
try {
  if (-not $lock.WaitOne(0)) {
    Write-Host 'Another update is running, waiting for it to finish ...' -ForegroundColor DarkYellow
    if (-not $lock.WaitOne([TimeSpan]::FromMinutes(30))) { Write-Host 'Still running after 30 min, stopped.' -ForegroundColor Red; exit 1 }
  }
} catch [Threading.AbandonedMutexException] { }

$results = New-Object System.Collections.Generic.List[object]
function Step([string]$name, [string]$file, [string[]]$extra = @()) {
  Write-Host "`n== $name" -ForegroundColor Yellow
  if (-not (Test-Path -LiteralPath $file)) { $results.Add([pscustomobject]@{ Step = $name; Result = 'SKIP (script missing)' }); return }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @extra 2>&1 | ForEach-Object { "    $_" } | Out-Host
  $results.Add([pscustomobject]@{ Step = $name; Result = $(if ($LASTEXITCODE -eq 0) { 'OK' } else { "FAIL (exit $LASTEXITCODE)" }) })
}

Step '1 Riot - VALORANT / LoL / TFT'   (Join-Path $ScriptsDir 'Master-Snapshot-Riot.ps1')
Step '2 EA   - EA app + games'          (Join-Path $ScriptsDir 'Master-Snapshot-EA.ps1')
Step '3 Epic - Epic games'              (Join-Path $ScriptsDir 'Master-Snapshot-Epic.ps1')
Step '4 EAC  - EasyAntiCheat products'  (Join-Path $ScriptsDir 'Client-EAC.ps1') @('-Snapshot')
Step '4b BNet - Battle.net Update Agent' (Join-Path $ScriptsDir 'Master-Snapshot-BattleNet.ps1')
Step '5 Menu - game list'               (Join-Path $ScriptsDir 'Master-GameList.ps1') $(if ($GameListOut) { @('-Out', $GameListOut) } else { @() })
Step '6 Cfx  - FiveM / RedM game folder' (Join-Path $ScriptsDir 'Master-CitizenFX.ps1') $(if ($GameListOut) { @('-Check') } else { @() })
Step '7 OSLink - files the clients may trust' (Join-Path $ScriptsDir 'Master-Snapshot-Oslink.ps1') $(if ($GameListOut) { @('-Check') } else { @() })

Write-Host "`n================ RESULT ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ('{0,-36} {1}' -f $_.Step, $_.Result) -ForegroundColor $(if ($_.Result -eq 'OK') { 'Green' } elseif ($_.Result -like 'SKIP*') { 'DarkYellow' } else { 'Red' }) }
Write-Host "`nClients pick this up after a reboot. New games are set up on each client at boot (task OSYNC-Client-Boot)." -ForegroundColor Cyan
if ($results | Where-Object { $_.Result -like 'FAIL*' }) { exit 1 }
