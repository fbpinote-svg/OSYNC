# Client-GameStart.ps1 - start a game the way iPlay does (iPlay's anti-cheat guide, rules 2, 4 and 6), for the menu cards in
# Settings\game-start.json (the menu runs System\Client\GameStart.vbs <card id>, which runs this):
#   6  close copies of the game / its anti-cheat that hang from before (a hung copy makes the anti-cheat refuse a new start)
#   4  check the PC is ready the way the anti-cheat wants it (nothing is skipped or switched off); not ready = the customer is
#      told why and can still try
#   2  then the publisher's launcher starts the game exactly as before (the card's old command, games.json "direct")
# Never touches game files. Log: C:\Users\Public\OSYNC-GameStart.log; a short line also goes to the master (port 4670).
#   Client-GameStart.ps1 -Id steam-1172470            what the menu does
#   Client-GameStart.ps1 -Id steam-1172470 -Check     only the checks, prints them, starts / closes nothing (tests)
param([Parameter(Mandatory = $true)][string]$Id, [switch]$Check)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Continue'
$log = Join-Path $env:PUBLIC 'OSYNC-GameStart.log'
$lines = New-Object System.Collections.Generic.List[string]
function Note([string]$s) {
  $lines.Add($s); Write-Output $s
  try { [IO.File]::AppendAllText($log, ('{0} {1} {2}{3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Id, $s, "`r`n")) } catch { }
}
function Get-Ver([string]$p) { $v = "$((Get-Item -LiteralPath $p -ErrorAction SilentlyContinue).VersionInfo.FileVersion)" -replace ',', '.' -replace '\s.*$', ''; if ($v -as [version]) { [version]$v } else { [version]'0.0' } }

$cat = try { (Get-Content -LiteralPath (Join-Path $SettingsDir 'game-start.json') -Raw -Encoding UTF8 | ConvertFrom-Json).games.$Id } catch { $null }
# (PS 5.1: ConvertFrom-Json hands the whole array on as ONE object - put it in a variable first, then filter)
$all = try { Get-Content -LiteralPath (Join-Path $Menu 'data\games.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { @() }
$card = @($all) | Where-Object { $_.id -eq $Id } | Select-Object -First 1
$name = if ($cat -and $cat.name) { $cat.name } elseif ($card) { $card.title } else { $Id }
$direct = if ($card -and $card.direct) { "$($card.direct)" } elseif ($card -and $card.cmd -notmatch 'GameStart\.vbs') { "$($card.cmd)" } else { '' }
if (-not $direct -and $cat -and $cat.steamApp) { $sd = Get-SteamDir; if ($sd) { $direct = '"' + (Join-Path $sd 'steam.exe') + '" -applaunch ' + $cat.steamApp } }
Note ("start {0} on {1}{2}" -f $name, $env:COMPUTERNAME, $(if ($Check) { ' (check only)' } else { '' }))

# the game folder (Steam: appmanifest in the libraries) - for the EA AntiCheat installer version
$gameDir = ''
if ($cat -and $cat.steamApp) {
  foreach ($l in Get-SteamLibraries) {
    $acf = Join-Path $l "steamapps\appmanifest_$($cat.steamApp).acf"
    if (Test-Path -LiteralPath $acf) { $d = [regex]::Match([IO.File]::ReadAllText($acf), '"installdir"\s+"([^"]+)"').Groups[1].Value; $gameDir = Join-Path $l "steamapps\common\$d"; break }
  }
}

# ---- 6: hung copies from before -------------------------------------------------------------------------------------------
$killed = @()
if ($cat -and $cat.kill) {
  $names = @($cat.kill | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension("$_") })
  $gameUp = $false
  foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName })) {
    $age = try { ((Get-Date) - $p.StartTime).TotalSeconds } catch { 999 }
    $win = $p.MainWindowHandle -ne [IntPtr]::Zero
    $hung = $win -and -not $p.Responding
    # a copy that is playing (has a window that answers) or is still starting (under 45 s) is left alone: Steam brings it up
    if ($age -lt 45 -or ($win -and -not $hung)) { $gameUp = $true; Note ("running, left alone: {0} pid {1} ({2:N0} s, window={3})" -f $p.ProcessName, $p.Id, $age, $win); continue }
    if ($Check) { Note ("would close hung copy: {0} pid {1} ({2:N0} s, window={3}, responding={4})" -f $p.ProcessName, $p.Id, $age, $win, $p.Responding); continue }
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $killed += $p.ProcessName; Note ("Terminated stuck instance: {0} pid {1} ({2:N0} s)" -f $p.ProcessName, $p.Id, $age) }
    catch { Note "could not close $($p.ProcessName) pid $($p.Id): $($_.Exception.Message)" }
  }
  # the anti-cheat service still running with no game = left from before; it starts again with the game
  if (-not $gameUp) {
    foreach ($s in @($cat.stopServices)) {
      if (-not $s) { continue }
      $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
      if ($svc -and $svc.Status -ne 'Stopped') {
        if ($Check) { Note "would stop service $s ($($svc.Status))"; continue }
        try { Stop-Service -Name $s -Force -ErrorAction Stop; Note "stopped service left running: $s" } catch { Note "could not stop $s : $($_.Exception.Message)" }
      }
    }
  }
  if ($killed) { Start-Sleep -Seconds 2 }
}

# ---- 4: is the PC ready for the anti-cheat? --------------------------------------------------------------------------------
$problems = New-Object System.Collections.Generic.List[string]     # Thai, for the customer / staff
foreach ($c in @($cat.checks)) {
  switch ("$c") {
    'ea_anticheat' {
      $svc = Get-CimInstance Win32_Service -Filter "Name='EAAntiCheatService'" -ErrorAction SilentlyContinue
      $exe = if ($svc) { [regex]::Match("$($svc.PathName)", '^"?([^"]+?\.exe)').Groups[1].Value } else { '' }
      $have = if ($exe -and (Test-Path -LiteralPath $exe)) { Get-Ver $exe } else { [version]'0.0' }
      $inst = if ($gameDir) { Join-Path $gameDir 'EAAntiCheat.Installer.exe' } else { '' }
      $want = if ($inst -and (Test-Path -LiteralPath $inst)) { Get-Ver $inst } else { [version]'0.0' }
      Note ("check ea_anticheat: service {0} {1} | installer in the game folder {2}" -f $(if ($svc) { $svc.State } else { 'MISSING' }), $have, $want)
      if (-not $svc -or $have -eq [version]'0.0') { $problems.Add('ไม่มีตัวกันโกง EA AntiCheat ในเครื่องนี้') }
      elseif ($want -gt $have) { Note '  older than the game folder - Steam updates it while the game starts (its install script)' }
    }
    'javelin_drivers' {
      # drivers EA's help names as blocked by Javelin, and drivers signed with an expired certificate (EA: "unrecoverable error")
      # the customer is told only about the ones EA names (CPU-Z, WinRing0); the others are only logged for the shop
      $run = @(Get-CimInstance Win32_SystemDriver -Filter "State='Running'" -ErrorAction SilentlyContinue | ForEach-Object Name)
      $deny = @($run | Where-Object { $_ -match '(?i)^(cpuz\d*|WinRing0\w*)$' })
      $info = @($run | Where-Object { $_ -match '(?i)^(WOVAD|RTCore64|GLCKIO2|AsIO\d*|gdrv|NTIOLib\w*)$' })
      Note ("check javelin_drivers: {0}{1}" -f $(if ($deny) { 'LOADED ' + ($deny -join ', ') } else { 'none of EA''s list loaded' }), $(if ($info) { " | also loaded (expired-certificate / tuning drivers): $($info -join ', ')" } else { '' }))
      if ($deny) {
        $problems.Add("มีไดรเวอร์ที่ตัวกันโกง EA Javelin ห้ามโหลดอยู่: $($deny -join ', ')")
        Note '  fix (shop): settings.txt ClientBlockCpuz = on (or add this PC), then reboot this PC'
      }
    }
    'no_test_signing' {
      $opt = "$((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -ErrorAction SilentlyContinue).SystemStartOptions)"
      $bad = @([regex]::Matches($opt, '(?i)\b(TESTSIGNING|DEBUG\b|DISABLE_INTEGRITY_CHECKS)') | ForEach-Object Value)
      Note ("check no_test_signing: {0}" -f $(if ($bad) { 'ON ' + ($bad -join ', ') } else { 'off' }))
      if ($bad) { $problems.Add("Windows เปิดโหมดทดสอบไดรเวอร์อยู่ ($($bad -join ', '))") }
    }
    '' { }
    default { Note "unknown check '$c' (Settings\game-start.json) - skipped" }
  }
}
if (-not $direct) { $problems.Add('ไม่รู้คำสั่งเปิดเกมนี้ (ไม่มีใน Menu\data\games.json)') }

# ---- tell the master (short line, never waits long) -----------------------------------------------------------------------
function Send-Master([string]$result) {
  $ip = Get-Setting 'MasterIP' ''; $port = Get-Setting 'ClientReportPort' '4670'
  if (-not $ip -or $Check) { return }
  $text = "OSLink report  $env:COMPUTERNAME  phase=gamestart  now=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  user=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`r`n" + ($lines -join "`r`n") + "`r`nRESULT: $result"
  try { Invoke-WebRequest -Uri "http://${ip}:${port}/oslink-report" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($text)) -ContentType 'text/plain; charset=utf-8' -UseBasicParsing -TimeoutSec 4 | Out-Null } catch { }
}

if ($Check) { Note ("RESULT: {0}" -f $(if ($problems.Count) { 'NOT READY - ' + ($problems -join ' | ') } else { 'READY' })); Note "would run: $direct"; return }

if ($problems.Count) {
  $msg = "$name อาจเปิดไม่ได้บนเครื่องนี้`n`n- " + ($problems -join "`n- ") + "`n`nแจ้งพนักงานได้เลยครับ`n`nลองเปิดต่อไหม? (ไม่ตอบใน 30 วินาที = เปิดต่อ)"
  $answer = try { (New-Object -ComObject WScript.Shell).Popup($msg, 30, "$name - เช็กเครื่องก่อนเปิดเกม", 4 + 48 + 4096) } catch { -1 }   # Yes/No, warning, on top
  Note ("not ready: {0} -> customer answered {1}" -f ($problems -join ' | '), $(switch ($answer) { 6 { 'open anyway' } 7 { 'do not open' } default { 'no answer (open)' } }))
  if ($answer -eq 7) { Send-Master 'NOT STARTED (customer chose not to)'; return }
}

# ---- 2: the publisher's launcher starts the game -----------------------------------------------------------------------
try {
  $parts = [regex]::Matches($direct, '"([^"]*)"|(\S+)') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } }
  $exe = @($parts)[0]; $rest = @($parts | Select-Object -Skip 1)
  if ($exe -match '^[a-z0-9+.-]+://') { Start-Process $exe } else { Start-Process -FilePath $exe -ArgumentList $rest -WorkingDirectory (Split-Path -Parent $exe) }
  Note "started: $direct"
  Send-Master $(if ($problems.Count) { 'STARTED (not ready: ' + ($problems -join ' | ') + ')' } else { 'STARTED (ready)' })
} catch {
  Note "could not start: $($_.Exception.Message)"
  Send-Master "FAIL $($_.Exception.Message)"
  try { (New-Object -ComObject WScript.Shell).Popup("เปิด $name ไม่ได้: $($_.Exception.Message)", 15, $name, 16 + 4096) | Out-Null } catch { }
}
