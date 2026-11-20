# Client-FiveMShare.ps1 - CLIENT PC: hands the FiveM servers' files this PC downloads to the master (Master-FiveMShare.ps1), so
# every client has them after its next boot (18 Nov 2026, the owner's idea). Started hidden by Client-Install at boot (Settings
# ClientFiveMShare=on); runs in the background for up to 16 hours:
#   at start   the fingerprint of FiveM's index (<FiveM>.app\data\server-cache-priv\db) as the master has it - this PC's FiveM
#              then only adds to it (FiveM already running at start = this boot does not take part)
#   while FiveM RUNS (every 30 s): the new server files FiveM finished saving (cache_<sha1>, unchanged for 3 min) are sent
#              AHEAD, gently (at most 25 MB/s), so little is left to send when FiveM is closed (a PC is often restarted soon after)
#   when FiveM is CLOSED (2 looks 20 s apart): the rest of the new files + FiveM's index -> the master takes them when its index
#              is still the one this PC started from ("stale" = another PC was faster: nothing more this boot)
# Only the servers' files and FiveM's index are sent - no sign-in, no game settings. LAN only. Never on the master.
# Log: C:\Users\Public\OSYNC-FiveMShare.log - every line also goes to the master's log (<drive>:\_osync-fivem-incoming\server.log),
#   because this PC's own log is gone after its reboot (v2, 18 Nov 2026: KORI19 offered 1.5 GB at 17:16, restarted at 17:24 with
#   nothing arrived, and nothing was left to tell why).
# Tests: -CacheDir <server-cache-priv> -Master <host:port> -Once (one look, no waiting) -Since <time> (instead of the boot time)
#        -Base <fingerprint> (instead of reading it at start) -Running yes|no|file:<path> (pretend FiveM runs / is closed; the
#        file holds yes or no) -AheadAge <s> -AheadMBps <n>
param([string]$CacheDir = '', [string]$Master = '', [switch]$Once, [string]$Since = '', [double]$Hours = 16, [string]$Base = '',
      [string]$Running = '', [int]$AheadAge = 180, [int]$AheadMBps = 25)
. (Join-Path $PSScriptRoot 'Common.ps1')
[Net.ServicePointManager]::Expect100Continue = $false
$log = Join-Path $env:PUBLIC 'OSYNC-FiveMShare.log'
$remote = $false
function Send-Log([string]$m) {
  try {
    $rq = [Net.HttpWebRequest]::Create("http://$Master/fivem/log"); $rq.Method = 'POST'; $rq.Timeout = 15000; $rq.KeepAlive = $false; $rq.ContentType = 'application/json'
    $b = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @{ pc = $env:COMPUTERNAME; msg = $m } -Compress)); $rq.ContentLength = $b.Length
    $st = $rq.GetRequestStream(); $st.Write($b, 0, $b.Length); $st.Close(); $rq.GetResponse().Close()
  } catch { }
}
function Log([string]$m) { $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"; Write-Host $l; try { Add-Content -LiteralPath $log -Value $l -Encoding UTF8 } catch { }; if ($remote) { Send-Log $m } }
# the same message again and again (master busy, an error that stays): written once, then at the 10th and 100th time
$script:lastNote = ''; $script:noteN = 0
function Note([string]$m) {
  if ($m -eq $script:lastNote) { $script:noteN++; if ($script:noteN -eq 9 -or $script:noteN -eq 99) { Log "$m (x$($script:noteN + 1))" }; return }
  $script:lastNote = $m; $script:noteN = 0; Log $m
}
if ((Test-IsMaster) -and -not $CacheDir) { Log 'this is the master - nothing to hand over'; exit 0 }
if (-not $Master) { $Master = "$(Get-Setting 'MasterIP' ''):$(Get-Setting 'FiveMSharePort' '4671')" }
if ($Master -notmatch '^[^:]+:\d+$' -or $Master.StartsWith(':')) { Log 'no MasterIP in settings'; exit 0 }
$remote = $true
if (-not $CacheDir) {
  $app = @(Get-CfxApps | Where-Object { $_.Name -eq 'FiveM' }) | Select-Object -First 1
  if (-not $app) { Log 'FiveM not found on the game disks'; exit 0 }
  $CacheDir = Join-Path $app.App 'data\server-cache-priv'
}
$db = Join-Path $CacheDir 'db'
if (-not (Test-Path -LiteralPath $db)) { Log "no FiveM index at $db"; exit 0 }
function Get-Fingerprint([string]$dir) {
  $items = @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" })
  if (-not $items.Count) { return '' }
  $sha = [Security.Cryptography.SHA256]::Create()
  ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($items -join "`n")))) -replace '-', '').Substring(0, 32)
}
function Test-FiveMRunning {
  if ($Running -eq 'yes') { return $true }; if ($Running -eq 'no') { return $false }
  if ($Running -like 'file:*') { return ("$(Get-Content -LiteralPath $Running.Substring(5) -ErrorAction SilentlyContinue)".Trim() -eq 'yes') }
  [bool](Get-Process -Name 'FiveM', 'FiveM_*' -ErrorAction SilentlyContinue)
}
# the master's reason when it refused (its JSON {reason}), else the error itself
function Get-WebReason([Net.WebException]$e) {
  $r = $e.Response; if (-not $r) { return $e.Message }
  try { $sr = New-Object IO.StreamReader($r.GetResponseStream()); $j = $sr.ReadToEnd() | ConvertFrom-Json; $sr.Close(); $r.Close(); "master: $($j.reason)" } catch { $e.Message }
}
function Invoke-Json([string]$method, [string]$path, $obj) {
  $rq = [Net.HttpWebRequest]::Create("http://$Master$path"); $rq.Method = $method; $rq.Timeout = 30000; $rq.ReadWriteTimeout = 60000; $rq.KeepAlive = $false; $rq.ContentType = 'application/json'
  $bytes = [Text.Encoding]::UTF8.GetBytes($(if ($null -ne $obj) { ConvertTo-Json -InputObject $obj -Depth 4 -Compress } else { '' }))
  $rq.ContentLength = $bytes.Length
  if ($bytes.Length) { $st = $rq.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close() }
  try { $rs = $rq.GetResponse() } catch [Net.WebException] { $rs = $_.Exception.Response; if (-not $rs) { throw } }
  $sr = New-Object IO.StreamReader($rs.GetResponseStream()); $txt = $sr.ReadToEnd(); $sr.Close(); $rs.Close()
  $txt | ConvertFrom-Json
}
# one file to the master; -MBps > 0: no faster than that (FiveM is running here). Returns the bytes sent.
function Send-File([string]$path, [string]$url, [int]$MBps = 0) {
  $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
  try {
    $len = $fs.Length
    $rq = [Net.HttpWebRequest]::Create("http://$Master$url"); $rq.Method = 'PUT'; $rq.Timeout = 120000; $rq.ReadWriteTimeout = 120000; $rq.KeepAlive = $false
    $rq.AllowWriteStreamBuffering = $false; $rq.SendChunked = $false; $rq.ContentLength = $len
    $st = $rq.GetRequestStream()
    try {
      if ($MBps -le 0) { $fs.CopyTo($st, 1048576) }
      else {
        $buf = New-Object byte[] 1048576; [long]$sent = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
        while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
          $st.Write($buf, 0, $n); $sent += $n
          $wait = $sent / ($MBps * 1MB) - $sw.Elapsed.TotalSeconds
          if ($wait -gt 0.05) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
        }
      }
    } finally { $st.Close() }
  } finally { $fs.Close() }
  try { $rs = $rq.GetResponse(); $rs.Close() } catch [Net.WebException] { throw "$(Split-Path -Leaf $path): $(Get-WebReason $_.Exception)" }
  $len
}

$bootAt = if ($Since) { [datetime]$Since } else { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
if (Test-FiveMRunning) { Log 'FiveM is already running - this boot does not take part'; exit 0 }
$base = if ($Base) { $Base } else { Get-Fingerprint $db }
if (-not $base) { Log 'FiveM index is empty - nothing to start from'; exit 0 }
Log "start (v2): cache $CacheDir, index $base, master $Master"
$handedUpTo = $bootAt      # server files newer than this are new (moves on after each hand-over)
$session = ''              # the master's session for what was sent so far
$sentNames = @{}           # name -> length of the files the master has from this PC in that session (or had already)
$stop = $false
function Get-NewFiles { @(Get-ChildItem -LiteralPath $CacheDir -File -Filter 'cache_*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^cache_[0-9a-f]{40}$' -and $_.Length -gt 0 -and $_.LastWriteTime -gt $handedUpTo }) }
function Invoke-Offer([bool]$pre, $files, $dbFiles) {
  $body = @{ pc = $env:COMPUTERNAME; base = $base; pre = $pre; files = @($files | ForEach-Object { @{ n = $_.Name; s = $_.Length } }) }
  if (-not $pre) { $body.db = @($dbFiles | ForEach-Object { @{ n = $_.Name; s = $_.Length } }) }
  if ($session) { $body.session = $session }
  $r = Invoke-Json 'POST' '/fivem/offer' $body
  if (-not $r.ok -and $r.reason -eq 'no session' -and $session) {
    # the master restarted (or dropped it): start again - it tells which files it still needs
    $script:session = ''; $script:sentNames = @{}; $body.Remove('session')
    $r = Invoke-Json 'POST' '/fivem/offer' $body
  }
  if (-not $r.ok -and ($r.reason -eq 'stale' -or $r.reason -eq 'too big')) {
    Log "the master answers '$($r.reason)': $(if ($r.reason -eq 'stale') { 'its copy changed since this boot (another PC or the master was faster)' } else { 'more than it takes from one PC' }) - nothing more this boot"
    $script:stop = $true
  }
  $r
}
# while FiveM runs: send the finished new files ahead
function Send-Ahead {
  $cut = (Get-Date).AddSeconds(-$AheadAge)
  $ready = @(Get-NewFiles | Where-Object { $_.LastWriteTime -lt $cut -and $sentNames[$_.Name] -ne $_.Length })
  if (-not $ready.Count) { return }
  $r = Invoke-Offer $true $ready $null
  if (-not $r.ok) { if (-not $stop) { Note "send ahead: master says $($r.reason)" }; return }
  $script:session = $r.session
  $need = @{}; foreach ($n in @($r.need)) { $need["$n"] = 1 }
  foreach ($f in $ready) { if (-not $need.ContainsKey($f.Name)) { $sentNames[$f.Name] = $f.Length } }
  $t0 = Get-Date; [long]$bytes = 0; $k = 0; $errs = 0
  foreach ($f in $ready) {
    if (-not $need.ContainsKey($f.Name)) { continue }
    if (-not (Test-FiveMRunning)) { break }           # FiveM was closed: the hand-over sends the rest at full speed
    try { $bytes += Send-File $f.FullName "/fivem/put/$session/f/$($f.Name)" $AheadMBps; $sentNames[$f.Name] = $f.Length; $k++; $errs = 0 }
    catch { $errs++; Note "send ahead: $($_.Exception.Message)"; if ($errs -ge 3) { break } }
  }
  if ($k) { Log "sent ahead while FiveM runs: $k server files ($([math]::Round($bytes/1MB)) MB) in $([int]((Get-Date) - $t0).TotalSeconds) s, session $session" }
}
# FiveM closed: the rest + the index, then the master takes it
function Send-Final {
  $stamp = Get-Date
  $files = Get-NewFiles
  if (-not $files.Count) { return }
  $dbFiles = @(Get-ChildItem -LiteralPath $db -File -Force)
  $fp = Get-Fingerprint $db
  $r = Invoke-Offer $false $files $dbFiles
  if (-not $r.ok) { if (-not $stop) { Note "hand-over of $($files.Count) new server files: master says $($r.reason)" }; return }
  $script:session = $r.session
  $byName = @{}; foreach ($f in $files) { $byName[$f.Name] = $f }
  $need = @($r.need)
  Log "hand-over: $($files.Count) new server files, the master still needs $($need.Count), session $session"
  $t0 = Get-Date; [long]$bytes = 0
  foreach ($n in $need) {
    if (Test-FiveMRunning) { Log 'FiveM started again - the rest goes ahead while it runs, the index when it is closed'; return }
    $f = $byName["$n"]; if (-not $f) { throw "the master asked for $n, not offered" }
    $bytes += Send-File $f.FullName "/fivem/put/$session/f/$n"; $sentNames[$f.Name] = $f.Length
  }
  if ((Test-FiveMRunning) -or (Get-Fingerprint $db) -ne $fp) { Log 'FiveM was started again before its index was sent - later'; return }
  foreach ($d in $dbFiles) { $null = Send-File $d.FullName "/fivem/put/$session/d/$($d.Name)" }
  $c = Invoke-Json 'POST' "/fivem/commit/$session" $null
  if ($c.ok) {
    $script:base = $c.base; $script:handedUpTo = $stamp; $script:session = ''; $script:sentNames = @{}
    Log "handed over: $($files.Count) new server files ($($need.Count) sent now, $([math]::Round($bytes/1MB)) MB in $([int]((Get-Date) - $t0).TotalSeconds) s) + the index; the master took $($c.added) new"
  } else {
    Note "commit: master says $($c.reason)"
    if ($c.reason -eq 'stale') { Log 'another PC was faster - nothing more this boot'; $script:stop = $true }
  }
}

$until = (Get-Date).AddHours($Hours)
do {
  try {
    if (Test-FiveMRunning) { Send-Ahead }
    elseif ((Get-NewFiles).Count) {
      if (-not $Once) { Start-Sleep -Seconds 20 }   # FiveM restarts itself when it changes game version: closed for real?
      if (-not (Test-FiveMRunning)) { Send-Final }
    }
  } catch { Note "error: $($_.Exception.Message)" }
  if ($stop -or $Once) { break }
  Start-Sleep -Seconds 30
} while ((Get-Date) -lt $until)
Log 'stop'
