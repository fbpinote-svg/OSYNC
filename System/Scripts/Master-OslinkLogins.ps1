# Master-OslinkLogins.ps1 - MASTER: keeps each client PC's own OSLink sign-in, so the support account signed in on the master
# reaches every client and stays signed in across diskless reboots (16 Nov, user chose "automatic").
# Why: OSLink's saved sign-in (userData\accounts\<uid>\userinfo.config loginKey) belongs to one PC. Clients copy the master's
# copy from the game disk; the first boot of a PC with it makes OSLink register that PC as a computer of its own with a NEW
# key - which a diskless reboot throws away (next boot: "please sign in again"). This service is where each PC's own key is
# kept: the client's logon helper (Client-OslinkHelper.ps1) sends it here after OSLink signed in, the boot step
# (Client-OslinkLogin.ps1) asks for it at the next boot and puts it back before OSLink starts.
# HTTP on the LAN, port Settings OslinkLoginPort (4669). A PC only ever reads / writes ITS OWN record: the record is chosen by
# the caller's IP address (diskless PCs keep their IP), so a customer on PC X can only get what PC X already has.
# Records: C:\ProgramData\OSYNC\OslinkLogins\<ip>.json (SYSTEM + Administrators only; not on the game disk).
#   GET  /oslink-login   -> 200 record | 404
#   POST /oslink-login   <- { pc, uid, files: { "accounts/<uid>/userinfo.config": base64, ... }, mac, rcmac: { hklm, hkcu } }
# ONLY THE SHOP'S ACCOUNT (18 Nov 2026, the owner): a record is kept / handed out only when its uid is an account signed in
# on the master's OSLink (<OSLink>\userData\accounts\<uid>\userinfo.config, looked up at every request). A customer who
# signs in with their own OSLink account on a client is NOT kept (POST -> 403), so the next customer on that PC never gets
# it; an older record of another account is not handed out (GET -> 404). Nobody signed in on the master = nothing kept.
# -Install   (administrator) data folder + firewall rule (LAN only) + task OSYNC-OslinkLogins (at startup, SYSTEM) + start
# -Uninstall (administrator) task + firewall rule removed (records kept)   -Status  what is installed / running / stored
# Tests: -Port <n> -RecordDir <folder> -AllowLoopback (127.0.0.1 allowed) -MaxRequests <n> (exit after n requests)
#        -ShopAccounts <folder> (instead of the master's OSLink userData\accounts)
param([switch]$Install, [switch]$Uninstall, [switch]$Status, [int]$Port = 0, [string]$RecordDir = '', [switch]$AllowLoopback, [int]$MaxRequests = 0, [string]$ShopAccounts = '')
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $Port) { $Port = [int](Get-Setting 'OslinkLoginPort' '4669') }
# (not $RecordDir: Common.ps1 has its own $RecordDir = System\Data on the game disk, which the clients can read)
if (-not $RecordDir) { $RecordDir = Join-Path $env:ProgramData 'OSYNC\OslinkLogins' }
$TaskName = 'OSYNC-OslinkLogins'; $RuleName = 'OSYNC OSLink logins'
$Self = $MyInvocation.MyCommand.Path

# the accounts signed in on the master's OSLink = the shop's account(s): <OSLink>\userData\accounts\<uid>\userinfo.config
function Get-ShopAccountsDir {
  if ($ShopAccounts) { return $ShopAccounts }
  $svc = Get-CimInstance Win32_Service -Filter "Name='LDRemoteSvc'" -ErrorAction SilentlyContinue
  if ($svc -and $svc.PathName) {
    $m = [regex]::Match($svc.PathName, '^\s*"([^"]+)"'); if (-not $m.Success) { $m = [regex]::Match($svc.PathName, '^\s*(\S+?\.exe)') }
    if ($m.Success) { $r = Join-Path (Split-Path -Parent (Split-Path -Parent $m.Groups[1].Value)) 'userData\accounts'; if (Test-Path -LiteralPath $r) { return $r } }
  }
  foreach ($d in (Get-SharedDrives).ToCharArray()) { $r = "${d}:\LDPlayer\OSLink\userData\accounts"; if (Test-Path -LiteralPath $r) { return $r } }
  ''
}
function Get-ShopUids {
  $dir = Get-ShopAccountsDir
  if (-not $dir) { return @() }
  @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4,30}$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'userinfo.config')) } | ForEach-Object Name)
}

if ($Status) {
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Write-Host "task $TaskName : $(if ($t) { $t.State } else { 'not installed' })"
  Write-Host "firewall '$RuleName' : $(if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) { 'present' } else { 'missing' })"
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "port $Port : $(if ($l) { "listening (pid $($l.OwningProcess))" } else { 'not listening' })"
  $shop = @(Get-ShopUids)
  Write-Host "shop account(s) signed in on the master: $(if ($shop.Count) { $shop.Count } else { 'none - no client sign-in is kept' })"
  $recs = @(Get-ChildItem -LiteralPath $RecordDir -Filter '*.json' -ErrorAction SilentlyContinue)
  Write-Host "records: $($recs.Count)"
  foreach ($r in $recs) { try { $j = Get-Content -LiteralPath $r.FullName -Raw | ConvertFrom-Json; Write-Host ("  {0,-16} {1,-12} saved {2}{3}" -f $r.BaseName, $j.pc, $j.at, $(if ($shop -notcontains "$($j.uid)") { '  (NOT the shop account - not handed out)' } else { '' })) } catch { Write-Host "  $($r.Name) (unreadable)" } }
  exit 0
}
if ($Install -or $Uninstall) {
  if (-not (Test-Admin)) { Write-Host 'Run as administrator.' -ForegroundColor Red; exit 1 }
  if (-not (Test-IsMaster)) { Write-Host 'Only on the master.' -ForegroundColor Red; exit 1 }
  if ($Uninstall) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Host "removed task + firewall rule (records kept in $RecordDir)"; exit 0
  }
  New-Item -ItemType Directory -Force -Path $RecordDir | Out-Null
  & icacls.exe $RecordDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress LocalSubnet -Action Allow -Profile Any | Out-Null
  $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $a = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Self`""
  $tr = New-ScheduledTaskTrigger -AtStartup
  $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -StartWhenAvailable
  Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $tr -Principal $pr -Settings $st -Description "OSYNC: keeps each client PC's own OSLink sign-in (LAN, port $Port)" -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Start-Sleep -Seconds 3
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "installed: task $TaskName (startup, SYSTEM), firewall '$RuleName' (TCP $Port, LocalSubnet), data $RecordDir - port $Port $(if ($l) { 'listening' } else { 'NOT listening yet' })"
  exit 0
}

# ---------------- the service ----------------
if (-not $AllowLoopback -and -not (Test-IsMaster)) { Write-Host 'Only on the master.'; exit 1 }
New-Item -ItemType Directory -Force -Path $RecordDir | Out-Null
$logFile = Join-Path $RecordDir 'server.log'
function Log([string]$s) {
  try {
    if ((Test-Path -LiteralPath $logFile) -and (Get-Item -LiteralPath $logFile).Length -gt 1MB) { Move-Item -LiteralPath $logFile -Destination "$logFile.1" -Force }
    Add-Content -LiteralPath $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $s) -Encoding UTF8
  } catch { }
}
$created = $false
$mutex = New-Object Threading.Mutex($true, "Global\OSYNC-OslinkLogins-$Port", [ref]$created)
if (-not $created) { Write-Host "already running on port $Port"; exit 0 }

$FileKey = '^accounts/(\d{4,30}/(userinfo\.config|user\.ini)|lastuser\.data)$'
function Test-LanIp([Net.IPAddress]$ip) {
  if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
  if ([Net.IPAddress]::IsLoopback($ip)) { return [bool]$AllowLoopback }
  $b = $ip.GetAddressBytes()
  if ($b.Length -ne 4) { return $false }
  ($b[0] -eq 10) -or ($b[0] -eq 192 -and $b[1] -eq 168) -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31)
}
function Test-Record($r) {
  if (-not $r -or "$($r.pc)" -notmatch '^[A-Za-z0-9_.-]{1,40}$') { return 'pc' }
  if ("$($r.uid)" -notmatch '^\d{4,30}$') { return 'uid' }
  if ($r.mac -and "$($r.mac)" -notmatch '^[0-9A-Fa-f]{12}$') { return 'mac' }
  if ($r.rcmac) { foreach ($k in 'hklm', 'hkcu') { $v = "$($r.rcmac.$k)"; if ($v -and $v -notmatch '^[0-9A-Za-z]{8,64}$') { return "rcmac.$k" } } }
  if (-not $r.files) { return 'files' }
  $n = 0
  foreach ($p in $r.files.PSObject.Properties) {
    $n++
    if ($p.Name -notmatch $FileKey) { return "file name $($p.Name)" }
    if ("$($p.Value)".Length -gt 24000) { return "file size $($p.Name)" }
    try { [void][Convert]::FromBase64String("$($p.Value)") } catch { return "file data $($p.Name)" }
  }
  if (-not $n -or -not ($r.files.PSObject.Properties.Name -match '/userinfo\.config$')) { return 'no userinfo.config' }
  ''
}
function Send($stream, [int]$code, [string]$body) {
  $reason = @{ 200 = 'OK'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 405 = 'Method Not Allowed'; 413 = 'Payload Too Large' }[$code]
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $code $reason`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
  $stream.Write($head, 0, $head.Length); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
}
function Handle([Net.Sockets.TcpClient]$c) {
  $c.ReceiveTimeout = 5000; $c.SendTimeout = 5000
  $ep = [Net.IPEndPoint]$c.Client.RemoteEndPoint
  $ip = $ep.Address; if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
  $s = $c.GetStream()
  # request line + headers (max 8 KB), then the body by Content-Length (max 64 KB)
  $buf = New-Object byte[] 8192; $got = 0; $headEnd = -1
  while ($got -lt $buf.Length) {
    $n = $s.Read($buf, $got, $buf.Length - $got); if ($n -le 0) { break }; $got += $n
    $txt = [Text.Encoding]::ASCII.GetString($buf, 0, $got); $headEnd = $txt.IndexOf("`r`n`r`n"); if ($headEnd -ge 0) { break }
  }
  if ($headEnd -lt 0) { Send $s 400 '{"ok":false,"error":"bad request"}'; return }
  $lines = $txt.Substring(0, $headEnd) -split "`r`n"
  $parts = $lines[0] -split ' '
  $method = $parts[0]; $path = ($parts[1] -split '\?')[0]
  if (-not (Test-LanIp $ip)) { Send $s 403 '{"ok":false,"error":"LAN only"}'; Log "403 $ip $method $path"; return }
  if ($path -ne '/oslink-login') { Send $s 404 '{"ok":false,"error":"not found"}'; return }
  $file = Join-Path $RecordDir ("$ip" + '.json')
  if ($method -eq 'GET') {
    if (Test-Path -LiteralPath $file) {
      $uid = ''; try { $uid = "$(([IO.File]::ReadAllText($file) | ConvertFrom-Json).uid)" } catch { }
      if ((Get-ShopUids) -contains $uid) { Send $s 200 ([IO.File]::ReadAllText($file)); Log "GET $ip -> record" }
      else { Send $s 404 '{"ok":false,"error":"no record"}'; Log "GET $ip -> record of another account (not the shop's) - not handed out" }
    } else { Send $s 404 '{"ok":false,"error":"no record"}'; Log "GET $ip -> none" }
    return
  }
  if ($method -ne 'POST') { Send $s 405 '{"ok":false,"error":"GET or POST"}'; return }
  $len = 0; foreach ($h in $lines) { if ($h -match '^(?i)content-length:\s*(\d+)') { $len = [int]$Matches[1] } }
  if ($len -le 0 -or $len -gt 65536) { Send $s 413 '{"ok":false,"error":"size"}'; return }
  $body = New-Object byte[] $len
  $have = $got - ($headEnd + 4); if ($have -gt $len) { $have = $len }
  if ($have -gt 0) { [Array]::Copy($buf, $headEnd + 4, $body, 0, $have) }
  while ($have -lt $len) { $n = $s.Read($body, $have, $len - $have); if ($n -le 0) { break }; $have += $n }
  if ($have -lt $len) { Send $s 400 '{"ok":false,"error":"short body"}'; return }
  try { $r = [Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json } catch { Send $s 400 '{"ok":false,"error":"json"}'; return }
  $bad = Test-Record $r
  if ($bad) { Send $s 400 ('{"ok":false,"error":"' + $bad + '"}'); Log "POST $ip rejected: $bad"; return }
  if ((Get-ShopUids) -notcontains "$($r.uid)") { Send $s 403 '{"ok":false,"error":"not the shop account"}'; Log "POST $ip rejected: not the shop account signed in on the master ($($r.pc)) - not kept"; return }
  $out = [ordered]@{ pc = "$($r.pc)"; ip = "$ip"; at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); uid = "$($r.uid)"; mac = "$($r.mac)"; rcmac = [ordered]@{ hklm = "$($r.rcmac.hklm)"; hkcu = "$($r.rcmac.hkcu)" }; files = [ordered]@{} }
  foreach ($p in $r.files.PSObject.Properties) { $out.files[$p.Name] = "$($p.Value)" }
  $tmp = "$file.tmp"
  [IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject $out -Depth 5), (New-Object Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $file -Force
  Send $s 200 '{"ok":true}'
  Log "POST $ip saved ($($out.pc), uid $($out.uid), $($out.files.Count) file(s))"
}

# tests (-AllowLoopback) listen on 127.0.0.1 only (no firewall prompt); the service listens on the LAN (firewall rule from -Install)
$listener = New-Object Net.Sockets.TcpListener($(if ($AllowLoopback) { [Net.IPAddress]::Loopback } else { [Net.IPAddress]::Any }), $Port)
$listener.Start()
Log "listening on $Port (data $RecordDir)"
Write-Host "OSLink logins: listening on $Port"
$count = 0
while ($true) {
  $c = $listener.AcceptTcpClient()
  try { Handle $c } catch { Log "error: $($_.Exception.Message)" } finally { try { $c.Close() } catch { } }
  $count++
  if ($MaxRequests -gt 0 -and $count -ge $MaxRequests) { break }
}
$listener.Stop()
