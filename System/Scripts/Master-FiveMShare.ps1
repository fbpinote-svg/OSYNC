# Master-FiveMShare.ps1 - MASTER: collects the FiveM servers' files the CLIENT PCs download, so every client has them after
# its next boot (18 Nov 2026, the owner's idea; tested: KORI12 joined a server the master had fetched and downloaded 1 file of 220).
# What FiveM keeps (<FiveM>.app\data\server-cache-priv): the servers' files (cache_<sha1>) + an index (db\, LevelDB). Both are
# encrypted by FiveM with a key that is the same on every PC - so they are only copied, never opened. Merging two indexes is
# not possible that way, so a client's copy is taken WHOLE, and only when it grew from exactly the index the master has now:
#   at boot a client notes the fingerprint of the master's index as it sees it (Client-FiveMShare.ps1); FiveM then only ADDS
#   to it. When FiveM is closed on the client, it offers its new files: same fingerprint as the master's index now -> the
#   master takes the client's new files (only those it does not have) + the client's index (= everything the master had +
#   the new servers); other fingerprint (another client or the master was faster) -> "stale", nothing taken.
#   The index is swapped as a folder (new copy + rename), new files are added under new names: a client that is running keeps
#   its own view until it reboots. The master's FiveM must be closed (its index is in use) - else "busy, later".
# v2 (18 Nov 2026 evening): KORI19 offered 1.5 GB at 17:16 and restarted at 17:24 with nothing arrived, and no log was left to
#   say why (a client's own log is gone after its reboot). Now: a client sends its files AHEAD while FiveM runs (offer with
#   pre=true, no index; same session kept), so little is left when FiveM is closed; clients also send their log lines here
#   (POST /fivem/log); every refused request, broken upload and slow file is logged; a commit drops the other sessions
#   (they are stale then); sessions live 3 h after their LAST request; old session folders are removed at start.
# HTTP on the LAN, port Settings FiveMSharePort (4671). Incoming: <drive of FiveM>:\_osync-fivem-incoming\<session>.
#   POST /fivem/offer           {pc, base, files:[{n,s}], db:[{n,s}], pre, session}  -> {ok, session, need:[n], reason}
#                               pre=true: files only (FiveM still runs there); session: add to that session
#   PUT  /fivem/put/<s>/f/<n>   a cache_<sha1> file        PUT /fivem/put/<s>/d/<n>   an index file (CURRENT, MANIFEST-n, n.ldb, n.log, LOCK)
#   POST /fivem/commit/<s>      -> {ok, base (the new fingerprint), added, reason}
#   POST /fivem/drop/<s>        the client gives up the session
#   POST /fivem/log             {pc, msg} -> one line in the log (at most 120 lines per PC per hour)
#   GET  /fivem/base            -> the fingerprint now
# -Install / -Uninstall (administrator): task OSYNC-FiveMShare (at startup, SYSTEM) + firewall rule (LAN). -Status.
# Tests: -Port <n> -CacheDir <server-cache-priv folder> -AllowLoopback -MaxRequests <n> -NoProcessCheck
# Log: <drive>:\_osync-fivem-incoming\server.log
param([switch]$Install, [switch]$Uninstall, [switch]$Status, [int]$Port = 0, [string]$CacheDir = '', [switch]$AllowLoopback, [int]$MaxRequests = 0, [switch]$NoProcessCheck)
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $Port) { $Port = [int](Get-Setting 'FiveMSharePort' '4671') }
$TaskName = 'OSYNC-FiveMShare'; $RuleName = 'OSYNC FiveM share'
$Self = $MyInvocation.MyCommand.Path

function Get-CacheDir {
  if ($CacheDir) { return $CacheDir }
  $app = @(Get-CfxApps | Where-Object { $_.Name -eq 'FiveM' }) | Select-Object -First 1
  if (-not $app) { return '' }
  Join-Path $app.App 'data\server-cache-priv'
}
# fingerprint of an index folder: names, sizes and times of its files (a client sees the master's values)
function Get-Fingerprint([string]$db) {
  $items = @(Get-ChildItem -LiteralPath $db -File -Force -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" })
  if (-not $items.Count) { return '' }
  $sha = [Security.Cryptography.SHA256]::Create()
  ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($items -join "`n")))) -replace '-', '').Substring(0, 32)
}
function Test-FiveMRunning { if ($NoProcessCheck) { return $false }; [bool](Get-Process -Name 'FiveM', 'FiveM_*' -ErrorAction SilentlyContinue) }

if ($Status) {
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Write-Host "task $TaskName : $(if ($t) { $t.State } else { 'not installed' })"
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "port $Port : $(if ($l) { "listening (pid $($l.OwningProcess))" } else { 'not listening' })"
  $cd = Get-CacheDir
  if ($cd) { $f = @(Get-ChildItem -LiteralPath $cd -File -Filter 'cache_*' -ErrorAction SilentlyContinue); Write-Host "cache $cd : $($f.Count) files, $([math]::Round((($f | Measure-Object Length -Sum).Sum)/1GB, 2)) GB, index $(Get-Fingerprint (Join-Path $cd 'db'))" }
  exit 0
}
if ($Install -or $Uninstall) {
  if (-not (Test-Admin)) { Write-Host 'Run as administrator.' -ForegroundColor Red; exit 1 }
  if (-not (Test-IsMaster)) { Write-Host 'Only on the master.' -ForegroundColor Red; exit 1 }
  if ($Uninstall) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Host 'removed task + firewall rule'; exit 0
  }
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress LocalSubnet -Action Allow -Profile Any | Out-Null
  $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $a = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Self`""
  $tr = New-ScheduledTaskTrigger -AtStartup
  $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -StartWhenAvailable
  Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $tr -Principal $pr -Settings $st -Description "OSYNC: takes the FiveM server files the client PCs downloaded (LAN, port $Port)" -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Start-Sleep -Seconds 3
  $l = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host "installed: task $TaskName (startup, SYSTEM), firewall '$RuleName' (TCP $Port, LocalSubnet) - port $Port $(if ($l) { 'listening' } else { 'NOT listening yet' })"
  exit 0
}

# ---------------- the service ----------------
if (-not $AllowLoopback -and -not (Test-IsMaster)) { Write-Host 'Only on the master.'; exit 1 }
$cache = Get-CacheDir
if (-not $cache -or -not (Test-Path -LiteralPath $cache)) { Write-Host "no FiveM server-cache-priv found ($cache)"; exit 1 }
$drive = Split-Path -Qualifier $cache
$inbox = Join-Path "$drive\" '_osync-fivem-incoming'
New-Item -ItemType Directory -Force -Path $inbox | Out-Null
$logFile = Join-Path $inbox 'server.log'
function Log([string]$s) {
  try {
    if ((Test-Path -LiteralPath $logFile) -and (Get-Item -LiteralPath $logFile).Length -gt 2MB) { Move-Item -LiteralPath $logFile -Destination "$logFile.1" -Force }
    Add-Content -LiteralPath $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $s) -Encoding UTF8
  } catch { }
}
$created = $false
$mutex = New-Object Threading.Mutex($true, "Global\OSYNC-FiveMShare-$Port", [ref]$created)
if (-not $created) { Write-Host "already running on port $Port"; exit 0 }

$MaxFile = 1GB; $MaxOffer = 20GB; $KeepFree = 30GB
$sessions = @{}
$logLines = @{}
$script:req = ''
# sessions live in memory only: the folders an earlier run left are of no use any more
foreach ($d in @(Get-ChildItem -LiteralPath $inbox -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[0-9a-f]{12}$' })) { try { [IO.Directory]::Delete($d.FullName, $true) } catch { } }
function Test-LanIp([Net.IPAddress]$ip) {
  if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
  if ([Net.IPAddress]::IsLoopback($ip)) { return [bool]$AllowLoopback }
  $b = $ip.GetAddressBytes(); if ($b.Length -ne 4) { return $false }
  ($b[0] -eq 10) -or ($b[0] -eq 192 -and $b[1] -eq 168) -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31)
}
# -Quiet: the caller logs it itself (with more detail)
function Send($stream, [int]$code, $obj, [switch]$Quiet) {
  $reason = @{ 200 = 'OK'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 405 = 'Method Not Allowed'; 409 = 'Conflict'; 413 = 'Payload Too Large'; 503 = 'Busy' }[$code]
  $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $obj -Depth 4 -Compress))
  $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $code $reason`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
  $stream.Write($head, 0, $head.Length); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
  if ($code -ne 200 -and -not $Quiet) { Log "$($script:req) -> $code $($obj.reason)" }
}
function Get-Free { try { (New-Object IO.DriveInfo($drive)).AvailableFreeSpace } catch { 0 } }
function Remove-Session([string]$id) {
  if (-not $sessions.ContainsKey($id)) { return }
  try { [IO.Directory]::Delete($sessions[$id].Dir, $true) } catch { }
  $sessions.Remove($id)
}
function Remove-OldSessions {
  foreach ($k in @($sessions.Keys)) { if (((Get-Date) - $sessions[$k].At).TotalHours -gt 3) { Log "session $k ($($sessions[$k].Pc)): nothing for 3 h - removed"; Remove-Session $k } }
}
function Get-MB([long]$b) { [math]::Round($b / 1MB) }
# adopt a client's index + its new files (called with everything checked)
function Invoke-Adopt($sess) {
  $live = Join-Path $cache 'db'
  $added = 0
  foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $sess.Dir 'f') -File -ErrorAction SilentlyContinue)) {
    $dst = Join-Path $cache $f.Name
    if (Test-Path -LiteralPath $dst) { continue }
    [IO.File]::Move($f.FullName, $dst); $added++
  }
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $newDb = Join-Path $cache 'db-osync-new'
  if (Test-Path -LiteralPath $newDb) { [IO.Directory]::Delete($newDb, $true) }
  [IO.Directory]::Move((Join-Path $sess.Dir 'd'), $newDb)
  $old = Join-Path $cache "db-osync-old-$stamp"
  [IO.Directory]::Move($live, $old)
  [IO.Directory]::Move($newDb, $live)
  $q = Join-Path "$drive\" ('_' + [char]0x0E25 + [char]0x0E1A + [char]0x0E44 + [char]0x0E14 + [char]0x0E49)   # the folder 'to delete' (built from char codes: this file stays ASCII)
  $qd = Join-Path $q 'fivem-index-old'
  New-Item -ItemType Directory -Force -Path $qd | Out-Null
  try { [IO.Directory]::Move($old, (Join-Path $qd $stamp)) } catch { }
  $added
}

function Handle([Net.Sockets.TcpClient]$c) {
  $c.ReceiveTimeout = 60000; $c.SendTimeout = 60000
  $ip = ([Net.IPEndPoint]$c.Client.RemoteEndPoint).Address; if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
  $s = $c.GetStream()
  $script:req = "$ip ?"
  $buf = New-Object byte[] 16384; $got = 0; $headEnd = -1; $txt = ''
  while ($got -lt $buf.Length) {
    $n = $s.Read($buf, $got, $buf.Length - $got); if ($n -le 0) { break }; $got += $n
    $txt = [Text.Encoding]::ASCII.GetString($buf, 0, $got); $headEnd = $txt.IndexOf("`r`n`r`n"); if ($headEnd -ge 0) { break }
  }
  if ($headEnd -lt 0) { Send $s 400 @{ ok = $false; reason = 'bad request' }; return }
  $lines = $txt.Substring(0, $headEnd) -split "`r`n"
  $parts = $lines[0] -split ' '; $method = $parts[0]; $path = ($parts[1] -split '\?')[0]
  $script:req = "$ip $method $path"
  if (-not (Test-LanIp $ip)) { Send $s 403 @{ ok = $false; reason = 'LAN only' }; return }
  [long]$len = 0; foreach ($h in $lines) { if ($h -match '^(?i)content-length:\s*(\d+)') { $len = [long]$Matches[1] } }
  $have = $got - ($headEnd + 4)
  # small JSON bodies
  function Read-Json { if ($len -le 0 -or $len -gt 4MB) { return $null }; $body = New-Object byte[] $len; $h2 = [Math]::Min($have, $len); if ($h2 -gt 0) { [Array]::Copy($buf, $headEnd + 4, $body, 0, $h2) }; while ($h2 -lt $len) { $n = $s.Read($body, $h2, $len - $h2); if ($n -le 0) { break }; $h2 += $n }; try { [Text.Encoding]::UTF8.GetString($body, 0, $h2) | ConvertFrom-Json } catch { $null } }
  # a session of this PC (another PC's session id is "no session")
  function Get-Sess([string]$id) { $x = $sessions[$id]; if ($x -and $x.Ip -eq "$ip") { $x } else { $null } }

  if ($method -eq 'GET' -and $path -eq '/fivem/base') { Send $s 200 @{ ok = $true; base = (Get-Fingerprint (Join-Path $cache 'db')) }; return }
  if ($method -eq 'POST' -and $path -eq '/fivem/log') {
    $o = Read-Json
    $hk = "$ip|$((Get-Date).ToString('yyyyMMddHH'))"
    if ($logLines.Count -gt 5000) { $logLines.Clear() }
    $logLines[$hk] = 1 + [int]$logLines[$hk]
    if ($o -and $logLines[$hk] -le 120) {
      $m = "$($o.msg)" -replace '[\x00-\x1f]', ' '; if ($m.Length -gt 300) { $m = $m.Substring(0, 300) }
      Log "  $ip $("$($o.pc)" -replace '[^A-Za-z0-9_.-]', ''): $m"
    }
    Send $s 200 @{ ok = $true }; return
  }
  if ($method -eq 'POST' -and $path -eq '/fivem/offer') {
    $o = Read-Json
    if (-not $o -or "$($o.pc)" -notmatch '^[A-Za-z0-9_.-]{1,40}$' -or "$($o.base)" -notmatch '^[0-9A-F]{32}$') { Send $s 400 @{ ok = $false; reason = 'bad offer' }; return }
    $pre = [bool]$o.pre
    Remove-OldSessions
    $now = Get-Fingerprint (Join-Path $cache 'db')
    if ($o.base -ne $now) { Send $s 409 @{ ok = $false; reason = 'stale' } -Quiet; Log "offer $ip $($o.pc): stale (its base $($o.base), now $now)"; return }
    if (-not $pre -and (Test-FiveMRunning)) { Send $s 503 @{ ok = $false; reason = 'busy' } -Quiet; Log "offer $ip $($o.pc): FiveM runs on the master - later"; return }
    $files = @($o.files | Where-Object { "$($_.n)" -match '^cache_[0-9a-f]{40}$' -and [long]$_.s -gt 0 -and [long]$_.s -le $MaxFile })
    $dbs = @()
    if (-not $pre) {
      $dbs = @($o.db | Where-Object { "$($_.n)" -match '^(CURRENT|LOCK|LOG|LOG\.old|MANIFEST-\d{1,9}|\d{1,9}\.(log|ldb|sst))$' -and [long]$_.s -ge 0 -and [long]$_.s -le 512MB })
      if (-not $dbs.Count -or -not @($dbs | Where-Object { $_.n -eq 'CURRENT' }).Count -or $dbs.Count -ne @($o.db).Count) { Send $s 400 @{ ok = $false; reason = 'bad index list' }; return }
    }
    $id = "$($o.session)"; $sess = $null
    if ($id) {
      $sess = Get-Sess $id
      if (-not $sess -or $sess.Base -ne $now) { Send $s 404 @{ ok = $false; reason = 'no session' }; return }
    }
    $isNew = -not $sess
    if ($isNew) {
      $id = ([guid]::NewGuid().ToString('N')).Substring(0, 12)
      $dir = Join-Path $inbox $id
      New-Item -ItemType Directory -Force -Path (Join-Path $dir 'f'), (Join-Path $dir 'd') | Out-Null
      $sess = @{ Dir = $dir; Ip = "$ip"; Pc = "$($o.pc)"; Base = $now; Need = @{}; Db = @{}; At = Get-Date; Start = Get-Date; Got = 0; GotBytes = [long]0 }
      $sessions[$id] = $sess
    }
    # the hand-over itself (FiveM closed there) lists every new file the PC has: only those count from now on
    if (-not $pre) { $sess.Need = @{} }
    foreach ($x in $files) { if (-not (Test-Path -LiteralPath (Join-Path $cache $x.n))) { $sess.Need["$($x.n)"] = [long]$x.s } }
    if (-not $pre) { $sess.Db = @{}; foreach ($x in $dbs) { $sess.Db["$($x.n)"] = [long]$x.s } }
    $fdir = Join-Path $sess.Dir 'f'
    $need = @(foreach ($k in @($sess.Need.Keys)) { $p = Join-Path $fdir $k; if (-not ((Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -eq $sess.Need[$k])) { $k } })
    [long]$all = 0; foreach ($v in @($sess.Need.Values)) { $all += $v }
    [long]$total = 0; foreach ($k in $need) { $total += $sess.Need[$k] }; foreach ($v in @($sess.Db.Values)) { $total += $v }
    $sess.At = Get-Date
    if ($all -gt $MaxOffer) { Send $s 413 @{ ok = $false; reason = 'too big' } -Quiet; Log "offer $ip $($o.pc): too big ($(Get-MB $all) MB) - session $id removed"; Remove-Session $id; return }
    if ((Get-Free) - $total -lt $KeepFree) { Send $s 503 @{ ok = $false; reason = 'disk full' } -Quiet; Log "offer $ip $($o.pc): not enough free space on $drive"; return }
    Send $s 200 @{ ok = $true; session = $id; need = @($need) }
    if ($isNew -or $need.Count -or -not $pre) {
      Log "offer $ip $($o.pc) ($(if ($pre) { 'ahead, FiveM runs there' } else { 'FiveM closed there' })): session $id$(if ($isNew) { ' (new)' }), $($files.Count) new files, $($need.Count) still to send ($(Get-MB $total) MB)$(if (-not $pre) { ", index $($dbs.Count) files" })"
    }
    return
  }
  if ($method -eq 'PUT' -and $path -match '^/fivem/put/([0-9a-f]{12})/(f|d)/([A-Za-z0-9_.\-]{1,60})$') {
    $id = $Matches[1]; $kind = $Matches[2]; $name = $Matches[3]
    $sess = Get-Sess $id
    if (-not $sess) { Send $s 404 @{ ok = $false; reason = 'no session' }; return }
    $want = if ($kind -eq 'f') { $sess.Need[$name] } else { $sess.Db[$name] }
    if ($null -eq $want -or $len -ne $want) { Send $s 400 @{ ok = $false; reason = 'not offered / size' }; return }
    $out = Join-Path (Join-Path $sess.Dir $kind) $name
    $t0 = Get-Date; [long]$done = 0; $err = ''
    $fs = [IO.File]::Create($out)
    try {
      $h2 = [long][Math]::Min($have, $len); if ($h2 -gt 0) { $fs.Write($buf, $headEnd + 4, [int]$h2); $done = $h2 }
      $chunk = New-Object byte[] 1048576
      try { while ($done -lt $len) { $n = $s.Read($chunk, 0, [int][Math]::Min($chunk.Length, $len - $done)); if ($n -le 0) { break }; $fs.Write($chunk, 0, $n); $done += $n } }
      catch { $err = $_.Exception.Message }
    } finally { $fs.Close() }
    $sess.At = Get-Date
    $sec = ((Get-Date) - $t0).TotalSeconds
    if ($done -ne $len) {
      try { [IO.File]::Delete($out) } catch { }
      Log "upload $($sess.Pc) $name broke after $([math]::Round($done/1MB,1)) of $([math]::Round($len/1MB,1)) MB in $([int]$sec) s - $(if ($err) { $err } else { 'the PC closed the connection' })"
      if (-not $err) { Send $s 400 @{ ok = $false; reason = 'short' } -Quiet }
      return
    }
    if ($kind -eq 'f') {
      $sess.Got++; $sess.GotBytes += $len
      if ($sec -gt 30) { Log "upload $($sess.Pc) $name slow: $([math]::Round($len/1MB,1)) MB in $([int]$sec) s" }
      if ($sess.Got % 250 -eq 0) { Log "upload $($sess.Pc) session $id : $($sess.Got) files ($(Get-MB $sess.GotBytes) MB) so far, $([int]((Get-Date) - $sess.Start).TotalMinutes) min" }
    }
    Send $s 200 @{ ok = $true }
    return
  }
  if ($method -eq 'POST' -and $path -match '^/fivem/drop/([0-9a-f]{12})$') {
    $id = $Matches[1]; $sess = Get-Sess $id
    if ($sess) { Log "session $id ($($sess.Pc)): dropped by the PC"; Remove-Session $id }
    Send $s 200 @{ ok = $true }; return
  }
  if ($method -eq 'POST' -and $path -match '^/fivem/commit/([0-9a-f]{12})$') {
    $id = $Matches[1]; $sess = Get-Sess $id
    if (-not $sess) { Send $s 404 @{ ok = $false; reason = 'no session' }; return }
    if (-not $sess.Db.Count) { Send $s 400 @{ ok = $false; reason = 'no index offered' }; return }
    $missing = @(foreach ($k in $sess.Need.Keys) { $p = Join-Path (Join-Path $sess.Dir 'f') $k; if (-not (Test-Path -LiteralPath $p) -or (Get-Item -LiteralPath $p).Length -ne $sess.Need[$k]) { $k } }) +
               @(foreach ($k in $sess.Db.Keys) { $p = Join-Path (Join-Path $sess.Dir 'd') $k; if (-not (Test-Path -LiteralPath $p) -or (Get-Item -LiteralPath $p).Length -ne $sess.Db[$k]) { $k } })
    if ($missing.Count) { Send $s 400 @{ ok = $false; reason = "missing $($missing.Count)" }; return }
    if ((Get-Fingerprint (Join-Path $cache 'db')) -ne $sess.Base) { Send $s 409 @{ ok = $false; reason = 'stale' } -Quiet; Log "commit $ip $($sess.Pc): stale (someone else was faster)"; Remove-Session $id; return }
    if (Test-FiveMRunning) { Send $s 503 @{ ok = $false; reason = 'busy' } -Quiet; Log "commit $ip $($sess.Pc): FiveM runs on the master - later"; return }
    [long]$mb = 0; foreach ($v in @($sess.Need.Values)) { $mb += $v }
    try { $added = Invoke-Adopt $sess } catch { Send $s 400 @{ ok = $false; reason = "adopt failed: $($_.Exception.Message)" } -Quiet; Log "commit $ip $($sess.Pc): FAILED $($_.Exception.Message)"; return }
    $pc = $sess.Pc; $min = [int]((Get-Date) - $sess.Start).TotalMinutes
    Remove-Session $id
    $nb = Get-Fingerprint (Join-Path $cache 'db')
    Send $s 200 @{ ok = $true; base = $nb; added = $added }
    Log "commit $ip $($pc): taken - $added new server files ($(Get-MB $mb) MB, session of $min min) + its index (index now $nb)"
    # every other session started from the old index: it can never be taken now
    $others = @($sessions.Keys)
    foreach ($k in $others) { Log "session $k ($($sessions[$k].Pc)): stale now - removed"; Remove-Session $k }
    return
  }
  Send $s 404 @{ ok = $false; reason = 'not found' }
}

$listener = New-Object Net.Sockets.TcpListener($(if ($AllowLoopback) { [Net.IPAddress]::Loopback } else { [Net.IPAddress]::Any }), $Port)
# 18 Nov 2026: the port may still be taken for a moment (an older listener) - try for 5 minutes, then stop (no busy loop)
$started = $false
for ($try = 0; $try -lt 30 -and -not $started; $try++) { try { $listener.Start(); $started = $true } catch { Start-Sleep -Seconds 10 } }
if (-not $started) { Write-Host "cannot listen on port $Port"; exit 1 }
Log "listening on $Port (cache $cache) v2"
Write-Host "FiveM share: listening on $Port (cache $cache)"
$count = 0
while ($true) {
  try { $c = $listener.AcceptTcpClient() } catch { Start-Sleep -Seconds 1; continue }
  try { Handle $c } catch { Log "error: $($_.Exception.Message) ($($script:req))" } finally { try { $c.Close() } catch { } }
  $count++
  if ($MaxRequests -gt 0 -and $count -ge $MaxRequests) { break }
}
$listener.Stop()
