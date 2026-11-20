# SteamQueue-Lib.ps1 - Steam game requests from the client menu ("ขอเกม Steam", 19 Nov 2026, the owner wanted ComOom's
# download queue in our system). Shared by:
#   Master-ClientReports.ps1  the LAN listener (port ClientReportPort 4670): POST /steam/request, GET /steam/job, POST /steam/cancel
#   Master-SteamQueue.ps1     the worker: DepotDownloader with the customer's own Steam QR sign-in -> SHA1 check -> SteamLibrary
# Jobs: C:\ProgramData\OSYNC\SteamQueue\jobs\<id>.json (one writer each: the listener writes a new job and <id>.cancel, the
# worker writes the job afterwards). Settings (settings.txt, all optional):
#   SteamRequests=on|off (default on)   SteamRequestMinFreeGB=30 (free space that must stay on the drive after the game)
#   SteamRequestDrives=DEFGIJ (default: the shared drives with a Steam library)   SteamRequestQrMinutes=5
$SqDir    = Join-Path $env:ProgramData 'OSYNC\SteamQueue'
$SqJobs   = Join-Path $SqDir 'jobs'
$SqActive = @('queued', 'checking', 'waiting-qr', 'downloading', 'verifying', 'importing')
$SqWorkerMutex = 'Global\OSYNC-SteamQueue-Worker'
$SqUtf8 = New-Object Text.UTF8Encoding($false)

function Get-SqSettings {
  $drv = ((Get-Setting 'SteamRequestDrives' '') -replace '[^A-Za-z]', '').ToUpper()
  if (-not $drv) { $drv = Get-SharedDrives }
  [pscustomobject]@{
    On        = (Get-Setting 'SteamRequests' 'on') -notmatch '^(?i)(off|no|0|false)$'
    MinFreeGB = [int](Get-Setting 'SteamRequestMinFreeGB' '30')
    Drives    = $drv
    QrMinutes = [int](Get-Setting 'SteamRequestQrMinutes' '5')
    Exe       = Join-Path $ToolsDir 'DepotDownloader\DepotDownloader.exe'
  }
}

# "570", "https://store.steampowered.com/app/570/Dota_2/", "steam://rungameid/570" -> 570 (0 = not understood)
function ConvertFrom-SqAppText([string]$Text) {
  $t = "$Text".Trim()
  if ($t -match '^\d{1,9}$') { return [int]$t }
  if ($t -match '(?i)(?:store\.steampowered\.com|steamcommunity\.com|steamdb\.info)/app/(\d{1,9})') { return [int]$Matches[1] }
  if ($t -match '(?i)steam://(?:run|rungameid|install|store|nav/games/details)/(\d{1,9})') { return [int]$Matches[1] }
  if ($t -match '(?i)/app/(\d{1,9})') { return [int]$Matches[1] }
  0
}

function Read-SqJob([string]$Path) {
  for ($i = 0; $i -lt 3; $i++) {
    try { return ([IO.File]::ReadAllText($Path, $SqUtf8) | ConvertFrom-Json) } catch { Start-Sleep -Milliseconds 60 }
  }
  $null
}
function Write-SqJob($Job) {
  New-Item -ItemType Directory -Force -Path $SqJobs | Out-Null
  $Job.updated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $p = Join-Path $SqJobs "$($Job.id).json"; $tmp = "$p.tmp"
  [IO.File]::WriteAllText($tmp, ($Job | ConvertTo-Json -Depth 6 -Compress), $SqUtf8)
  # [NullString]::Value: PowerShell turns $null into '' for a string argument, which Replace refuses
  if (Test-Path -LiteralPath $p) { [IO.File]::Replace($tmp, $p, [NullString]::Value) } else { [IO.File]::Move($tmp, $p) }
}
function Get-SqJobs {
  if (-not (Test-Path -LiteralPath $SqJobs)) { return @() }
  @(Get-ChildItem -LiteralPath $SqJobs -Filter '*.json' -File | Sort-Object Name | ForEach-Object { Read-SqJob $_.FullName } | Where-Object { $_ })
}
function Test-SqCancel($Job) { Test-Path -LiteralPath (Join-Path $SqJobs "$($Job.id).cancel") }

# what a client may see of a job (no paths of the master, no log)
function Get-SqView($Job, $All) {
  if (-not $Job) { return $null }
  $pos = 0
  if ($Job.state -eq 'queued') { $pos = 1 + @($All | Where-Object { $SqActive -contains $_.state -and $_.id -lt $Job.id }).Count }
  [ordered]@{ id = $Job.id; app = $Job.app; name = $Job.name; state = $Job.state; message = $Job.message; progress = $Job.progress
    queuePos = $pos; qr = $(if ($Job.state -eq 'waiting-qr') { $Job.qr } else { $null }); qrUntil = $Job.qrUntil
    sizeGB = $Job.sizeGB; drive = $Job.drive; created = $Job.created; updated = $Job.updated }
}

function Start-SqWorker {
  $m = $null
  if ([Threading.Mutex]::TryOpenExisting($SqWorkerMutex, [ref]$m)) { $m.Dispose(); return }
  $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  Start-Process -FilePath $ps -WindowStyle Hidden -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $ScriptsDir 'Master-SteamQueue.ps1') + '"'))
}

# the listener's /steam/* calls -> @{ code; body (hashtable -> JSON) }
function Invoke-SqApi([string]$Method, [string]$Path, [string]$Body, [string]$Ip) {
  $set = Get-SqSettings
  $all = Get-SqJobs
  $mine = @($all | Where-Object { $_.ip -eq $Ip })
  $active = $mine | Where-Object { $SqActive -contains $_.state } | Select-Object -Last 1
  switch ($Path) {
    '/steam/job' {
      $j = $active
      if (-not $j) { $j = $mine | Where-Object { $_.created -and ((Get-Date) - [datetime]$_.created).TotalHours -lt 12 } | Select-Object -Last 1 }
      if ($active) { Start-SqWorker }   # a worker that stopped is started again (it fails the job it cannot go on with)
      return @{ code = 200; body = @{ ok = $true; on = $set.On; job = (Get-SqView $j $all) } }
    }
    '/steam/cancel' {
      if ($Method -ne 'POST') { return @{ code = 405; body = @{ ok = $false; message = 'POST only' } } }
      if (-not $active) { return @{ code = 200; body = @{ ok = $true; message = 'ไม่มีงานที่ค้างอยู่' } } }
      [IO.File]::WriteAllText((Join-Path $SqJobs "$($active.id).cancel"), (Get-Date).ToString('s'))
      Start-SqWorker
      return @{ code = 200; body = @{ ok = $true; message = 'กำลังยกเลิก' } }
    }
    '/steam/request' {
      if ($Method -ne 'POST') { return @{ code = 405; body = @{ ok = $false; message = 'POST only' } } }
      if (-not $set.On) { return @{ code = 200; body = @{ ok = $false; message = 'ร้านปิดระบบขอเกมไว้ แจ้งพนักงานได้เลย' } } }
      if ($active) { return @{ code = 200; body = @{ ok = $true; message = 'เครื่องนี้มีคำขออยู่แล้ว'; job = (Get-SqView $active $all) } } }
      $req = $null; try { $req = $Body | ConvertFrom-Json } catch { }
      $app = ConvertFrom-SqAppText "$($req.app)"
      if (-not $app) { return @{ code = 200; body = @{ ok = $false; message = 'ใส่ลิงก์หน้าเกม Steam หรือเลข AppID (เช่น https://store.steampowered.com/app/570)' } } }
      $other = $all | Where-Object { $SqActive -contains $_.state -and $_.app -eq $app } | Select-Object -First 1
      if ($other) { return @{ code = 200; body = @{ ok = $false; message = "เกมนี้กำลังโหลดให้เครื่อง $($other.pc) อยู่แล้ว รอสักครู่แล้วรีบูตเครื่องเพื่อเล่น" } } }
      if (@($all | Where-Object { $SqActive -contains $_.state }).Count -ge 10) { return @{ code = 200; body = @{ ok = $false; message = 'คิวเต็ม (10 งาน) ลองใหม่ภายหลัง' } } }
      $pc = ("$($req.pc)" -replace '[^A-Za-z0-9_.-]', ''); if ($pc.Length -gt 32) { $pc = $pc.Substring(0, 32) }; if (-not $pc) { $pc = $Ip }
      $now = Get-Date
      $job = [ordered]@{ id = ('{0}-{1}-{2}' -f $now.ToString('yyyyMMdd-HHmmss'), $app, ($Ip -replace '^.*\.', '')); app = $app; name = ''; pc = $pc; ip = $Ip
        created = $now.ToString('yyyy-MM-dd HH:mm:ss'); updated = ''; state = 'queued'; message = 'รอคิว'; progress = 0; qr = $null; qrUntil = ''
        sizeGB = 0; drive = ''; installdir = ''; error = '' }
      Write-SqJob ([pscustomobject]$job)
      Start-SqWorker
      $all = Get-SqJobs
      return @{ code = 200; body = @{ ok = $true; message = 'ส่งคำขอแล้ว'; job = (Get-SqView ($all | Where-Object { $_.id -eq $job.id } | Select-Object -First 1) $all) } }
    }
  }
  @{ code = 404; body = @{ ok = $false; message = 'not found' } }
}
