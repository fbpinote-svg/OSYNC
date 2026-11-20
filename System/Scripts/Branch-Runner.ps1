# Branch-Runner.ps1 - folder 2 of the shop system: the BRANCH RUNNER on a branch's master PC (C:\AT9-Branch).
#   1 the shop web (its own folder)   2 this runner (C:\AT9-Branch)   3 OSYNC (games, launchers, menu - game drive)
# The runner keeps the master linked to the shop web - the web wakes the branch's PCs through it (Wake-on-LAN) -
# from the moment Windows starts, without anyone logging on, and shows the web link and OSYNC in one place.
#
#   C:\AT9-Branch\
#     branch-helper.ps1   the web link. It comes from the shop web, and the web can update it (admin > Branches)
#     branch.json         web address + this branch's key - administrators and SYSTEM only
#     runner.ps1          a copy of this script (status / uninstall)      osync.json   where OSYNC is on this PC
#     status.cmd          web link + OSYNC state                          uninstall.cmd  removes the runner
#     state.json, helper.log   written by the web link
#   Started by the scheduled task "CooperBranchHelper" (SYSTEM, at startup + every 5 min if it stopped) - the same
#   task the web's one-line install makes, so installing here replaces an older copy instead of running two.
#   Not on the game drive on purpose: customer PCs read the game drive, and branch.json is the branch's key.
#   Only administrators can change this folder (it runs as SYSTEM).
#
#   -Install [-Command <install line from admin > Branches>]   install, move here from ProgramData, or re-install (admin)
#   -Status                                                    print the state (no admin needed)
#   -Uninstall                                                 stop it, move the folder to C:\_<delete-ok> (admin)
#   -OsyncRoot <folder>   the OSYNC folder to show (default: the OSYNC this script is in, or osync.json)
# Plain ASCII on purpose (Windows PowerShell 5.1 reads BOM-less files as ANSI).
param([switch]$Install, [string]$Command = '', [switch]$Status, [switch]$Uninstall, [string]$OsyncRoot = '', [switch]$Yes)

$ErrorActionPreference = 'Stop'
$Dir      = Join-Path $env:SystemDrive 'AT9-Branch'
$OldDir   = Join-Path $env:ProgramData 'CooperBranch'
$TaskName = 'CooperBranchHelper'
$Helper   = Join-Path $Dir 'branch-helper.ps1'
$CfgPath  = Join-Path $Dir 'branch.json'
$StateP   = Join-Path $Dir 'state.json'
$Trash    = Join-Path ($env:SystemDrive + '\') ('_' + [string]::new([char[]](0x0E25, 0x0E1A, 0x0E44, 0x0E14, 0x0E49)))   # C:\_<delete-ok> (Thai name the shop uses)
$PsExe    = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Test-Admin { (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }
function Get-NowMs { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Read-Json([string]$p) { try { ConvertFrom-Json ([IO.File]::ReadAllText($p)) } catch { $null } }
function Inner([object]$e) { while ($e.InnerException) { $e = $e.InnerException }; [string]$e.Message }

# OSYNC folder: -OsyncRoot, else the OSYNC this script lives in (System\Scripts), else what the install wrote down
function Get-OsyncRoot {
  if ($OsyncRoot) { return $OsyncRoot.TrimEnd('\') }
  $up = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  if ($up -and (Test-Path -LiteralPath (Join-Path $up 'OSYNC.bat'))) { return $up }
  $o = Read-Json (Join-Path $Dir 'osync.json')
  if ($o -and $o.root) { return [string]$o.root }
  ''
}

# stop every copy of the web link: the task, the pids it wrote down (here and in the old ProgramData folder), strays
function Stop-Helpers {
  try { & schtasks.exe /end /tn $TaskName 2>$null | Out-Null } catch { }
  foreach ($sp in @($StateP, (Join-Path $OldDir 'state.json'))) {
    $s = Read-Json $sp
    if ($s -and $s.pid -and [int]$s.pid -ne $PID) { Stop-Process -Id ([int]$s.pid) -Force -ErrorAction SilentlyContinue }
  }
  try {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction Stop |
      Where-Object { $_.ProcessId -ne $PID -and [string]$_.CommandLine -like '*branch-helper.ps1*' -and [string]$_.CommandLine -notlike '*-Status*' -and [string]$_.CommandLine -notlike '*-Uninstall*' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  } catch { }
}

# move a folder to C:\_<delete-ok>\<name>-<stamp> (nothing is deleted - the owner empties that folder)
function Move-ToTrash([string]$path, [string]$name) {
  New-Item -ItemType Directory -Force -Path $Trash | Out-Null
  $dest = Join-Path $Trash ('{0}-{1:yyyyMMdd-HHmm}' -f $name, (Get-Date))
  Move-Item -LiteralPath $path -Destination $dest
  $dest
}

function Write-Ascii([string]$path, [string[]]$lines) { [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII) }

# ================================================================ -Status
function Show-Status {
  Say "AT9 branch runner   $Dir" Cyan
  if (Test-Path -LiteralPath $Helper) {
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File $Helper -Status
  } else {
    Say '  Not installed on this PC.' Yellow
    if (Test-Path -LiteralPath (Join-Path $OldDir 'branch-helper.ps1')) { Say "  An older copy is in $OldDir - move it here: OSYNC.bat > 7 Tools > 20 (needs a new install line)" Yellow }
    else { Say '  Branches only: OSYNC.bat > 7 Tools > 20 with the install line from admin page > Branches' }
  }

  $root = Get-OsyncRoot
  Say ''
  Say "OSYNC   $(if ($root) { $root } else { '(not found on this PC)' })" Cyan
  if (-not $root -or -not (Test-Path -LiteralPath $root)) { return }
  $ver = Join-Path $root 'System\VERSION.txt'
  if (Test-Path -LiteralPath $ver) { Say ('  Version    : {0}' -f ((Get-Content -LiteralPath $ver -TotalCount 1).Trim())) }
  try {
    $d = New-Object IO.DriveInfo ($root.Substring(0, 1))
    $free = [math]::Round($d.AvailableFreeSpace / 1GB); $size = [math]::Round($d.TotalSize / 1GB)
    $c = if ($free -lt 10) { 'Red' } elseif ($free -lt 50) { 'Yellow' } else { 'Gray' }
    Say ('  Game drive : {0}: {1} GB free of {2} GB{3}' -f $d.Name.Substring(0, 1), $free, $size, $(if ($free -lt 50) { ' - running out of space' })) $c
  } catch { }
  $w = @()
  try { $w = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop | Where-Object { [string]$_.CommandLine -like '*Master-Watch.ps1*' -and [string]$_.CommandLine -notlike '*-Register*' }) } catch { }
  if ($w) { Say '  Watcher    : running (updates clients by itself)' } else { Say '  Watcher    : not running - it starts when this PC logs on (OSYNC.bat > 2)' Yellow }
  $lw = @(Get-Service -Name 'lwdiskless*' -ErrorAction SilentlyContinue)
  if ($lw) { Say ('  Diskless   : ' + (($lw | ForEach-Object { '{0} {1}' -f $_.Name, $_.Status }) -join ', ')) }
  $gj = Join-Path $root 'Menu\data\games.json'
  if (Test-Path -LiteralPath $gj) {
    $n = 0; try { $n = @((Get-Content -LiteralPath $gj -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ }).Count } catch { }
    Say ('  Game list  : {0} games, made {1:yyyy-MM-dd HH:mm}' -f $n, (Get-Item -LiteralPath $gj).LastWriteTime)
  }
}

if ($Status) { Show-Status; exit 0 }

# ================================================================ -Uninstall
if ($Uninstall) {
  if (-not (Test-Admin)) { Say 'Needs administrator rights: run uninstall.cmd (it asks), or OSYNC.bat > 7 Tools > 22.' Red; exit 1 }
  Stop-Helpers
  try { & schtasks.exe /delete /tn $TaskName /f 2>$null | Out-Null } catch { }
  Say "Removed the startup task $TaskName."
  if (Test-Path -LiteralPath $Dir) {
    Set-Location -LiteralPath $env:SystemRoot
    Start-Sleep -Seconds 1
    try { $to = Move-ToTrash $Dir 'AT9-Branch'; Say "Moved $Dir to $to (nothing deleted)." }
    catch {
      # a window still open in that folder (status.cmd / uninstall.cmd): move it a few seconds after this window closes
      $dest = Join-Path $Trash ('AT9-Branch-{0:yyyyMMdd-HHmm}' -f (Get-Date))
      $cmd = "Start-Sleep 5; New-Item -ItemType Directory -Force -Path '$Trash' | Out-Null; Move-Item -LiteralPath '$Dir' -Destination '$dest'"
      Start-Process -FilePath $PsExe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))) -WindowStyle Hidden
      Say "$Dir is moved to $dest a few seconds after this window closes."
    }
  }
  Say 'Done. The branch stays in the admin page, and its key works until you delete the branch there or install again.' Green
  exit 0
}

# ================================================================ -Install
if (-not $Install) {
  Say 'Use -Install, -Status or -Uninstall (or OSYNC.bat > 7 Tools > 20 / 21 / 22).' Yellow
  exit 1
}
if (-not (Test-Admin)) { Say 'Needs administrator rights: OSYNC.bat > 7 Tools > 20 asks for them.' Red; exit 1 }

Say 'Branch runner: links this master to the shop web, so the web can wake this branch''s PCs.' Cyan
Say "It goes in $Dir and starts with Windows (no logon needed)."
if (-not $Command) {
  if ($Yes) { Say 'No install line given (-Command).' Red; exit 1 }
  Say ''
  Say 'Admin page > Branches > the branch > "install command" - copy the whole line and paste it here.'
  $Command = Read-Host 'Install line (Enter = cancel)'
}
$m = [regex]::Match([string]$Command, '(?i)(https?://[^\s/''"`;|]+)/api/branch/setup/([A-Za-z0-9_-]{20,64})')
if (-not $m.Success) { Say 'That is not the install line from admin page > Branches (it has .../api/branch/setup/<code>). Nothing changed.' Red; exit 1 }
$server = $m.Groups[1].Value.TrimEnd('/'); $code = $m.Groups[2].Value

# everything that can fail BEFORE the code is used up (using it switches the branch to the new key at once)
try {
  if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { throw 'the Task Scheduler commands are missing on this Windows' }
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  # SYSTEM runs these files: only administrators may change them (C:\ lets every user change new folders by default)
  & icacls.exe $Dir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "could not set the permissions of $Dir" }
} catch { Say ("Setup stopped, nothing installed: " + (Inner $_.Exception)) Red; exit 1 }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }
Say "[1/4] Getting the web link from $server ..." Cyan
try {
  $body = @{ host = $env:COMPUTERNAME } | ConvertTo-Json -Compress
  $r = Invoke-RestMethod -Method Post -Uri "$server/api/branch/setup/$code/redeem" -Body $body -ContentType 'application/json' -TimeoutSec 30 -UseBasicParsing
} catch { Say ("Could not reach the shop web: " + (Inner $_.Exception) + ' - check the internet, then try again (the line still works if it is under 15 min old).') Red; exit 1 }
if (-not $r -or -not $r.ok) { Say ("The shop web said: " + [string]$r.error) Red; exit 1 }
$bytes = [Convert]::FromBase64String([string]$r.script)
$sum = -join ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
if ($sum -ne [string]$r.sha256) { Say 'The download was damaged (sha256 mismatch). Make a new install line in the admin page and run this again.' Red; exit 1 }

Say "[2/4] Installing web link $($r.version) for branch '$($r.name)' ..." Cyan
Stop-Helpers
[IO.File]::WriteAllBytes($Helper, $bytes)
[IO.File]::WriteAllText($CfgPath, (@{ server = $server; token = [string]$r.token; name = [string]$r.name; branchId = [int]$r.id } | ConvertTo-Json -Compress))
& icacls.exe $CfgPath /inheritance:r /grant:r '*S-1-5-32-544:(F)' '*S-1-5-18:(F)' | Out-Null
$root = Get-OsyncRoot
[IO.File]::WriteAllText((Join-Path $Dir 'osync.json'), (@{ root = $root } | ConvertTo-Json -Compress))
if ($PSCommandPath -ne (Join-Path $Dir 'runner.ps1')) { Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $Dir 'runner.ps1') -Force }
$runPs = '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0runner.ps1"'
Write-Ascii (Join-Path $Dir 'status.cmd') @('@echo off', 'cd /d "%SystemRoot%"', "$runPs -Status", 'pause')
Write-Ascii (Join-Path $Dir 'uninstall.cmd') @('@echo off', 'net session >nul 2>&1 || (powershell -NoProfile -Command "Start-Process -FilePath ''%~f0'' -Verb RunAs" & exit /b)', 'cd /d "%SystemRoot%"', "$runPs -Uninstall", 'pause')
Write-Ascii (Join-Path $Dir 'README.txt') @(
  'AT9 branch runner - links this branch''s master PC to the shop web (the web wakes this branch''s PCs through it).',
  'It starts with Windows (task CooperBranchHelper, runs as SYSTEM) - nobody needs to log on.',
  '',
  '  status.cmd      is it connected? + OSYNC state',
  '  uninstall.cmd   remove it (the folder is moved to C:\_<delete-ok>, nothing deleted)',
  '  branch.json     this branch''s key - never copy it to another PC or share it',
  '',
  'Install again / move to another PC: admin page > Branches > new install line, then OSYNC.bat > 7 Tools > 20.',
  "OSYNC (games, launchers, menu): $root")

Say '[3/4] Startup task (SYSTEM, at startup + every 5 min if it stopped) ...' Cyan
$act = New-ScheduledTaskAction -Execute $PsExe -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Helper + '"') -WorkingDirectory $Dir
$t1 = New-ScheduledTaskTrigger -AtStartup
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$st = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger @($t1, $t2) -Principal $pr -Settings $st -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

Say '[4/4] Connecting to the shop web ...' Cyan
$ok = $false; $err = ''
for ($i = 0; $i -lt 25; $i++) {
  Start-Sleep -Seconds 1
  $s = Read-Json $StateP
  if ($s -and $s.connected -and [int]$s.pid -ne 0) { $ok = $true; break }
  if ($s) { $err = [string]$s.lastError }
}
if (Test-Path -LiteralPath $OldDir) {
  try { $to = Move-ToTrash $OldDir 'CooperBranch-old'; Say "  the older copy ($OldDir) was moved to $to" }
  catch { Say "  could not move the older copy $OldDir ($(Inner $_.Exception)) - it no longer runs; move it by hand" Yellow }
}
if ($ok) { Say "OK - connected as branch '$($r.name)'. State: $Dir\status.cmd, or OSYNC.bat > 7 Tools > 21, or admin page > Branches." Green; exit 0 }
Say "Installed, but not connected yet ($err). It keeps trying by itself - check with $Dir\status.cmd." Yellow
exit 0
