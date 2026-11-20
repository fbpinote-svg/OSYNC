# Test-Console.ps1 - simulation test of the admin console (Console-Server.ps1) on the master, without touching the real
# settings, game list or posters: copies them into a temp folder ($env:OSYNC_SETTINGS / $env:OSYNC_MENU), starts the console
# on a test port and checks every API: status, games, rename / hide, picture upload / reset, add / remove a game drive,
# and the safety checks (Host header, X-OSYNC header). Also: the shop's own categories, games added by hand in
# extra-games.json (rename keeps the category, hide / show), pictures from game folders on the game drives, the drive page
# (real drives read only: a drive with games / the Windows drive is refused, nothing is written there), a fast status.
# Prints PASS / FAIL lines; exit 1 when something failed.
#   powershell -ExecutionPolicy Bypass -File System\Tests\Test-Console.ps1 [-Port 4766] [-Keep]
param([int]$Port = 4766, [switch]$Keep)
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'Scripts'
. (Join-Path $scripts 'Common.ps1')
$T = Join-Path $env:TEMP ("osync-console-test-" + (Get-Date).ToString('yyyyMMddHHmmss'))
$fails = 0; $passes = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') { if ($ok) { $script:passes++; Write-Host "PASS  $name" -ForegroundColor Green } else { $script:fails++; Write-Host "FAIL  $name  $detail" -ForegroundColor Red } }

# ---------- test copy ----------
New-Item -ItemType Directory -Force "$T\Settings", "$T\Menu\data" | Out-Null
Copy-Item (Join-Path $SettingsDir 'settings.txt'), (Join-Path $SettingsDir 'extra-games.json') "$T\Settings"
Copy-Item (Join-Path $Menu 'data\games.json') "$T\Menu\data"
if (Test-Path (Join-Path $Menu 'data\posters')) { Copy-Item (Join-Path $Menu 'data\posters') "$T\Menu\data" -Recurse } else { New-Item -ItemType Directory "$T\Menu\data\posters" | Out-Null }
$env:OSYNC_SETTINGS = "$T\Settings"; $env:OSYNC_MENU = "$T\Menu"
$liveHash = (Get-FileHash (Join-Path $SettingsDir 'extra-games.json')).Hash, (Get-FileHash (Join-Path $SettingsDir 'settings.txt')).Hash, (Get-FileHash (Join-Path $Menu 'data\games.json')).Hash

$p = Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $scripts 'Console-Server.ps1') + '"'), '-Port', $Port, '-AllowStop', '-TestRoot', ('"' + $T + '"'))
$base = "http://127.0.0.1:$Port"
for ($i = 0; $i -lt 40; $i++) { try { Invoke-WebRequest "$base/api/status" -UseBasicParsing -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep -Milliseconds 300 } }
function Get-Api([string]$path) { Invoke-RestMethod "$base$path" -UseBasicParsing -TimeoutSec 60 }
function Post-Api([string]$path, $body) { Invoke-RestMethod "$base$path" -Method POST -UseBasicParsing -TimeoutSec 120 -Headers @{ 'X-OSYNC' = '1' } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $body -Compress))) }
function Get-Code([scriptblock]$sb) { try { & $sb | Out-Null; 200 } catch { try { [int]$_.Exception.Response.StatusCode } catch { -1 } } }

try {
  # page + status
  $page = Invoke-WebRequest "$base/" -UseBasicParsing
  Check 'page / served' ($page.StatusCode -eq 200 -and $page.Content -match 'OSYNC Console')
  $st = Get-Api '/api/status'
  Check 'status: uses the test copy' ($st.settings -eq "$T\Settings" -and $st.menu -eq "$T\Menu") "$($st.settings) $($st.menu)"
  Check "status: game count ($($st.games))" ($st.games -gt 0)
  $sw = [Diagnostics.Stopwatch]::StartNew(); Get-Api '/api/status' | Out-Null
  Check "status answers fast ($($sw.ElapsedMilliseconds) ms)" ($sw.ElapsedMilliseconds -lt 1500)

  # safety
  Check 'POST without X-OSYNC header is refused (403)' ((Get-Code { Invoke-RestMethod "$base/api/update" -Method POST -UseBasicParsing }) -eq 403)
  Check 'other Host header is refused (403)' ((Get-Code { Invoke-WebRequest "$base/api/status" -UseBasicParsing -Headers @{ Host = 'evil.example' } }) -eq 403)
  Check 'path outside the poster folders is refused (404)' ((Get-Code { Invoke-WebRequest "$base/poster/C:\Windows\win.ini" -UseBasicParsing }) -eq 404)

  # games
  $g = Get-Api '/api/games'
  # a game the shop has not renamed / moved / added by hand (so "undo" = no entry in extra-games.json)
  $pick = @($g.games | Where-Object { -not $_.hidden -and -not $_.renamed -and -not $_.recat -and -not $_.added -and -not $_.customIcon -and $_.id -match '^[A-Za-z0-9._\-]+$' })[0]
  $exBefore = (Get-Content "$T\Settings\extra-games.json" -Raw -Encoding UTF8 | ConvertFrom-Json).games | Where-Object { $_.id -ne $pick.id } | ConvertTo-Json -Depth 6 -Compress
  Check "games list ($(@($g.games).Count) games, testing with $($pick.id))" ($pick -ne $null)
  $r = Post-Api '/api/game' @{ id = $pick.id; title = 'CONSOLE TEST NAME'; cat = 'Mobile' }
  $after = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $pick.id }
  Check 'rename + category -> extra-games.json + game list' ($r.ok -and $after.title -eq 'CONSOLE TEST NAME' -and $after.cat -eq 'Mobile') "$($after.title) / $($after.cat)"
  $r = Post-Api '/api/game' @{ id = $pick.id; hide = $true }
  $inList = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $pick.id }
  $g2 = Get-Api '/api/games'; $hid = @($g2.games | Where-Object { $_.id -eq $pick.id })[0]
  Check 'hide -> gone from the menu, shown as hidden in the console' ((-not $inList) -and $hid.hidden) "inList=$([bool]$inList) hidden=$($hid.hidden)"
  $r = Post-Api '/api/game' @{ id = $pick.id; title = ''; cat = ''; hide = $false }
  $back = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $pick.id }
  $ex = Get-Content "$T\Settings\extra-games.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'undo -> original name back, no leftover entry' ($back.title -eq $pick.title -and -not @($ex.games | Where-Object { $_.id -eq $pick.id -and -not $_.exe }).Count) "$($back.title)"
  Check 'extra-games.json keeps its help text' ([bool]$ex._help)
  Check 'the other games'' entries in extra-games.json are unchanged' ((($ex.games | Where-Object { $_.id -ne $pick.id } | ConvertTo-Json -Depth 6 -Compress)) -eq $exBefore)

  # picture
  Add-Type -AssemblyName System.Drawing
  $bmp = New-Object Drawing.Bitmap 460, 215; $gr = [Drawing.Graphics]::FromImage($bmp); $gr.Clear([Drawing.Color]::FromArgb(40, 90, 200)); $gr.Dispose()
  $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $r = Post-Api '/api/icon' @{ id = $pick.id; data = ('data:image/png;base64,' + [Convert]::ToBase64String($ms.ToArray())) }
  $img = (@(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $pick.id }).img
  Check 'picture upload -> posters\<id>.png, used by the game list' ($r.ok -and (Test-Path "$T\Menu\data\posters\$($pick.id).png") -and [uri]::UnescapeDataString("$img") -like "*posters\$($pick.id).png") "$img"
  $pr = Invoke-WebRequest ("$base" + $img) -UseBasicParsing
  Check 'console serves that picture' ($pr.StatusCode -eq 200 -and $pr.RawContentLength -gt 100)
  Check 'not a picture is refused' ((Get-Code { Post-Api '/api/icon' @{ id = $pick.id; data = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('this is not an image file at all......')) } }) -eq 400)
  $r = Post-Api '/api/icon/reset' @{ id = $pick.id }
  Check 'picture reset -> file gone' ($r.ok -and -not (Test-Path "$T\Menu\data\posters\$($pick.id).png"))
  # a picture the menu takes from a game folder on a game drive (zPoster.jpg next to the game)
  $far = @((Get-Api '/api/games').games | Where-Object { "$($_.img)" -like '/poster/*' -and [uri]::UnescapeDataString("$($_.img)".Substring(8)) -notlike "$T\*" -and [uri]::UnescapeDataString("$($_.img)".Substring(8)) -notlike "$Menu\*" })[0]
  if ($far) { Check "picture from a game folder is served ($($far.id))" ((Get-Code { Invoke-WebRequest ("$base" + $far.img) -UseBasicParsing }) -eq 200) }
  else { Check 'picture from a game folder (none in this menu)' $true }

  # categories: the standard ones + every one the shop uses (e.g. "Anime RPG")
  $usedCats = @($g.games | ForEach-Object { "$($_.cat)" } | Where-Object { $_ } | Sort-Object -Unique)
  Check "every category in use can be chosen ($($usedCats -join ', '))" (-not @($usedCats | Where-Object { @($g.cats) -notcontains $_ }).Count)

  # a game added by hand (extra-games.json entry with "exe"): rename keeps its category, hide / show, entry unchanged after
  $exRaw = Get-Content "$T\Settings\extra-games.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  $hand = @($g.games | Where-Object { $_.added -and -not $_.hidden -and $_.cat -and -not $_.renamed -and $_.id -match '^[A-Za-z0-9._\-]+$' })[0]
  if ($hand) {
    $entryBefore = @($exRaw.games | Where-Object { $_.id -eq $hand.id }) | ConvertTo-Json -Depth 6 -Compress
    $r = Post-Api '/api/game' @{ id = $hand.id; title = 'HAND TEST NAME'; cat = ''; hide = $false }
    $after = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $hand.id }
    Check "hand-added game ($($hand.id)): rename keeps its category ($($hand.cat))" ($r.ok -and $after.title -eq 'HAND TEST NAME' -and $after.cat -eq $hand.cat) "$($after.title) / $($after.cat)"
    $r = Post-Api '/api/game' @{ id = $hand.id; hide = $true }
    $inList = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $hand.id }
    $hid = @((Get-Api '/api/games').games | Where-Object { $_.id -eq $hand.id })[0]
    Check 'hand-added game: hide -> gone from the menu, shown as hidden' ((-not $inList) -and $hid.hidden) "inList=$([bool]$inList) hidden=$($hid.hidden)"
    $r = Post-Api '/api/game' @{ id = $hand.id; title = $hand.title; hide = $false }
    $back = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.id -eq $hand.id }
    $entryAfter = @((Get-Content "$T\Settings\extra-games.json" -Raw -Encoding UTF8 | ConvertFrom-Json).games | Where-Object { $_.id -eq $hand.id }) | ConvertTo-Json -Depth 6 -Compress
    Check 'hand-added game: show again -> back in the menu, its extra-games.json entry as before' ($back -and $back.title -eq $hand.title -and $entryAfter -eq $entryBefore) $entryAfter
  } else { Check 'hand-added game (none in this menu)' $true }

  # the real drives: read only. Refusals happen before anything is written (and clientsOff is not even sent).
  $d0 = Get-Api '/api/drives'
  $full = @($d0.drives | Where-Object { $_.hasGames -and -not $_.system -and -not $_.diskless })[0]
  if ($full) { Check "drive with games ($($full.letter):) has no 'use for games' and adding it is refused" ((-not $full.canAdd) -and (Get-Code { Post-Api '/api/drives/add' @{ letter = $full.letter } }) -eq 400) }
  $sysd = @($d0.drives | Where-Object { $_.system })[0]
  if ($sysd) { Check "the Windows drive ($($sysd.letter):) is refused" ((-not $sysd.canAdd) -and (Get-Code { Post-Api '/api/drives/add' @{ letter = $sysd.letter } }) -eq 400) }
  Check "drive page lists what is scanned ($(@($d0.drives | Where-Object { $_.hasGames }).Count) drives with games, layout $($d0.style))" (@($d0.drives).Count -gt 0 -and $d0.style -in 'top', 'game')

  # game drive (a test folder: -TestRoot lets it skip the drive checks)
  $gd = "$T\X-GAME"
  $r = Post-Api '/api/drives/add' @{ path = $gd; clientsOff = $true }
  $stx = Get-Content "$T\Settings\settings.txt" -Encoding UTF8 | Where-Object { $_ -match '^GameFolders=' }
  Check 'add drive -> category folders + GameFolders' ($r.ok -and (Test-Path "$gd\Online") -and (Test-Path "$gd\Single Player") -and "$stx" -like "*$gd*") "$stx"
  $d = Get-Api '/api/drives'
  Check 'drives list shows it' (@($d.folders) -contains $gd)
  New-Item -ItemType Directory -Force "$gd\Online\Console Test Game" | Out-Null
  Copy-Item "$env:SystemRoot\System32\notepad.exe" "$gd\Online\Console Test Game\ctgame.exe"
  $u = Post-Api '/api/update' @{}
  $found = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.cmd -like '*Console Test Game*' }
  Check 'a game put on the new drive shows up after the update' ($u.ok -and $found) ($u.log -join ' | ')
  Check 'adding it twice is refused' ((Get-Code { Post-Api '/api/drives/add' @{ path = $gd; clientsOff = $true } }) -eq 400)
  $r = Post-Api '/api/drives/remove' @{ path = $gd }
  $gone = @(Get-Content "$T\Menu\data\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.cmd -like '*Console Test Game*' }
  Check 'remove drive -> its games leave the list, files stay' ($r.ok -and -not $gone -and (Test-Path "$gd\Online\Console Test Game\ctgame.exe"))

  # live files untouched
  $now = (Get-FileHash (Join-Path $SettingsDir 'extra-games.json')).Hash, (Get-FileHash (Join-Path $SettingsDir 'settings.txt')).Hash, (Get-FileHash (Join-Path $Menu 'data\games.json')).Hash
  Check 'the real settings / extra-games / games.json were not changed' (($now -join ',') -eq ($liveHash -join ','))
} catch { Check 'test run' $false "$($_.Exception.Message)" }
finally {
  try { Post-Api '/api/_stop' @{} | Out-Null } catch { }
  Start-Sleep -Milliseconds 300; if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  Remove-Item Env:\OSYNC_SETTINGS, Env:\OSYNC_MENU -ErrorAction SilentlyContinue
  if (-not $Keep) { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host ("console test: {0} passed, {1} failed{2}" -f $passes, $fails, $(if ($Keep) { " (kept $T)" } else { '' })) -ForegroundColor $(if ($fails) { 'Red' } else { 'Green' })
if ($fails) { exit 1 }
exit 0
