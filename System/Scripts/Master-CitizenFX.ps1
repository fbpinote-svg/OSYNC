# Master-CitizenFX.ps1 - MASTER: points FiveM at GTA V Legacy and RedM at Red Dead Redemption 2 (Master-Update step 6).
# FiveM / RedM ask for the game folder in a file dialog when they cannot find the game (diskless clients have no Rockstar
# registry keys) and keep the answer in <FiveM|RedM>.app\CitizenFX.ini [Game] IVPath=. That file is on the game disk next to
# FiveM / RedM, so writing it here points every client - no file dialog on the clients.
#   - the game folder: Steam libraries (GTA V Legacy 271590 - FiveM cannot use Enhanced 3240220 / RDR2 1174180), then
#     Rockstar's registry keys, then GAME\Rockstar / GAME\Epic; it must be on a drive the clients see
#   - written only when IVPath is missing or no longer a usable game folder (moved / removed); a usable folder the shop
#     picked itself is kept; every other line in the file stays
#   - games moved / a new shop: the next run (watcher every hour, or OSYNC.bat > 1) points them again
# -Check: report only, write nothing.
param([switch]$Check)
. (Join-Path $PSScriptRoot 'Common.ps1')
$st = @(Get-CfxStatus)
if (-not $st.Count) { Write-Host 'FiveM / RedM: not on the game disk - nothing to do'; exit 0 }
$failed = $false
foreach ($s in $st) {
  if ($s.HaveOk) { Write-Host "$($s.Name): points at $($s.Have) - OK"; continue }
  $now = if ($s.Have) { "now: $($s.Have) (not a usable $($s.Game) folder)" } else { 'now: not set' }
  if (-not $s.Want) { Write-Host "$($s.Name): $($s.Game) not found on the drives the clients see - $($s.Name) will ask for the folder ($now)"; continue }
  if ($Check) { Write-Host "$($s.Name): would point at $($s.Want) ($now)"; continue }
  try {
    Set-CfxIVPath $s.Ini $s.Want
    if ((Get-CfxIVPath $s.Ini) -ieq $s.Want) { Write-Host "$($s.Name): now points at $($s.Want) ($($s.Ini); was $(if ($s.Have) { $s.Have } else { 'not set' }))" }
    else { Write-Host "$($s.Name): wrote $($s.Ini) but it does not read back as $($s.Want)"; $failed = $true }
  } catch { Write-Host "$($s.Name): could not write $($s.Ini): $($_.Exception.Message)"; $failed = $true }
}
if ($failed) { exit 1 }
exit 0
