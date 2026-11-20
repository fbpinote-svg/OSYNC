# Master-Snapshot-BattleNet.ps1 - MASTER (Master-Update.ps1 runs it, so the watcher does too): copies the Battle.net Update
# Agent (C:\ProgramData\Battle.net\Agent: Agent.exe + its list of installed Blizzard games, product.db) into
# System\Data\BattleNet\Agent. Client-Install step 1v copies it back to C:\ProgramData\Battle.net\Agent at every boot:
# without the Agent, Battle.net (Launchers\BattleNet) does not open and Overwatch on Steam (its Blizzard launcher checks the
# game through the Agent) does not start. Only changed files are copied (robocopy), logs are left out.
# Not copied: the registry (its LocalBattlenetCertificate / PrivateKey are encrypted for this PC only).
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
$src = Join-Path $env:ProgramData 'Battle.net\Agent'
$dst = Join-Path $DataDir 'BattleNet\Agent'
if (-not (Test-Path -LiteralPath (Join-Path $src 'Agent.exe'))) { "no Battle.net Agent on this master ($src) - nothing to copy"; exit 0 }
New-Item -ItemType Directory -Force -Path $dst | Out-Null
& robocopy.exe $src $dst /MIR /XD Logs /XF *.log *.lock /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
$rc = $LASTEXITCODE
if ($rc -ge 8) { throw "copy failed (robocopy $rc)" }
$ver = (Get-ChildItem -LiteralPath $dst -Directory -Filter 'Agent.*' | Sort-Object Name | Select-Object -Last 1).Name
$kb = [int]((Get-ChildItem -LiteralPath $dst -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
"$(if ($rc -eq 0) { 'unchanged' } else { 'updated' }): $ver, $kb KB -> $dst"
