# Sim-OnlineLibrary.ps1 - simulation of the online library on ONE master: a hub + two branches, each with its own settings /
# menu / data folders in a temp folder. Branch A has "Sim Racer" + "Sim Arena" in GAME\Online and - laid out like a shop that
# keeps games at the top of its drives (X:\Online, X:\Mobile) and lists them by hand in extra-games.json - "Sim Hand"
# (drv\Online) and "Sim Twin" (drv\Mobile). Branch B has "Sim Arena" and its own copy of "Sim Twin" under another id.
# Checks: publish, the hub's list, "missing here" (= Sim Racer + Sim Hand: same id or same folder counts as "have"), hub key,
# tracker, disk-space refusal, B asks for both -> A makes the torrents -> B downloads them -> every piece checked -> B's menu.
# The branches never see the real game drives (SharedDrives = a drive letter that does not exist). Nothing real is changed.
#   -Engine mock  (default) copies on this PC and checks pieces    -Engine aria2  real BitTorrent between two aria2 on 127.0.0.1
#   -ClosedSide A|B  that branch cannot be reached (it tells the tracker 127.0.0.2, where nothing listens): the download only
#                    works because the other side's aria2 is connected TO it - "one side open is enough" (aria2 only)
#   -Upnp            both branches use OnlineUpnp=on against a fake router (Fake-Igd.ps1, secure mode, 127.0.0.1): aria2's
#                    port is mapped while it runs, renewed, and removed by -Stop; the hub maps / renews / removes its port;
#                    a port mapped to another host is left alone
#   powershell -ExecutionPolicy Bypass -File System\Tests\Sim-OnlineLibrary.ps1 [-Engine mock|aria2] [-ClosedSide A|B] [-Upnp] [-Keep]
param([ValidateSet('mock', 'aria2')][string]$Engine = 'mock', [int]$HubPort = 4790, [ValidateSet('none', 'A', 'B')][string]$ClosedSide = 'none', [switch]$Upnp, [switch]$Keep)
$ErrorActionPreference = 'Stop'
$scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'Scripts'
. (Join-Path $scripts 'Common.ps1')
. (Join-Path $scripts 'Online-Torrent.ps1')
# the long form of TEMP (a short TEMP like C:\Users\ABCDEF~1 would not match the long paths the game list writes)
$T = Join-Path (Get-Item -LiteralPath $env:TEMP).FullName ("osync-online-sim-" + (Get-Date).ToString('yyyyMMddHHmmss'))
$fails = 0; $passes = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') { if ($ok) { $script:passes++; Write-Host "PASS  $name" -ForegroundColor Green } else { $script:fails++; Write-Host "FAIL  $name  $detail" -ForegroundColor Red } }
if ($ClosedSide -ne 'none' -and $Engine -ne 'aria2') { Write-Host '-ClosedSide needs -Engine aria2' -ForegroundColor Red; exit 1 }
$b = New-Object byte[] 18; ([Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($b); $Key = ([Convert]::ToBase64String($b) -replace '[^A-Za-z0-9]', 'k')
$hub = "http://127.0.0.1:$HubPort"
$igdPort = $HubPort + 1; $igdUrl = "http://127.0.0.1:$igdPort/rootDesc.xml"
# SharedDrives of the branches = a drive with no games (no Steam library, no X:\Online ...): their game list / share scan must
# not see the real game drives (a letter that does not exist breaks Get-SteamLibraries, so an existing empty one)
$kindsList = 'Online', 'PvP', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'Garena', 'HoYoPlay', 'Gacha', 'Games', 'SteamLibrary', 'Steam'
$noDrive = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID.Substring(0, 1) } | Where-Object { $l = $_; -not @($kindsList | Where-Object { Test-Path -LiteralPath "${l}:\$_" }).Count } | Sort-Object -Descending)[0]
if (-not $noDrive) { Write-Host 'no drive without games for the simulation' -ForegroundColor Red; exit 1 }

# ---------- two branches ----------
$branches = [ordered]@{ A = @{ id = 'SIM-A'; name = 'Branch A'; bt = 6991; rpc = 6900 }; B = @{ id = 'SIM-B'; name = 'Branch B'; bt = 6992; rpc = 6901 } }
$rnd = New-Object Random 7
function New-FakeGame([string]$dir, [int[]]$sizes) { New-Item -ItemType Directory -Force "$dir\data" | Out-Null; Copy-Item "$env:SystemRoot\System32\notepad.exe" "$dir\game.exe"; $i = 0; foreach ($s in $sizes) { $x = New-Object byte[] $s; $script:rnd.NextBytes($x); [IO.File]::WriteAllBytes("$dir\data\part$i.pak", $x); $i++ } }
foreach ($k in $branches.Keys) {
  $br = $branches[$k]; $d = "$T\$k"; $br.dir = $d
  New-Item -ItemType Directory -Force "$d\Settings", "$d\Menu\data", "$d\GAME\Online", "$d\GAME\Mobile", "$d\data", "$d\drv\Online", "$d\drv\Mobile" | Out-Null
  $lines = Get-Content (Join-Path $SettingsDir 'settings.txt') -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*(GamesFolder|GameFolders|SharedDrives|Online\w+)\s*=' }
  $lines += "SharedDrives=$noDrive", "GamesFolder=$d\GAME", "OnlineHub=$hub", "OnlineBranch=$($br.id)", "OnlineBranchName=$($br.name)", "OnlineEngine=$Engine", "OnlineBtPort=$($br.bt)", "OnlineRpcPort=$($br.rpc)", "OnlineBind=127.0.0.1"
  if ($ClosedSide -eq $k) { $lines += 'OnlineExternalIP=127.0.0.2' }      # nothing listens there: nobody can connect to this branch
  if ($Upnp) { $lines += 'OnlineUpnp=on' }
  [IO.File]::WriteAllLines("$d\Settings\settings.txt", $lines, (New-Object Text.UTF8Encoding($false)))
  if (Test-Path (Join-Path $Menu 'data\posters')) { Copy-Item (Join-Path $Menu 'data\posters') "$d\Menu\data" -Recurse }
}
New-FakeGame "$T\A\GAME\Online\Sim Racer" @(9000000, 7000003, 1234567)
New-FakeGame "$T\A\GAME\Online\Sim Arena" @(3000000)
New-FakeGame "$T\A\drv\Online\Sim Hand" @(2500000, 1100000)
New-FakeGame "$T\A\drv\Mobile\Sim Twin" @(1500000)
Copy-Item "$T\A\GAME\Online\Sim Arena" "$T\B\GAME\Online" -Recurse
Copy-Item "$T\A\drv\Mobile\Sim Twin" "$T\B\GAME\Mobile" -Recurse
# A lists its drive games by hand (like J:\Online\PointBlank in extra-games.json); B has nothing extra
$exA = [ordered]@{ games = @([ordered]@{ id = 'sim-hand'; title = 'Sim Hand'; cat = 'Online'; exe = "$T\A\drv\Online\Sim Hand\game.exe" }, [ordered]@{ id = 'sim-twin-a'; title = 'Sim Twin'; cat = 'Anime RPG'; exe = "$T\A\drv\Mobile\Sim Twin\game.exe" }) }
[IO.File]::WriteAllText("$T\A\Settings\extra-games.json", (ConvertTo-Json $exA -Depth 5), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText("$T\B\Settings\extra-games.json", '{ "games": [] }', (New-Object Text.UTF8Encoding($false)))

function Invoke-As([string]$k, [string[]]$argv) {
  $br = $branches[$k]
  $env:OSYNC_SETTINGS = "$($br.dir)\Settings"; $env:OSYNC_MENU = "$($br.dir)\Menu"; $env:OSYNC_ONLINEDATA = "$($br.dir)\data"; $env:OSYNC_ONLINEKEY = $Key
  if ($k -eq 'A') { $env:OSYNC_DRIVEROOTS = "$($br.dir)\drv" }
  if ($Upnp) { $env:OSYNC_UPNP_LOCATION = $igdUrl }
  try { & powershell.exe -NoProfile -ExecutionPolicy Bypass @argv 2>&1 | ForEach-Object { "$_" } } finally { Remove-Item Env:\OSYNC_SETTINGS, Env:\OSYNC_MENU, Env:\OSYNC_ONLINEDATA, Env:\OSYNC_ONLINEKEY, Env:\OSYNC_DRIVEROOTS, Env:\OSYNC_UPNP_LOCATION -ErrorAction SilentlyContinue }
}
function Get-View([string]$k) { $o = Invoke-As $k @('-Command', ". '$scripts\Online-Library.ps1'; ConvertTo-Json -InputObject (Get-OnlineView) -Depth 8 -Compress"); ($o | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json }
function Get-Games([string]$k) { $x = [IO.File]::ReadAllText("$($branches[$k].dir)\Menu\data\games.json", [Text.Encoding]::UTF8) | ConvertFrom-Json; @($x) }
function Hub-Api([string]$m, [string]$p, $body, [string]$key = $Key) {
  $a = @{ Uri = "$hub$p"; Method = $m; UseBasicParsing = $true; TimeoutSec = 30; Headers = @{ 'X-Hub-Key' = $key } }
  if ($null -ne $body) { $a.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $body -Depth 6 -Compress)); $a.ContentType = 'application/json; charset=utf-8' }
  Invoke-RestMethod @a
}
function Get-Igd { Invoke-RestMethod "http://127.0.0.1:$igdPort/_state" -UseBasicParsing -TimeoutSec 10 }

$igdProc = $null
if ($Upnp) {
  $igdProc = Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + "$PSScriptRoot\Fake-Igd.ps1" + '"'), '-Port', $igdPort, '-ExternalIP', '127.0.0.1')
  for ($i = 0; $i -lt 40; $i++) { try { Get-Igd | Out-Null; break } catch { Start-Sleep -Milliseconds 300 } }
  Invoke-RestMethod "http://127.0.0.1:$igdPort/_seed" -Method POST -UseBasicParsing -ContentType 'application/json' -Body '{"port":6993,"client":"10.0.0.9","description":"Parsec on a client PC"}' | Out-Null
  # the hub uses branch A's settings (OnlineUpnp=on) and renews its mapping every 2 s
  $env:OSYNC_SETTINGS = "$T\A\Settings"; $env:OSYNC_UPNP_LOCATION = $igdUrl; $env:OSYNC_ONLINEDATA = "$T\hubnet"
}
$hubProc = Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + "$scripts\Hub-Server.ps1" + '"'), '-Port', $HubPort, '-Bind', '127.0.0.1', '-Key', $Key, '-HubDir', ('"' + "$T\hub" + '"'), '-AllowStop', '-UpnpRenewSec', 2)
Remove-Item Env:\OSYNC_SETTINGS, Env:\OSYNC_UPNP_LOCATION, Env:\OSYNC_ONLINEDATA -ErrorAction SilentlyContinue
for ($i = 0; $i -lt 40; $i++) { try { Hub-Api 'GET' '/api/catalog' $null | Out-Null; break } catch { Start-Sleep -Milliseconds 300 } }
try {
  Check "hub up on $hub" ((Hub-Api 'GET' '/api/catalog' $null).ok)
  $code = 0; try { Invoke-RestMethod "$hub/api/catalog" -UseBasicParsing -Headers @{ 'X-Hub-Key' = 'wrong-key-123456' } | Out-Null } catch { $code = [int]$_.Exception.Response.StatusCode }
  Check 'hub refuses a wrong key (403)' ($code -eq 403)

  # game lists of both branches
  foreach ($k in 'A', 'B') { Invoke-As $k @('-File', "$scripts\Master-GameList.ps1") | Out-Null }
  $racer = Get-Games 'A' | Where-Object { $_.cmd -like '*Sim Racer*' } | Select-Object -First 1
  Check "branch A's menu has Sim Racer ($($racer.id)) and the hand-added Sim Hand" ($racer -ne $null -and (Get-Games 'A' | Where-Object { $_.id -eq 'sim-hand' }))
  Check "branch B's menu has no Sim Racer" (-not (Get-Games 'B' | Where-Object { $_.cmd -like '*Sim Racer*' }))

  foreach ($k in 'A', 'B') { $o = Invoke-As $k @('-File', "$scripts\Online-Library.ps1", '-Publish'); Check "branch $k publishes its list" (($o -join ' ') -match '"ok":\s*true') ($o -join ' ') }
  $cat = Hub-Api 'GET' '/api/catalog' $null
  $ga = @($cat.branches | Where-Object { $_.branch -eq 'SIM-A' })[0]
  $gr = @($ga.games | Where-Object { $_.key -eq $racer.id })[0]
  Check "hub knows A's Sim Racer (kind $($gr.kind), $($gr.size) bytes, $($gr.files) files)" ($gr -and $gr.kind -eq 'folder' -and $gr.rel -eq 'Online\Sim Racer' -and $gr.size -gt 17000000)
  $gh = @($ga.games | Where-Object { $_.key -eq 'sim-hand' })[0]; $gt = @($ga.games | Where-Object { $_.key -eq 'sim-twin-a' })[0]
  Check "hub knows A's drive-layout games (Sim Hand -> $($gh.rel), Sim Twin -> $($gt.rel))" ($gh.rel -eq 'Online\Sim Hand' -and $gh.size -gt 3500000 -and $gt.rel -eq 'Mobile\Sim Twin')

  $v = Get-View 'B'
  $miss = @($v.missing)
  Check "B's 'missing here' = Sim Racer + Sim Hand, not its own Sim Twin under another id ($(($miss | ForEach-Object { $_.title }) -join ', '))" ($miss.Count -eq 2 -and @($miss.key) -contains $racer.id -and @($miss.key) -contains 'sim-hand' -and $miss[0].branches -contains 'Branch A')

  # where a pull lands on a shop that keeps games at the top of its drives (no game folder): <drive>\<kind>\<game>
  $env:OSYNC_DRIVEROOTS = "$T\C\drv"; New-Item -ItemType Directory -Force "$T\C\drv\Online", "$T\C\drv\Mobile" | Out-Null
  $o = Invoke-As 'B' @('-Command', "`$env:OSYNC_DRIVEROOTS = '$T\C\drv'; `$env:OSYNC_GAMEFOLDERS = ''; . '$scripts\Online-Library.ps1'; `$GamesRoot = '$T\C\none'; `$c = Get-OnlineConfig; (Get-PullDestination `$c @{ kind = 'folder'; rel = 'Minecraft' }) + '|' + (Get-PullDestination `$c @{ kind = 'folder'; rel = 'Gacha\Star Rail Games' })")
  Remove-Item Env:\OSYNC_DRIVEROOTS -ErrorAction SilentlyContinue
  Check "drive-layout destination: loose game -> Online\, missing kind -> similar existing one ($(($o | Select-Object -Last 1)))" (($o | Select-Object -Last 1) -eq "$T\C\drv\Online\Minecraft|$T\C\drv\Mobile\Star Rail Games")

  # disk space check: a branch C with a game far bigger than any disk
  Hub-Api 'POST' '/api/report' @{ branch = 'SIM-C'; name = 'Branch C'; games = @(@{ key = 'auto-hugegame'; title = 'Huge Game'; cat = 'Online'; kind = 'folder'; rel = 'Online\Huge Game'; size = 9000000000000000; files = 1 }) } | Out-Null
  $o = Invoke-As 'B' @('-File', "$scripts\Online-Library.ps1", '-Pull', 'auto-hugegame')
  Check 'pull refused when the disk is too small' (($o -join ' ') -match 'not enough space') ($o -join ' ')

  # tracker: two peers on one info hash
  $ih = -join (1..20 | ForEach-Object { '%{0:X2}' -f $_ })
  $r1 = Invoke-WebRequest "$hub/announce/$Key`?info_hash=$ih&peer_id=-SIM001-000000000001&port=50001&uploaded=0&downloaded=0&left=0&compact=1&event=started" -UseBasicParsing
  $r2 = Invoke-WebRequest "$hub/announce/$Key`?info_hash=$ih&peer_id=-SIM001-000000000002&port=50002&uploaded=0&downloaded=0&left=100&compact=1&event=started" -UseBasicParsing
  $d2 = ConvertFrom-Bencode $r2.RawContentStream.ToArray()
  $peers = [byte[]]$d2['peers']
  Check 'tracker gives peer 2 the address of peer 1 (127.0.0.1:50001)' ($peers.Length -eq 6 -and $peers[0] -eq 127 -and $peers[3] -eq 1 -and ($peers[4] * 256 + $peers[5]) -eq 50001 -and $d2['complete'] -eq 1)
  $r3 = Invoke-WebRequest "$hub/announce/$Key`?info_hash=$ih&peer_id=-SIM001-000000000003&port=50003&left=100&compact=1&ip=203.0.113.7" -UseBasicParsing
  $r4 = ConvertFrom-Bencode (Invoke-WebRequest "$hub/announce/$Key`?info_hash=$ih&peer_id=-SIM001-000000000004&port=50004&left=100&compact=1" -UseBasicParsing).RawContentStream.ToArray()
  $p4 = [byte[]]$r4['peers']; $ips = @(for ($i = 0; $i -lt $p4.Length; $i += 6) { '{0}.{1}.{2}.{3}:{4}' -f $p4[$i], $p4[$i + 1], $p4[$i + 2], $p4[$i + 3], ($p4[$i + 4] * 256 + $p4[$i + 5]) })
  Check "tracker uses the public IP a peer reports (ip=, aria2 --bt-external-ip): $($ips -join ' ')" ($ips -contains '203.0.113.7:50003')
  $bad = Invoke-WebRequest "$hub/announce/not-the-key?info_hash=$ih&peer_id=x&port=1&left=0" -UseBasicParsing
  Check 'tracker refuses a wrong key' ($bad.Content -match 'failure reason')

  # the pull: B asks for both, A shares them, B downloads
  foreach ($gk in $racer.id, 'sim-hand') { $o = Invoke-As 'B' @('-File', "$scripts\Online-Library.ps1", '-Pull', $gk); Check "B asks for $gk (job made, waiting for A)" (($o -join ' ') -match '"ok":\s*true') ($o -join ' ') }
  $req = Hub-Api 'GET' '/api/requests?branch=SIM-A' $null
  Check 'hub has both requests for A' (@($req.requests | Where-Object { $_.branch -eq 'SIM-B' }).Count -eq 2)
  $o = Invoke-As 'A' @('-File', "$scripts\Online-Library.ps1", '-Sync')
  Check 'A serves them (makes the torrents, shares them)' (($o -join ' ') -match '"served":\s*2') ($o -join ' ')
  $sw = [Diagnostics.Stopwatch]::StartNew(); $jobs = @()
  while ($sw.Elapsed.TotalSeconds -lt 240) {
    Invoke-As 'B' @('-File', "$scripts\Online-Library.ps1", '-Sync') | Out-Null
    $jobs = @([IO.File]::ReadAllText("$T\B\data\jobs.json") | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.key -in $racer.id, 'sim-hand' }
    if (@($jobs | Where-Object { $_.state -notin 'done', 'failed' }).Count -eq 0 -and $jobs.Count -eq 2) { break }
    Start-Sleep -Seconds 2
  }
  Check "B's downloads finished ($(($jobs | ForEach-Object { "$($_.key)=$($_.state)" }) -join ' '), $([int]$sw.Elapsed.TotalSeconds) s, engine $Engine$(if ($ClosedSide -ne 'none') { ", branch $ClosedSide unreachable" }))" (@($jobs | Where-Object { $_.state -eq 'done' }).Count -eq 2) "$(($jobs | ForEach-Object { $_.message }) -join ' | ')"
  $same = $true
  foreach ($pair in @(@("$T\A\GAME\Online\Sim Racer", "$T\B\GAME\Online\Sim Racer"), @("$T\A\drv\Online\Sim Hand", "$T\B\GAME\Online\Sim Hand"))) {
    foreach ($f in Get-ChildItem $pair[0] -Recurse -File) { $other = $pair[1] + $f.FullName.Substring($pair[0].Length); if (-not (Test-Path $other) -or (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $other).Hash) { $same = $false } }
  }
  Check 'every file in B is the same as in A (SHA256)' $same
  $okPieces = $true; $np = 0
  foreach ($j in $jobs) { $tb = [IO.File]::ReadAllBytes("$T\B\data\torrents\$($j.infohash).torrent"); $chk = Test-TorrentData $tb $j.dest; $np += $chk.pieces; if (-not $chk.ok) { $okPieces = $false } }
  Check "B's data passes the torrents' piece check ($np pieces)" $okPieces
  $tb = [IO.File]::ReadAllBytes("$T\B\data\torrents\$($jobs[0].infohash).torrent")
  $other = Set-TorrentAnnounce $tb 'http://other-hub.example:4667/announce/k' $jobs[0].infohash
  Check "B's torrent announces to B's own hub address; another tracker keeps the info hash" ((Get-BStr (ConvertFrom-Bencode $tb)['announce']) -like "$hub/announce/*" -and (Get-BStr (ConvertFrom-Bencode $other)['announce']) -like 'http://other-hub.example*' -and (Get-TorrentInfoHash $other) -eq $jobs[0].infohash)

  Invoke-As 'B' @('-File', "$scripts\Master-GameList.ps1") | Out-Null
  Check "B's menu now has Sim Racer and Sim Hand" ([bool](Get-Games 'B' | Where-Object { $_.cmd -like '*Sim Racer*' }) -and [bool](Get-Games 'B' | Where-Object { $_.cmd -like '*Sim Hand*' }))
  Invoke-As 'B' @('-File', "$scripts\Online-Library.ps1", '-Publish') | Out-Null
  $v2 = Get-View 'B'
  Check "B's 'missing here' no longer lists Sim Racer / Sim Hand (left: $(@($v2.missing | ForEach-Object { $_.key }) -join ', '))" (-not @($v2.missing | Where-Object { $_.key -in $racer.id, 'sim-hand' }).Count)

  if ($Upnp) {
    $st = Get-Igd; $m = @($st.maps)
    $ma = @($m | Where-Object { $_.port -eq 6991 })[0]; $mb = @($m | Where-Object { $_.port -eq 6992 })[0]
    Check "UPnP: A's and B's aria2 ports are mapped to this PC ($(($m | ForEach-Object { "$($_.port)->$($_.client) $($_.desc)" }) -join '; '))" ($ma.client -eq '127.0.0.1' -and $ma.desc -like 'OSYNC aria2*' -and $mb.client -eq '127.0.0.1' -and $ma.lease -gt 0)
    Check "UPnP: aria2 tells the tracker the router's public IP ($(Get-Content "$T\A\data\aria2.extip" -Raw))" ("$(Get-Content "$T\A\data\aria2.extip" -Raw)".Trim() -eq $(if ($ClosedSide -eq 'A') { '127.0.0.2' } else { '127.0.0.1' }))
    Check "UPnP: the hub's port $HubPort is mapped and renewed ($($st.adds) AddPortMapping calls)" (@($m | Where-Object { $_.port -eq $HubPort -and $_.desc -eq 'OSYNC hub' }).Count -eq 1 -and $st.adds -ge 4)
    $o = Invoke-As 'A' @('-Command', ". '$scripts\Online-Upnp.ps1'; try { Add-UpnpMapping 6993 'OSYNC test' 60 | Out-Null; 'took it' } catch { 'refused: ' + `$_.Exception.Message }; 'remove: ' + (Remove-UpnpMapping 6993)")
    Check "UPnP: a port mapped to another host is neither taken nor removed ($($o -join ' / '))" (($o -join ' ') -match 'refused: .*already mapped' -and ($o -join ' ') -match 'remove: left alone' -and @((Get-Igd).maps | Where-Object { $_.port -eq 6993 -and $_.client -eq '10.0.0.9' }).Count -eq 1)
    $o = Invoke-As 'A' @('-File', "$scripts\Online-Library.ps1", '-Stop')
    $m2 = @((Get-Igd).maps)
    Check "UPnP: -Stop ends A's aria2 and removes ONLY A's mapping ($($o -join ' ' -replace '\s+', ' '))" (-not @($m2 | Where-Object { $_.port -eq 6991 }).Count -and @($m2 | Where-Object { $_.port -eq 6992 }).Count -eq 1)
  }
  Check 'the real game list was not changed' (-not (@([IO.File]::ReadAllText((Join-Path $Menu 'data\games.json')) | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_.cmd -like '*Sim Racer*' }))
} catch { Check 'simulation run' $false "$($_.Exception.Message) $($_.InvocationInfo.PositionMessage)" }
finally {
  try { Hub-Api 'POST' '/api/_stop' @{} | Out-Null } catch { }
  Start-Sleep -Milliseconds 800; if (-not $hubProc.HasExited) { Stop-Process -Id $hubProc.Id -Force -ErrorAction SilentlyContinue }
  if ($Upnp) {
    try { Check "UPnP: the hub removed its mapping when it stopped" (-not @((Get-Igd).maps | Where-Object { $_.port -eq $HubPort }).Count) } catch { Check 'UPnP: hub mapping check' $false "$($_.Exception.Message)" }
    try { Invoke-RestMethod "http://127.0.0.1:$igdPort/_stop" -Method POST -UseBasicParsing | Out-Null } catch { }
    Start-Sleep -Milliseconds 300; if ($igdProc -and -not $igdProc.HasExited) { Stop-Process -Id $igdProc.Id -Force -ErrorAction SilentlyContinue }
  }
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^aria2c' -and "$($_.CommandLine)" -like "*$T*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  if (-not $Keep) { Start-Sleep -Milliseconds 500; Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host ("online library simulation ({0}{1}{2}): {3} passed, {4} failed{5}" -f $Engine, $(if ($ClosedSide -ne 'none') { ", $ClosedSide closed" } else { '' }), $(if ($Upnp) { ', UPnP' } else { '' }), $passes, $fails, $(if ($Keep) { " (kept $T)" } else { '' })) -ForegroundColor $(if ($fails) { 'Red' } else { 'Green' })
if ($fails) { exit 1 }
exit 0
