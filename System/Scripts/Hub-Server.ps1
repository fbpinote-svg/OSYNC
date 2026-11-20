# Hub-Server.ps1 - the online library hub: which branch has which game + a private BitTorrent tracker. One master hosts it
# (or, later, the web as a patch - the protocol below is plain HTTP + JSON so it can move there as it is).
#   POST /api/report    {branch, name, games:[{key,title,cat,kind,rel,size,files}]}  a branch's game list (replaces the old one)
#   GET  /api/catalog                                     every branch with its games (+ lastSeen, ip)
#   POST /api/request   {branch, from, key}               branch <branch> wants game <key> from branch <from>
#   GET  /api/requests?branch=<b>                         requests waiting for branch <b> (the one that has the game)
#   POST /api/torrent   {from, key, infohash, torrent (base64), source}   the seeding branch's .torrent for a game
#   GET  /api/torrent?from=<b>&key=<k>                    that .torrent (404 until the seeder made it)
#   GET  /announce/<key>?info_hash=..&peer_id=..&port=..&left=..&event=..   tracker (compact peers only)
# Every /api call needs the header X-Hub-Key (Settings OnlineKey / -Key); the tracker has the key in its path.
# Branches are told apart by the name they report + the public IP the hub sees. Data: -HubDir (default System\Data\Hub).
#   -Port 4667  -Bind 0.0.0.0 (other branches reach it over the internet) or 127.0.0.1 (tests)
#   Settings OnlineUpnp=on (and -Bind not 127.x): the router maps -Port to this PC over UPnP while the hub runs - no port
#   forward by hand; renewed every 5 min (lease 1 h), removed when the hub stops (a killed hub's lease runs out by itself)
#   -Register: start at logon (task OSYNC-Hub, this user, hidden, not elevated) + now   -Unregister: remove the task
#   -AllowStop: POST /api/_stop ends it (tests)
param([int]$Port = 4667, [string]$Bind = '0.0.0.0', [string]$Key = '', [string]$HubDir = '', [switch]$AllowStop, [switch]$Register, [switch]$Unregister, [int]$UpnpRenewSec = 300)
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Http-Lib.ps1')
. (Join-Path $PSScriptRoot 'Online-Torrent.ps1')
. (Join-Path $PSScriptRoot 'Online-Upnp.ps1')
if ($Register -or $Unregister) {
  $tn = 'OSYNC-Hub'
  Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue
  if ($Unregister) { Write-Host "task $tn removed (stop a running hub: end its powershell.exe or log off)"; exit 0 }
  if (-not (Get-OnlineSecret)) { Write-Host 'Hub: no key - put it in System\Data\Online\online.key first' -ForegroundColor Red; exit 1 }
  $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '" -Port ' + $Port)
  $t = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $tn -Action $a -Trigger $t -Principal $p -Settings $s -Description "OSYNC online library hub, port $Port" -Force | Out-Null
  Start-ScheduledTask -TaskName $tn
  Write-Host "task ${tn}: at logon -> hub on port $Port$(if ((Get-Setting 'OnlineUpnp' 'off') -match '^(on|1|true|yes)$') { ' (UPnP mapping on)' })"
  exit 0
}
if (-not $Key) { $Key = Get-OnlineSecret }
if (-not $Key -or $Key.Length -lt 12) { Write-Host 'Hub: needs a key of 12+ characters (-Key or System\Data\Online\online.key)' -ForegroundColor Red; exit 1 }
$HubData = if ($HubDir) { $HubDir } elseif (Get-Setting 'OnlineData' '') { Join-Path (Get-Setting 'OnlineData' '') 'Hub' } else { Join-Path (Join-Path $SystemDir 'Data') 'Hub' }   # OnlineData: off the shared drives
foreach ($d in $HubData, (Join-Path $HubData 'branches'), (Join-Path $HubData 'torrents')) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

function Get-SafeName([string]$s) { if ($s -notmatch '^[A-Za-z0-9._\-]{1,64}$') { throw "bad name: $s" }; $s }
function Read-Json([string]$f) { if (Test-Path -LiteralPath $f) { [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json } else { $null } }
function Write-Json([string]$f, $o) { [IO.File]::WriteAllText($f, (ConvertTo-Json -InputObject $o -Depth 10), (New-Object Text.UTF8Encoding($false))) }
$reqFile = Join-Path $HubData 'requests.json'
$torIndex = Join-Path $HubData 'torrents.json'
function Get-Requests { $r = Read-Json $reqFile; if ($r) { @($r) } else { @() } }
function Get-TorIndex { $r = Read-Json $torIndex; if ($r) { @($r) } else { @() } }

# tracker: info_hash hex -> peer_id hex -> @{ ip; port; left; seen }
$script:Swarms = @{}
function Get-Announce($req, [string]$pathKey) {
  if ($pathKey -ne $Key) { return @{ Status = 200; Type = 'text/plain'; Body = (ConvertTo-Bencode ([ordered]@{ 'failure reason' = 'unknown key' })) } }
  $raw = @{}; foreach ($pair in ($req.RawQuery -split '&')) { $kv = $pair -split '=', 2; if ($kv.Count -eq 2) { $raw[$kv[0]] = $kv[1] } }
  $ih = [BitConverter]::ToString((ConvertFrom-UrlBytes "$($raw['info_hash'])")).Replace('-', '').ToLower()
  $peer = [BitConverter]::ToString((ConvertFrom-UrlBytes "$($raw['peer_id'])")).Replace('-', '').ToLower()
  $port = [int]"0$($req.Query['port'])"
  if ($ih.Length -ne 40 -or -not $peer -or $port -le 0) { return @{ Status = 200; Type = 'text/plain'; Body = (ConvertTo-Bencode ([ordered]@{ 'failure reason' = 'bad announce' })) } }
  $ip = if ($req.Query['ip'] -match '^\d{1,3}(\.\d{1,3}){3}$') { $req.Query['ip'] } else { $req.Remote }
  if (-not $script:Swarms[$ih]) { $script:Swarms[$ih] = @{} }
  $sw = $script:Swarms[$ih]
  if ($req.Query['event'] -eq 'stopped') { $sw.Remove($peer) } else { $sw[$peer] = @{ ip = $ip; port = $port; left = [int64]"0$($req.Query['left'])"; seen = [DateTime]::UtcNow } }
  foreach ($k in @($sw.Keys)) { if (([DateTime]::UtcNow - $sw[$k].seen).TotalMinutes -gt 30) { $sw.Remove($k) } }
  $ms = New-Object IO.MemoryStream
  foreach ($k in $sw.Keys) {
    if ($k -eq $peer) { continue }
    $p = $sw[$k]; $ipb = ([Net.IPAddress]::Parse($p.ip)).GetAddressBytes()
    if ($ipb.Length -ne 4) { continue }
    $ms.Write($ipb, 0, 4); $ms.WriteByte([byte](($p.port -shr 8) -band 255)); $ms.WriteByte([byte]($p.port -band 255))
  }
  $seeders = @($sw.Values | Where-Object { $_.left -eq 0 }).Count
  $res = [ordered]@{ complete = $seeders; incomplete = ($sw.Count - $seeders); interval = 60; 'min interval' = 20; peers = $ms.ToArray() }
  @{ Status = 200; Type = 'text/plain'; Body = (ConvertTo-Bencode $res) }
}

$handler = {
  param($req)
  $p = $req.Path
  if ($req.RawPath -match '^/announce/([^/?]+)$') { return (Get-Announce $req (ConvertFrom-UrlString $Matches[1])) }
  if ($p -eq '/api/_stop' -and $AllowStop -and $req.Method -eq 'POST' -and $req.Headers['x-hub-key'] -eq $Key) { $r = New-JsonResponse @{ ok = $true }; $r.Stop = $true; return $r }
  if ($p -notlike '/api/*') { return (New-ErrorResponse 404 'not found') }
  if ($req.Headers['x-hub-key'] -ne $Key) { return (New-ErrorResponse 403 'bad hub key') }
  try {
    switch -Regex ($p) {
      '^/api/report$' {
        $b = Get-JsonBody $req; $br = Get-SafeName "$($b.branch)"
        $games = @($b.games | Where-Object { $_.key } | ForEach-Object { [ordered]@{ key = "$($_.key)"; title = "$($_.title)"; cat = "$($_.cat)"; kind = "$($_.kind)"; rel = "$($_.rel)"; size = [int64]"0$($_.size)"; files = [int]"0$($_.files)" } })
        Write-Json (Join-Path $HubData "branches\$br.json") ([ordered]@{ branch = $br; name = "$($b.name)"; ip = $req.Remote; lastSeen = [DateTime]::UtcNow.ToString('o'); games = $games })
        return (New-JsonResponse @{ ok = $true; games = $games.Count })
      }
      '^/api/catalog$' {
        $all = @(Get-ChildItem -LiteralPath (Join-Path $HubData 'branches') -Filter *.json -File | ForEach-Object { Read-Json $_.FullName })
        return (New-JsonResponse @{ ok = $true; branches = $all })
      }
      '^/api/request$' {
        $b = Get-JsonBody $req; $br = Get-SafeName "$($b.branch)"; $from = Get-SafeName "$($b.from)"; $k = Get-SafeName "$($b.key)"
        $list = @(Get-Requests | Where-Object { -not ($_.branch -eq $br -and $_.from -eq $from -and $_.key -eq $k) })
        $list += [ordered]@{ branch = $br; from = $from; key = $k; at = [DateTime]::UtcNow.ToString('o') }
        Write-Json $reqFile $list
        $have = Get-TorIndex | Where-Object { $_.from -eq $from -and $_.key -eq $k } | Select-Object -First 1
        return (New-JsonResponse @{ ok = $true; torrentReady = [bool]$have })
      }
      '^/api/requests$' {
        $br = Get-SafeName "$($req.Query['branch'])"
        return (New-JsonResponse @{ ok = $true; requests = @(Get-Requests | Where-Object { $_.from -eq $br }) })
      }
      '^/api/torrent$' {
        if ($req.Method -eq 'POST') {
          $b = Get-JsonBody $req; $from = Get-SafeName "$($b.from)"; $k = Get-SafeName "$($b.key)"
          $ih = "$($b.infohash)".ToLower(); if ($ih -notmatch '^[0-9a-f]{40}$') { throw 'bad infohash' }
          $bytes = [Convert]::FromBase64String("$($b.torrent)")
          [IO.File]::WriteAllBytes((Join-Path $HubData "torrents\$ih.torrent"), $bytes)
          if ($b.manifest) { [IO.File]::WriteAllBytes((Join-Path $HubData "torrents\$ih.acf"), [Convert]::FromBase64String("$($b.manifest)")) }
          $idx = @(Get-TorIndex | Where-Object { -not ($_.from -eq $from -and $_.key -eq $k) })
          $idx += [ordered]@{ from = $from; key = $k; infohash = $ih; source = "$($b.source)"; size = [int64]"0$($b.size)"; at = [DateTime]::UtcNow.ToString('o') }
          Write-Json $torIndex $idx
          Write-Json $reqFile @(Get-Requests | Where-Object { -not ($_.from -eq $from -and $_.key -eq $k) })   # served
          return (New-JsonResponse @{ ok = $true })
        }
        $from = Get-SafeName "$($req.Query['from'])"; $k = Get-SafeName "$($req.Query['key'])"
        $e = Get-TorIndex | Where-Object { $_.from -eq $from -and $_.key -eq $k } | Select-Object -First 1
        if (-not $e) { return (New-JsonResponse @{ ok = $false; ready = $false } 404) }
        $tf = Join-Path $HubData "torrents\$($e.infohash).torrent"
        $af = Join-Path $HubData "torrents\$($e.infohash).acf"
        return (New-JsonResponse @{ ok = $true; ready = $true; infohash = $e.infohash; source = $e.source; size = $e.size; torrent = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tf))
            manifest = $(if (Test-Path -LiteralPath $af) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($af)) } else { '' }) })
      }
      default { return (New-ErrorResponse 404 'not found') }
    }
  } catch { return (New-ErrorResponse 400 "$($_.Exception.Message)") }
}

$script:HttpMaxBody = 16MB
$mutex = New-Object Threading.Mutex($false, "Local\OSYNC-Hub-$Port")
if (-not $mutex.WaitOne(0)) { Write-Host "the hub already runs on port $Port"; exit 0 }
$upnpOn = ((Get-Setting 'OnlineUpnp' 'off') -match '^(on|1|true|yes)$') -and ($Bind -notmatch '^127\.' -or $env:OSYNC_UPNP_LOCATION)   # 127.x + fake router: tests
$upnpLog = Join-Path $HubData 'hub.log'
function Write-HubLog([string]$m) { try { Add-Content -LiteralPath $upnpLog -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $m) -Encoding UTF8 } catch { } }
$renew = { try { $m = Add-UpnpMapping $Port "OSYNC hub" 3600 'TCP'; Write-HubLog "UPnP: $($m.ExternalIP):$Port -> $($m.LocalIP):$Port" } catch { Write-HubLog "UPnP mapping failed: $($_.Exception.Message)" } }
Write-HubLog "hub started on ${Bind}:$Port$(if ($upnpOn) { ' (UPnP on)' })"
try {
  if ($upnpOn) { & $renew; Start-HttpServer -Port $Port -Bind $Bind -Handler $handler -Name 'OSYNC online hub' -OnIdle $renew -IdleSeconds $UpnpRenewSec }
  else { Start-HttpServer -Port $Port -Bind $Bind -Handler $handler -Name 'OSYNC online hub' }
} finally {
  if ($upnpOn) { try { Write-HubLog "stopped, UPnP: $(Remove-UpnpMapping $Port 'TCP')" } catch { Write-HubLog "stopped, UPnP remove failed: $($_.Exception.Message)" } } else { Write-HubLog 'stopped' }
}
