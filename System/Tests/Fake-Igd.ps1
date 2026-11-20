# Fake-Igd.ps1 - TESTS ONLY: a pretend UPnP router (IGD, WANIPConnection:1) on 127.0.0.1 for Sim-OnlineLibrary.ps1 -Upnp.
# Behaves like miniupnpd in secure mode: a host may only map to / delete mappings of its OWN address, a port mapped to
# another host is a conflict (718). Nothing real is touched (no SSDP: the scripts get the description URL from
# $env:OSYNC_UPNP_LOCATION). Test helpers: GET /_state (mappings + how many AddPortMapping calls), POST /_seed {port,client,
# description} (a mapping of another host, e.g. Parsec on a client PC), POST /_stop.
#   Fake-Igd.ps1 -Port 4791 -ExternalIP 203.0.113.10
param([int]$Port = 4791, [string]$ExternalIP = '203.0.113.10')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Scripts\Http-Lib.ps1')
$svc = 'urn:schemas-upnp-org:service:WANIPConnection:1'
$script:maps = @{}; $script:adds = 0
$desc = @"
<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0"><specVersion><major>1</major><minor>0</minor></specVersion>
<device><deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType><friendlyName>fake IGD</friendlyName>
<deviceList><device><deviceType>urn:schemas-upnp-org:device:WANDevice:1</deviceType><deviceList><device>
<deviceType>urn:schemas-upnp-org:device:WANConnectionDevice:1</deviceType><serviceList><service><serviceType>$svc</serviceType>
<serviceId>urn:upnp-org:serviceId:WANIPConn1</serviceId><controlURL>/ctl/IPConn</controlURL><eventSubURL>/evt/IPConn</eventSubURL><SCPDURL>/WANIPCn.xml</SCPDURL></service></serviceList>
</device></deviceList></device></deviceList></device></root>
"@
function Soap([string]$action, [hashtable]$out) {
  $x = ''; foreach ($k in $out.Keys) { $x += "<$k>$([Security.SecurityElement]::Escape([string]$out[$k]))</$k>" }
  @{ Status = 200; Type = 'text/xml; charset="utf-8"'; Body = "<?xml version=`"1.0`"?><s:Envelope xmlns:s=`"http://schemas.xmlsoap.org/soap/envelope/`"><s:Body><u:${action}Response xmlns:u=`"$svc`">$x</u:${action}Response></s:Body></s:Envelope>" }
}
function Fault([int]$code, [string]$text) {
  @{ Status = 500; Type = 'text/xml; charset="utf-8"'; Body = "<?xml version=`"1.0`"?><s:Envelope xmlns:s=`"http://schemas.xmlsoap.org/soap/envelope/`"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns=`"urn:schemas-upnp-org:control-1-0`"><errorCode>$code</errorCode><errorDescription>$text</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>" }
}
$handler = {
  param($req)
  if ($req.Path -eq '/rootDesc.xml') { return @{ Status = 200; Type = 'text/xml'; Body = $desc } }
  if ($req.Path -eq '/_state') { return (New-JsonResponse @{ adds = $script:adds; maps = @($script:maps.Values) }) }
  if ($req.Path -eq '/_seed') { $b = Get-JsonBody $req; $script:maps["$($b.port)/TCP"] = [ordered]@{ port = [int]$b.port; proto = 'TCP'; client = "$($b.client)"; iport = [int]$b.port; desc = "$($b.description)"; lease = 0 }; return (New-JsonResponse @{ ok = $true }) }
  if ($req.Path -eq '/_stop') { $r = New-JsonResponse @{ ok = $true }; $r.Stop = $true; return $r }
  if ($req.Path -ne '/ctl/IPConn') { return (New-ErrorResponse 404 'not found') }
  $action = ("$($req.Headers['soapaction'])".Trim('"') -split '#')[-1]
  $x = [xml]$req.BodyText
  $arg = { param($n) "$($x.SelectSingleNode("//*[local-name()='$n']").InnerText)" }
  switch ($action) {
    'GetExternalIPAddress' { return (Soap $action @{ NewExternalIPAddress = $ExternalIP }) }
    'AddPortMapping' {
      $k = "$(& $arg 'NewExternalPort')/$(& $arg 'NewProtocol')"; $client = & $arg 'NewInternalClient'
      if ($client -ne $req.Remote) { return (Fault 606 'Action not authorized') }                         # secure mode
      if ($script:maps[$k] -and $script:maps[$k].client -ne $client) { return (Fault 718 'ConflictInMappingEntry') }
      $script:adds++
      $script:maps[$k] = [ordered]@{ port = [int](& $arg 'NewExternalPort'); proto = (& $arg 'NewProtocol'); client = $client; iport = [int](& $arg 'NewInternalPort'); desc = (& $arg 'NewPortMappingDescription'); lease = [int](& $arg 'NewLeaseDuration') }
      return (Soap $action @{})
    }
    'GetSpecificPortMappingEntry' {
      $m = $script:maps["$(& $arg 'NewExternalPort')/$(& $arg 'NewProtocol')"]
      if (-not $m) { return (Fault 714 'NoSuchEntryInArray') }
      return (Soap $action ([ordered]@{ NewInternalPort = $m.iport; NewInternalClient = $m.client; NewEnabled = 1; NewPortMappingDescription = $m.desc; NewLeaseDuration = $m.lease }))
    }
    'GetGenericPortMappingEntry' {
      $all = @($script:maps.Values | Sort-Object { $_.port }); $i = [int](& $arg 'NewPortMappingIndex')
      if ($i -ge $all.Count) { return (Fault 713 'SpecifiedArrayIndexInvalid') }
      $m = $all[$i]
      return (Soap $action ([ordered]@{ NewRemoteHost = ''; NewExternalPort = $m.port; NewProtocol = $m.proto; NewInternalPort = $m.iport; NewInternalClient = $m.client; NewEnabled = 1; NewPortMappingDescription = $m.desc; NewLeaseDuration = $m.lease }))
    }
    'DeletePortMapping' {
      $k = "$(& $arg 'NewExternalPort')/$(& $arg 'NewProtocol')"
      if (-not $script:maps[$k]) { return (Fault 714 'NoSuchEntryInArray') }
      if ($script:maps[$k].client -ne $req.Remote) { return (Fault 606 'Action not authorized') }
      $script:maps.Remove($k); return (Soap $action @{})
    }
    default { return (Fault 401 'Invalid Action') }
  }
}
Start-HttpServer -Port $Port -Bind '127.0.0.1' -Handler $handler -Name 'fake IGD'
