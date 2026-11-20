# Online-Upnp.ps1 - MASTER: asks the shop router (UPnP IGD, e.g. OPNsense miniupnpd) for a port mapping so other branches can
# reach this PC's BitTorrent port (aria2) / the online-library hub WITHOUT a port forward made by hand. aria2 has no UPnP or
# NAT-PMP of its own, so OSYNC does it: Online-Library.ps1 maps OnlineBtPort while aria2 runs, Hub-Server.ps1 maps its port
# while the hub runs; both renew the lease and remove THEIR OWN mapping when they stop (an unrenewed lease expires anyway).
# Off unless Settings OnlineUpnp=on. Dot-sourced by Online-Library.ps1 / Hub-Server.ps1 (functions only).
# Every request goes out FROM the local IP the mapping is for (a router in "secure mode" only maps to the asking host's own IP).
# That IP: Settings OnlineBind, else the address Windows uses towards the internet (the NIC with the default route) - an
# inbound connection to another NIC of a multi-NIC master could not be answered (Windows strong-host model).
#   Online-Upnp.ps1 -Status            read only: router, external IP, this PC's local IP, every mapping on the router
#   Online-Upnp.ps1 -Map <port> [-Description x] [-LeaseSec 3600]   /   -Unmap <port>     (TCP; -Unmap removes only an OSYNC mapping to this PC)
param([switch]$Status, [int]$Map = 0, [int]$Unmap = 0, [string]$Description = 'OSYNC', [int]$LeaseSec = 3600)
if (-not (Get-Command Get-Setting -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Common.ps1') }

$script:UpnpIgd = $null; $script:UpnpIgdAt = [DateTime]::MinValue

function Test-PrivateIPv4([string]$ip) {
  $ip -match '^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.|0\.)'   # incl. CGNAT 100.64/10
}
# the local IPv4 to use: Settings OnlineBind (not 127.x), else the source address of the route to the internet
function Get-UpnpLocalIP {
  $b = Get-Setting 'OnlineBind' ''
  if ($b -match '^\d{1,3}(\.\d{1,3}){3}$' -and ($b -notmatch '^127\.' -or $env:OSYNC_UPNP_LOCATION)) { return $b }   # 127.x: tests only
  try { $r = @(Find-NetRoute -RemoteIPAddress '1.1.1.1' -ErrorAction Stop | Where-Object { $_.IPAddress -match '^\d{1,3}(\.\d{1,3}){3}$' })[0]; if ($r) { return [string]$r.IPAddress } } catch { }
  Get-LanIP
}

# minimal HTTP/1.1 over a TCP socket bound to $LocalIP (so the router sees that address) -> @{ Status; Body }
function Invoke-UpnpHttp([string]$Url, [string]$LocalIP, [string]$Method = 'GET', [string]$Body = '', [hashtable]$Headers = @{}, [int]$TimeoutMs = 4000) {
  $u = [uri]$Url
  $c = New-Object Net.Sockets.TcpClient([Net.Sockets.AddressFamily]::InterNetwork)
  try {
    if ($LocalIP) { $c.Client.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Parse($LocalIP), 0))) }
    $ar = $c.BeginConnect($u.Host, $u.Port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw "no answer from $($u.Host):$($u.Port)" }
    $c.EndConnect($ar)
    $c.ReceiveTimeout = $TimeoutMs; $c.SendTimeout = $TimeoutMs
    $s = $c.GetStream()
    $bb = [Text.Encoding]::UTF8.GetBytes($Body)
    $h = "$Method $($u.PathAndQuery) HTTP/1.1`r`nHost: $($u.Host):$($u.Port)`r`nConnection: close`r`nContent-Length: $($bb.Length)`r`n"
    foreach ($k in $Headers.Keys) { $h += "${k}: $($Headers[$k])`r`n" }
    $hb = [Text.Encoding]::ASCII.GetBytes($h + "`r`n")
    $s.Write($hb, 0, $hb.Length); if ($bb.Length) { $s.Write($bb, 0, $bb.Length) }
    $ms = New-Object IO.MemoryStream; $buf = New-Object byte[] 8192
    while ($true) { try { $n = $s.Read($buf, 0, $buf.Length) } catch { break }; if ($n -le 0) { break }; $ms.Write($buf, 0, $n) }
    $txt = [Text.Encoding]::UTF8.GetString($ms.ToArray())
    $i = $txt.IndexOf("`r`n`r`n"); if ($i -lt 0) { throw "bad HTTP answer from $($u.Host)" }
    $head = $txt.Substring(0, $i); $rest = $txt.Substring($i + 4)
    if ($head -match '(?im)^transfer-encoding:\s*chunked') {   # de-chunk
      $out = New-Object Text.StringBuilder; $p = 0
      while ($p -lt $rest.Length) { $e = $rest.IndexOf("`r`n", $p); if ($e -lt 0) { break }; $len = [Convert]::ToInt32(($rest.Substring($p, $e - $p) -split ';')[0].Trim(), 16); if ($len -le 0) { break }; [void]$out.Append($rest.Substring($e + 2, [Math]::Min($len, $rest.Length - $e - 2))); $p = $e + 2 + $len + 2 }
      $rest = $out.ToString()
    }
    @{ Status = [int](($head -split ' ')[1]); Body = $rest }
  } finally { $c.Close() }
}

# SSDP search (multicast + unicast to the default gateways) from $LocalIP -> the first IGD with a WANIP/WANPPP connection service
# (kept 10 min). $env:OSYNC_UPNP_LOCATION = a description URL to use without SSDP (tests: a fake router on 127.0.0.1).
function Find-UpnpIgd([string]$LocalIP = '', [int]$WaitMs = 2500, [switch]$Fresh) {
  if (-not $LocalIP) { $LocalIP = Get-UpnpLocalIP }
  if ($script:UpnpIgd -and -not $Fresh -and $script:UpnpIgd.LocalIP -eq $LocalIP -and ([DateTime]::UtcNow - $script:UpnpIgdAt).TotalMinutes -lt 10) { return $script:UpnpIgd }
  $u = New-Object Net.Sockets.UdpClient([Net.Sockets.AddressFamily]::InterNetwork)
  $locs = New-Object System.Collections.Generic.List[string]
  if ($env:OSYNC_UPNP_LOCATION) { $locs.Add($env:OSYNC_UPNP_LOCATION); $WaitMs = 0 }
  try {
    $u.Client.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Parse($LocalIP), 0)))
    try { $u.Client.SetSocketOption([Net.Sockets.SocketOptionLevel]::IP, [Net.Sockets.SocketOptionName]::MulticastInterface, ([Net.IPAddress]::Parse($LocalIP)).GetAddressBytes()) } catch { }
    $targets = @('239.255.255.250') + @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object { "$($_.NextHop)" } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -ne '0.0.0.0' })
    foreach ($st in 'urn:schemas-upnp-org:device:InternetGatewayDevice:1', 'urn:schemas-upnp-org:service:WANIPConnection:1', 'urn:schemas-upnp-org:service:WANPPPConnection:1') {
      $msg = [Text.Encoding]::ASCII.GetBytes("M-SEARCH * HTTP/1.1`r`nHOST: 239.255.255.250:1900`r`nMAN: `"ssdp:discover`"`r`nMX: 2`r`nST: $st`r`n`r`n")
      foreach ($t in $targets) { try { [void]$u.Send($msg, $msg.Length, (New-Object Net.IPEndPoint([Net.IPAddress]::Parse($t), 1900))) } catch { } }
    }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $WaitMs) {
      if ($u.Available -le 0) { Start-Sleep -Milliseconds 50; continue }
      $from = New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0)
      $txt = [Text.Encoding]::ASCII.GetString($u.Receive([ref]$from))
      $m = [regex]::Match($txt, '(?im)^location:\s*(\S+)')
      if ($m.Success -and -not $locs.Contains($m.Groups[1].Value)) { $locs.Add($m.Groups[1].Value) }
    }
  } finally { $u.Close() }
  foreach ($loc in $locs) {
    try {
      $d = Invoke-UpnpHttp $loc $LocalIP
      if ($d.Status -ne 200) { continue }
      $x = [xml]$d.Body
      $base = "$($x.SelectSingleNode("//*[local-name()='URLBase']").InnerText)".Trim()
      if (-not $base) { $lu = [uri]$loc; $base = "$($lu.Scheme)://$($lu.Host):$($lu.Port)/" }
      foreach ($want in 'WANIPConnection:2', 'WANIPConnection:1', 'WANPPPConnection:1') {
        foreach ($sv in $x.SelectNodes("//*[local-name()='service']")) {
          $type = "$($sv.SelectSingleNode("*[local-name()='serviceType']").InnerText)".Trim()
          if ($type -ne "urn:schemas-upnp-org:service:$want") { continue }
          $ctl = "$($sv.SelectSingleNode("*[local-name()='controlURL']").InnerText)".Trim()
          $script:UpnpIgd = [pscustomobject]@{ Location = $loc; ServiceType = $type; ControlUrl = ([uri]::new([uri]$base, $ctl)).AbsoluteUri; LocalIP = $LocalIP; Router = ([uri]$loc).Host }
          $script:UpnpIgdAt = [DateTime]::UtcNow
          return $script:UpnpIgd
        }
      }
    } catch { }
  }
  throw "no UPnP router answered from $LocalIP (is UPnP on in the router, for this LAN?)"
}

# one SOAP action -> hashtable of the answer's fields; a UPnP error throws "UPnP <action>: <code> <description>"
function Invoke-UpnpAction($Igd, [string]$Action, [Collections.Specialized.OrderedDictionary]$Arguments = $null) {
  $a = ''; if ($Arguments) { foreach ($k in $Arguments.Keys) { $a += "<$k>$([Security.SecurityElement]::Escape([string]$Arguments[$k]))</$k>" } }
  $body = '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>' +
          "<u:$Action xmlns:u=`"$($Igd.ServiceType)`">$a</u:$Action></s:Body></s:Envelope>"
  $r = Invoke-UpnpHttp $Igd.ControlUrl $Igd.LocalIP 'POST' $body @{ 'Content-Type' = 'text/xml; charset="utf-8"'; 'SOAPAction' = "`"$($Igd.ServiceType)#$Action`"" }
  $out = @{}
  try { $x = [xml]$r.Body } catch { throw "UPnP ${Action}: HTTP $($r.Status), not XML" }
  if ($r.Status -ne 200) {
    $code = "$($x.SelectSingleNode("//*[local-name()='errorCode']").InnerText)"; $desc = "$($x.SelectSingleNode("//*[local-name()='errorDescription']").InnerText)"
    $e = New-Object Exception("UPnP ${Action}: $code $desc"); $e.Data['code'] = $code; throw $e
  }
  $resp = $x.SelectSingleNode("//*[local-name()='${Action}Response']")
  if ($resp) { foreach ($n in $resp.ChildNodes) { $out[$n.LocalName] = $n.InnerText } }
  $out
}
function Get-UpnpExternalIP($Igd) { "$((Invoke-UpnpAction $Igd 'GetExternalIPAddress').NewExternalIPAddress)".Trim() }
function Get-UpnpMappings($Igd, [int]$Max = 256) {
  for ($i = 0; $i -lt $Max; $i++) {
    try { $m = Invoke-UpnpAction $Igd 'GetGenericPortMappingEntry' ([ordered]@{ NewPortMappingIndex = $i }) } catch { break }   # 713 = end of the list
    [pscustomobject]@{ ExternalPort = [int]$m.NewExternalPort; Protocol = $m.NewProtocol; InternalClient = $m.NewInternalClient; InternalPort = [int]$m.NewInternalPort
      Description = $m.NewPortMappingDescription; Enabled = $m.NewEnabled; LeaseSec = [int]"0$($m.NewLeaseDuration)"; RemoteHost = $m.NewRemoteHost }
  }
}
function Get-UpnpMapping($Igd, [int]$Port, [string]$Protocol = 'TCP') {
  try { $m = Invoke-UpnpAction $Igd 'GetSpecificPortMappingEntry' ([ordered]@{ NewRemoteHost = ''; NewExternalPort = $Port; NewProtocol = $Protocol }) } catch { return $null }
  [pscustomobject]@{ ExternalPort = $Port; Protocol = $Protocol; InternalClient = $m.NewInternalClient; InternalPort = [int]$m.NewInternalPort; Description = $m.NewPortMappingDescription; LeaseSec = [int]"0$($m.NewLeaseDuration)" }
}

# map <external Port> -> <this PC>:<Port> (TCP). Adding it again = renewing the lease. Refuses a port mapped to another host.
function Add-UpnpMapping([int]$Port, [string]$Description = 'OSYNC', [int]$LeaseSec = 3600, [string]$Protocol = 'TCP', $Igd = $null) {
  if (-not $Igd) { $Igd = Find-UpnpIgd (Get-UpnpLocalIP) }
  $cur = Get-UpnpMapping $Igd $Port $Protocol
  if ($cur -and $cur.InternalClient -ne $Igd.LocalIP) { throw "UPnP: port $Port/$Protocol is already mapped to $($cur.InternalClient) ($($cur.Description)) - choose another port" }
  $a = [ordered]@{ NewRemoteHost = ''; NewExternalPort = $Port; NewProtocol = $Protocol; NewInternalPort = $Port; NewInternalClient = $Igd.LocalIP
                   NewEnabled = 1; NewPortMappingDescription = "$Description"; NewLeaseDuration = $LeaseSec }
  try { Invoke-UpnpAction $Igd 'AddPortMapping' $a | Out-Null }
  catch { if ("$($_.Exception.Data['code'])" -eq '725') { $a.NewLeaseDuration = 0; Invoke-UpnpAction $Igd 'AddPortMapping' $a | Out-Null } else { throw } }   # 725 = only permanent leases
  $ext = try { Get-UpnpExternalIP $Igd } catch { '' }
  Save-UpnpState $Port $Protocol @{ localIP = $Igd.LocalIP; externalIP = $ext; router = $Igd.Router; description = $Description; at = (Get-Date).ToString('o') }
  [pscustomobject]@{ Port = $Port; Protocol = $Protocol; LocalIP = $Igd.LocalIP; ExternalIP = $ext; Router = $Igd.Router }
}
# remove the mapping only when it is OSYNC's and points at this PC (never someone else's)
function Remove-UpnpMapping([int]$Port, [string]$Protocol = 'TCP', $Igd = $null) {
  if (-not $Igd) { $Igd = Find-UpnpIgd (Get-UpnpLocalIP) }
  $cur = Get-UpnpMapping $Igd $Port $Protocol
  Save-UpnpState $Port $Protocol $null
  if (-not $cur) { return 'not mapped' }
  if ($cur.InternalClient -ne $Igd.LocalIP -or "$($cur.Description)" -notmatch '^OSYNC') { return "left alone: mapped to $($cur.InternalClient) ($($cur.Description))" }
  Invoke-UpnpAction $Igd 'DeletePortMapping' ([ordered]@{ NewRemoteHost = ''; NewExternalPort = $Port; NewProtocol = $Protocol }) | Out-Null
  'removed'
}
# what OSYNC mapped (System\Data\Online\upnp.json, or $env:OSYNC_ONLINEDATA) - the console shows it without asking the router
# the online library's working folder: $env:OSYNC_ONLINEDATA (tests), Settings OnlineData (a folder on the master's own disk), System\Data\Online
function Get-OnlineDataDir { if ($env:OSYNC_ONLINEDATA) { return $env:OSYNC_ONLINEDATA }; $d = Get-Setting 'OnlineData' ''; if ($d) { return $d }; Join-Path $DataDir 'Online' }
function Get-UpnpStateFile { Join-Path (Get-OnlineDataDir) 'upnp.json' }
function Get-UpnpState { $f = Get-UpnpStateFile; if (Test-Path -LiteralPath $f) { try { return ([IO.File]::ReadAllText($f) | ConvertFrom-Json) } catch { } }; [pscustomobject]@{} }
function Save-UpnpState([int]$Port, [string]$Protocol, $Value) {
  $f = Get-UpnpStateFile
  try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f) | Out-Null
    $s = @{}; (Get-UpnpState).PSObject.Properties | ForEach-Object { $s[$_.Name] = $_.Value }
    $k = "$Port/$Protocol"; if ($Value) { $s[$k] = $Value } else { $s.Remove($k) }
    [IO.File]::WriteAllText($f, (ConvertTo-Json -InputObject $s -Depth 4))
  } catch { }
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    $ip = Get-UpnpLocalIP
    $igd = Find-UpnpIgd $ip
    if ($Map) { Add-UpnpMapping $Map $Description $LeaseSec | Format-List | Out-String; exit 0 }
    if ($Unmap) { Remove-UpnpMapping $Unmap; exit 0 }
    "router      : $($igd.Router)  ($($igd.ServiceType))"
    "description : $($igd.Location)"
    "this PC     : $ip"
    $ext = Get-UpnpExternalIP $igd
    "external IP : $ext$(if (Test-PrivateIPv4 $ext) { '   <- private / CGNAT address: other branches cannot reach a mapping here' })"
    $all = @(Get-UpnpMappings $igd)
    "mappings    : $($all.Count)"
    $all | Sort-Object ExternalPort | Format-Table ExternalPort, Protocol, InternalClient, InternalPort, LeaseSec, Description -AutoSize | Out-String -Width 200
    exit 0
  } catch { Write-Host "UPnP: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
}
