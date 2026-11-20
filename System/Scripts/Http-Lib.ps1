# Http-Lib.ps1 - a small HTTP/1.1 server on a TCP socket for the OSYNC admin console and the game hub (dot-sourced).
# A plain TcpListener needs no URL reservation and no administrator. One request at a time, Connection: close.
#   Start-HttpServer -Port 4666 -Bind 127.0.0.1 -Handler { param($req) ... return (New-JsonResponse $obj) }
# $req: Method, Path (decoded, no query), RawQuery, Query (name -> decoded string), Headers (lower-case names), Body (byte[]),
#       Remote (client IP), BodyText (UTF-8). A handler returns @{ Status; Type; Body (byte[] | string); Headers }.

$script:HttpMaxBody = 32MB

function ConvertFrom-UrlBytes([string]$s) {
  # percent-decoding to raw bytes (BitTorrent info_hash / peer_id are binary)
  $ms = New-Object IO.MemoryStream
  for ($i = 0; $i -lt $s.Length; $i++) {
    $ch = $s[$i]
    if ($ch -eq '%' -and $i + 2 -le $s.Length - 1) { $ms.WriteByte([Convert]::ToByte($s.Substring($i + 1, 2), 16)); $i += 2 }
    elseif ($ch -eq '+') { $ms.WriteByte(32) }
    else { $b = [Text.Encoding]::UTF8.GetBytes([string]$ch); $ms.Write($b, 0, $b.Length) }
  }
  , $ms.ToArray()
}
function ConvertFrom-UrlString([string]$s) { [Text.Encoding]::UTF8.GetString((ConvertFrom-UrlBytes $s)) }

function Read-HttpRequest([IO.Stream]$s, [string]$remote) {
  $buf = New-Object byte[] 8192
  $head = New-Object IO.MemoryStream
  $end = -1
  while ($end -lt 0) {
    $n = $s.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $head.Write($buf, 0, $n)
    $arr = $head.ToArray()
    for ($i = [Math]::Max(0, $arr.Length - $n - 3); $i -le $arr.Length - 4; $i++) {
      if ($arr[$i] -eq 13 -and $arr[$i + 1] -eq 10 -and $arr[$i + 2] -eq 13 -and $arr[$i + 3] -eq 10) { $end = $i; break }
    }
    if ($end -lt 0 -and $head.Length -gt 65536) { return $null }
  }
  $arr = $head.ToArray()
  $lines = [Text.Encoding]::ASCII.GetString($arr, 0, $end) -split "`r`n"
  $first = $lines[0] -split ' '
  if ($first.Count -lt 2) { return $null }
  $headers = @{}
  foreach ($l in $lines[1..($lines.Count - 1)]) { $p = $l.IndexOf(':'); if ($p -gt 0) { $headers[$l.Substring(0, $p).Trim().ToLower()] = $l.Substring($p + 1).Trim() } }
  $len = 0; if ($headers['content-length']) { $len = [int64]$headers['content-length'] }
  if ($len -gt $script:HttpMaxBody) { return @{ TooBig = $true; Method = $first[0]; Path = '/'; Headers = $headers } }
  $body = New-Object byte[] $len
  $have = $arr.Length - ($end + 4)
  if ($have -gt 0) { [Array]::Copy($arr, $end + 4, $body, 0, [Math]::Min($have, $len)) }
  $got = [Math]::Min($have, $len)
  while ($got -lt $len) { $n = $s.Read($body, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
  $target = $first[1]
  $q = ''; $path = $target
  $qi = $target.IndexOf('?'); if ($qi -ge 0) { $path = $target.Substring(0, $qi); $q = $target.Substring($qi + 1) }
  $query = @{}
  foreach ($pair in ($q -split '&')) { if (-not $pair) { continue }; $kv = $pair -split '=', 2; $query[(ConvertFrom-UrlString $kv[0])] = $(if ($kv.Count -gt 1) { ConvertFrom-UrlString $kv[1] } else { '' }) }
  @{ Method = $first[0].ToUpper(); Path = (ConvertFrom-UrlString $path); RawPath = $path; RawQuery = $q; Query = $query; Headers = $headers; Body = $body
     BodyText = [Text.Encoding]::UTF8.GetString($body); Remote = $remote }
}

$script:HttpStatusText = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 405 = 'Method Not Allowed'; 409 = 'Conflict'; 413 = 'Payload Too Large'; 500 = 'Internal Server Error' }
function Write-HttpResponse([IO.Stream]$s, $res) {
  $status = if ($res.Status) { [int]$res.Status } else { 200 }
  $body = $res.Body
  if ($null -eq $body) { $body = New-Object byte[] 0 } elseif ($body -is [string]) { $body = [Text.Encoding]::UTF8.GetBytes($body) }
  $type = if ($res.Type) { $res.Type } else { 'application/octet-stream' }
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("HTTP/1.1 $status $($script:HttpStatusText[$status])`r`n")
  [void]$sb.Append("Content-Type: $type`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`n")
  if ($res.Headers) { foreach ($k in $res.Headers.Keys) { [void]$sb.Append("${k}: $($res.Headers[$k])`r`n") } }
  [void]$sb.Append("`r`n")
  $h = [Text.Encoding]::ASCII.GetBytes($sb.ToString())
  $s.Write($h, 0, $h.Length)
  if ($body.Length) { $s.Write($body, 0, $body.Length) }
  $s.Flush()
}

function New-JsonResponse($obj, [int]$Status = 200) {
  @{ Status = $Status; Type = 'application/json; charset=utf-8'; Body = (ConvertTo-Json -InputObject $obj -Depth 12 -Compress) }
}
function New-ErrorResponse([int]$Status, [string]$Message) { New-JsonResponse @{ ok = $false; error = $Message } $Status }
function Get-JsonBody($req) { if (-not $req.BodyText.Trim()) { return $null }; $req.BodyText | ConvertFrom-Json }

$script:MimeTypes = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'; '.gif' = 'image/gif'; '.ico' = 'image/x-icon'; '.svg' = 'image/svg+xml'; '.torrent' = 'application/x-bittorrent' }
function New-FileResponse([string]$file) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return (New-ErrorResponse 404 'not found') }
  $ext = [IO.Path]::GetExtension($file).ToLower()
  @{ Status = 200; Type = $(if ($script:MimeTypes[$ext]) { $script:MimeTypes[$ext] } else { 'application/octet-stream' }); Body = [IO.File]::ReadAllBytes($file) }
}

function Write-HttpLog([string]$m) { if ($env:OSYNC_HTTP_LOG) { try { Add-Content -LiteralPath $env:OSYNC_HTTP_LOG -Value ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $m) } catch { } } }
# serve until the handler returns @{ Stop = $true } (tests) or the process ends
# -OnIdle { ... } -IdleSeconds 300: also run that block about every IdleSeconds between requests (the hub renews its UPnP mapping)
function Start-HttpServer([int]$Port, [string]$Bind = '127.0.0.1', [scriptblock]$Handler, [string]$Name = 'http', [scriptblock]$OnIdle = $null, [int]$IdleSeconds = 300) {
  $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Parse($Bind), $Port)
  $listener.Start()
  Write-Host "$Name listening on http://${Bind}:$Port/"
  $idleAt = [DateTime]::UtcNow.AddSeconds($IdleSeconds)
  try {
    while ($true) {
      if ($OnIdle) {
        while (-not $listener.Pending()) {
          Start-Sleep -Milliseconds 100
          if ([DateTime]::UtcNow -ge $idleAt) { $idleAt = [DateTime]::UtcNow.AddSeconds($IdleSeconds); try { & $OnIdle } catch { Write-HttpLog "  idle: $($_.Exception.Message)" } }
        }
      }
      $client = $listener.AcceptTcpClient()
      $stop = $false
      try {
        $client.ReceiveTimeout = 20000; $client.SendTimeout = 20000
        $stream = $client.GetStream()
        $remote = ([Net.IPEndPoint]$client.Client.RemoteEndPoint).Address.ToString()
        $req = Read-HttpRequest $stream $remote
        if ($req) {
          Write-HttpLog "$($req.Method) $($req.RawPath)"
          if ($req.TooBig) { $res = New-ErrorResponse 413 'request too big' }
          else { try { $res = & $Handler $req } catch { $res = New-ErrorResponse 500 "$($_.Exception.Message)" } }
          if ($res -is [array]) { $res = $res[-1] }
          Write-HttpResponse $stream $res
          Write-HttpLog "  -> $($res.Status)"
          if ($res.Stop) { $stop = $true }
        }
      } catch { Write-HttpLog "  error: $($_.Exception.Message)" } finally { $client.Close() }
      if ($stop) { break }
    }
  } finally { $listener.Stop() }
}
