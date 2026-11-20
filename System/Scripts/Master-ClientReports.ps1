# Master-ClientReports.ps1 - MASTER: keeps the status reports the client PCs send after boot (Client-OslinkReport.ps1: boot steps
# and their results, OSLink, Sunshine, Steam, FiveM, Riot ...), for the admin console's "client PCs" page (18 Nov 2026; before
# that a temporary listener did this). HTTP POST /oslink-report on the LAN, port Settings ClientReportPort (4670), 2 MB max.
# Reports: C:\ProgramData\OSYNC\ClientReports\<ip>-<yyyyMMdd-HHmmss>.txt - the newest 40 per PC are kept.
# -Install / -Uninstall (administrator): task OSYNC-ClientReports (at startup, SYSTEM) + firewall rule (LAN). -Status.
# 19 Nov 2026: also the client menu's Steam game requests (SteamQueue-Lib.ps1 + Master-SteamQueue.ps1): POST /steam/request,
# GET /steam/job, POST /steam/cancel - JSON, per client IP.
# Tests: -Port <n> -Dir <folder> -AllowLoopback -MaxRequests <n>
param([switch]$Install, [switch]$Uninstall, [switch]$Status, [int]$Port = 0, [string]$Dir = '', [switch]$AllowLoopback, [int]$MaxRequests = 0)
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'SteamQueue-Lib.ps1')   # 19 Nov 2026: /steam/request, /steam/job, /steam/cancel (Steam game requests)
if (-not $Port) { $Port = [int](Get-Setting 'ClientReportPort' '4670') }
if (-not $Dir) { $Dir = Join-Path $env:ProgramData 'OSYNC\ClientReports' }
$TaskName = 'OSYNC-ClientReports'; $RuleName = 'OSYNC client reports'
$Self = $MyInvocation.MyCommand.Path

if ($Status) {
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Write-Host "task $TaskName : $(if ($t) { $t.State } else { 'not installed' })"
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "port $Port : $(if ($l) { "listening (pid $($l.OwningProcess))" } else { 'not listening' })"
  Write-Host "reports: $(@(Get-ChildItem -LiteralPath $Dir -Filter '*.txt' -ErrorAction SilentlyContinue).Count) in $Dir"
  exit 0
}
if ($Install -or $Uninstall) {
  if (-not (Test-Admin)) { Write-Host 'Run as administrator.' -ForegroundColor Red; exit 1 }
  if (-not (Test-IsMaster)) { Write-Host 'Only on the master.' -ForegroundColor Red; exit 1 }
  if ($Uninstall) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Host 'removed task + firewall rule (reports kept)'; exit 0
  }
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress LocalSubnet -Action Allow -Profile Any | Out-Null
  $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $a = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Self`""
  $tr = New-ScheduledTaskTrigger -AtStartup
  $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -StartWhenAvailable
  Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $tr -Principal $pr -Settings $st -Description "OSYNC: keeps the client PCs' status reports (LAN, port $Port)" -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Start-Sleep -Seconds 3
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "installed: task $TaskName (startup, SYSTEM), firewall '$RuleName' (TCP $Port, LocalSubnet), reports $Dir - port $Port $(if ($l) { 'listening' } else { 'NOT listening yet' })"
  exit 0
}

# ---------------- the service ----------------
if (-not $AllowLoopback -and -not (Test-IsMaster)) { Write-Host 'Only on the master.'; exit 1 }
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$created = $false
$mutex = New-Object Threading.Mutex($true, "Global\OSYNC-ClientReports-$Port", [ref]$created)
if (-not $created) { Write-Host "already running on port $Port"; exit 0 }
function Test-LanIp([Net.IPAddress]$ip) {
  if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
  if ([Net.IPAddress]::IsLoopback($ip)) { return [bool]$AllowLoopback }
  $b = $ip.GetAddressBytes(); if ($b.Length -ne 4) { return $false }
  ($b[0] -eq 10) -or ($b[0] -eq 192 -and $b[1] -eq 168) -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31)
}
$listener = New-Object Net.Sockets.TcpListener($(if ($AllowLoopback) { [Net.IPAddress]::Loopback } else { [Net.IPAddress]::Any }), $Port)
# 18 Nov 2026: the port may still be taken for a moment (an older listener) - try for 5 minutes, then stop (no busy loop)
$started = $false
for ($try = 0; $try -lt 30 -and -not $started; $try++) { try { $listener.Start(); $started = $true } catch { Start-Sleep -Seconds 10 } }
if (-not $started) { Write-Host "cannot listen on port $Port"; exit 1 }
Write-Host "client reports: listening on $Port -> $Dir"
$count = 0
while ($true) {
  try { $c = $listener.AcceptTcpClient() } catch { Start-Sleep -Seconds 1; continue }
  try {
    $ip = ([Net.IPEndPoint]$c.Client.RemoteEndPoint).Address; if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
    if (-not (Test-LanIp $ip)) { continue }
    $c.ReceiveTimeout = 15000
    $s = $c.GetStream()
    $ms = New-Object IO.MemoryStream; $tmp = New-Object byte[] 65536; $headEnd = -1; $len = -1; $path = ''
    while ($true) {
      $n = $s.Read($tmp, 0, $tmp.Length); if ($n -le 0) { break }
      $ms.Write($tmp, 0, $n); $all = $ms.ToArray()
      if ($headEnd -lt 0) {
        $txt = [Text.Encoding]::ASCII.GetString($all); $headEnd = $txt.IndexOf("`r`n`r`n")
        if ($headEnd -ge 0) { $head = $txt.Substring(0, $headEnd); $path = (($head -split "`r`n")[0] -split ' ')[1]; if ($head -match '(?im)^Content-Length:\s*(\d+)') { $len = [int]$Matches[1] } else { $len = 0 } }
      }
      if ($headEnd -ge 0 -and $all.Length -ge $headEnd + 4 + $len) { break }
      if ($all.Length -gt 2MB) { break }
    }
    $all = $ms.ToArray()
    # 19 Nov 2026: Steam game requests from the client menu (SteamQueue-Lib.ps1) - JSON in, JSON out
    $route = ("$path" -split '\?')[0]
    if ($headEnd -ge 0 -and $route -like '/steam/*') {
      $method = (($head -split "`r`n")[0] -split ' ')[0]
      $body = if ($len -gt 0 -and $len -le 64KB) { [Text.Encoding]::UTF8.GetString($all, $headEnd + 4, [Math]::Max(0, [Math]::Min($len, $all.Length - $headEnd - 4))) } else { '' }
      $res = try { Invoke-SqApi $method $route $body "$ip" } catch { @{ code = 500; body = @{ ok = $false; message = "เครื่องแม่ขัดข้อง: $($_.Exception.Message)" } } }
      $json = [Text.Encoding]::UTF8.GetBytes(($res.body | ConvertTo-Json -Depth 6 -Compress))
      $hd = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $($res.code) OK`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($json.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n")
      $s.Write($hd, 0, $hd.Length); $s.Write($json, 0, $json.Length)
    }
    elseif ($headEnd -ge 0 -and $path -eq '/oslink-report' -and $len -gt 0 -and $len -le 2MB) {
      $body = [Text.Encoding]::UTF8.GetString($all, $headEnd + 4, [Math]::Max(0, [Math]::Min($len, $all.Length - $headEnd - 4)))
      $ipS = "$ip"
      [IO.File]::WriteAllText((Join-Path $Dir ("{0}-{1}.txt" -f $ipS, (Get-Date -Format 'yyyyMMdd-HHmmss'))), $body, (New-Object Text.UTF8Encoding($false)))
      @(Get-ChildItem -LiteralPath $Dir -Filter "$ipS-*.txt" -File | Sort-Object Name -Descending | Select-Object -Skip 40) | ForEach-Object { [IO.File]::Delete($_.FullName) }
    }
    if ($route -notlike '/steam/*') {
      $ok = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: 2`r`nConnection: close`r`n`r`nOK")
      $s.Write($ok, 0, $ok.Length)
    }
  } catch { } finally { try { $c.Close() } catch { } }
  $count++
  if ($MaxRequests -gt 0 -and $count -ge $MaxRequests) { break }
}
$listener.Stop()
