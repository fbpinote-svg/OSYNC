# Client-Install.ps1 - CLIENT PC: everything a client needs, in one run (OSYNC.bat > 5, or OSYNC.bat client).
# Run as administrator in super-workstation (image edit) mode, then save the image.
#   1 Riot   : start Riot silently at logon (prepares the PC for VALORANT / LoL / TFT)
#   2 Steam  : every Steam game's first-run setup (BattlEye, ACE, Ricochet, EasyAntiCheat, Social Club,
#              DirectX, VC++ ...) - also covers Steam games installed later
#   3 EA     : EA app, EA games and EA AntiCheat (Apex, Battlefield)
#   4 EAC    : EasyAntiCheat for games outside Steam's scripts (Fortnite, Dead by Daylight, VRChat ...)
#   5 Menu   : game menu at logon + desktop icon (through System\Client\Menu.vbs); not opened during this run - its
#              always-on-top lock screen would hide this window and the RESULT - it opens after the reboot
#   6 NT     : NEWTHINGS-GAMES (GTA SA / SA-MP) registry + shortcuts; asks first whether to fix Thai text
#              (alien letters in-game = "Beta: UTF-8" code page 65001; fix = Thai 874, restart needed)
#   7 Boot   : task OSYNC-Client-Boot (at startup, SYSTEM) runs System\Client\Boot.ps1 = this script with -Boot
#   8 Desktop: only the game menu icon stays on the desktop, other shortcuts moved aside (Client-DesktopClean.ps1;
#              also at every boot; Settings ClientDesktopMenuOnly=off skips it)
# Everything an older OSYNC folder (E:\Autosync) put in the image is replaced: Run\RiotStart, the boot task,
# the menu shortcuts and the EA registry / service now point at this folder.
# 1f Mic: WO Mic Client + VB-CABLE driver, installed silently only if missing (Client-Mic.ps1; also at every boot)
# 1g Parsec: Parsec app, installed silently only if missing (Client-Parsec.ps1; also at every boot)
# 1h GTA: GTA V / FiveM graphics from Settings\gta5_settings.xml for every profile (Client-GtaSettings.ps1; runs before 1f)
# 1i Logins: saved game logins of every user deleted (Client-ClearLogins.ps1, also Clear-Logins.bat; runs before 1f)
# 1j OSLink: the master's MAC removed from OSLink's settings on the game disk, account stays (Client-OslinkReset.ps1)
# 1k OSLink: this PC's own sign-in of the master's support account, kept on the master (Client-OslinkLogin.ps1)
# 1l OSLink: its virtual mouse / keyboard / gamepad drivers, installed silently only if missing (Client-OslinkDrivers.ps1;
#            runs before 1j - OSLink checks its drivers when it starts, 1j / 1k restart it)
# 1m OSLink: in the tray at logon, no window (task OSYNC-OslinkStart -> System\Client\OslinkStart.vbs)
# -Boot: steps 1-4 only, no questions - installs just what is new since the image was saved (new games need
#        no image edit, only a client reboot). Log: C:\Users\Public\OSYNC-Boot-Setup.log
# Log: C:\Users\Public\OSYNC-Install-All.log
param([switch]$Boot)
. (Join-Path $PSScriptRoot 'Common.ps1')
Stop-IfPreMigration 'Client install'
if (-not (Test-Admin)) { Write-Host 'Run as administrator (OSYNC.bat asks for it).' -ForegroundColor Red; exit 1 }
Start-Transcript -Path (Join-Path $env:PUBLIC $(if ($Boot) { 'OSYNC-Boot-Setup.log' } else { 'OSYNC-Install-All.log' })) -Force | Out-Null
Write-Host "OSYNC client $(if ($Boot) { 'boot setup' } else { 'install' }) on $env:COMPUTERNAME  ($Root)" -ForegroundColor Cyan

# the only question, asked up front so the rest runs unattended
$acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP
$fixThai = $false
if ($acp -ne '874' -and -not $Boot) {
  Write-Host "Thai text in games shows as alien letters on this PC (code page $acp)." -ForegroundColor DarkYellow
  $tf = Get-Setting 'ClientThaiFix' 'ask'     # Settings: on = fix without asking, off = leave it, ask = ask here
  if ($tf -match '^(?i)(on|yes|y|1|true)$') { $fixThai = $true; Write-Host 'Fixing it (Settings ClientThaiFix=on) - works after the restart.' }
  elseif ($tf -match '^(?i)(off|no|n|0|false)$') { Write-Host 'Left as it is (Settings ClientThaiFix=off).' }
  else { $fixThai = (Read-Host 'Fix it now? Sets system locale Thai, UTF-8 beta off, needs a restart [Y/N]') -match '^[Yy]' }
}

function Run-Script([string]$file, [string[]]$extra = @()) {
  # "~" lines = live status of a running installer: drawn in place, not logged
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @extra 2>&1 | ForEach-Object {
    $s = "$_"
    if ($s.StartsWith('~')) { Show-Live $s.Substring(1) } else { Show-Live ''; Write-Host "    $s" }
  }
  Show-Live ''
  $LASTEXITCODE
}
$results = New-Object System.Collections.Generic.List[object]
function Step([string]$name, [scriptblock]$body) {
  Write-Host "`n== $name" -ForegroundColor Yellow
  try { [Console]::Title = "OSYNC $name" } catch {}
  $t = [Diagnostics.Stopwatch]::StartNew()
  try { $r = & $body } catch { $r = "FAIL: $($_.Exception.Message)" }
  if ($null -eq $r -or $r -eq 0) { $r = 'OK' } elseif ($r -is [int]) { $r = "FAIL (exit $r)" }
  $results.Add([pscustomobject]@{ Step = $name; Result = $r; Sec = [int]$t.Elapsed.TotalSeconds })
}
# 19 Nov 2026 (Apex): WO Mic's driver WOVAD off for this boot. Turning its device off was not enough (KORI23 15:03: "WOVAD
# Running" - Windows Audio still held it), so Windows Audio stops for a moment, WO Mic's devices are removed (pnputil), the
# driver is stopped and Windows Audio starts again. Returns '' when WOVAD is not loaded any more, else why.
function Stop-WoMicDriver {
  $devs = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Service -eq 'WOVAD' -or (@($_.HardwareID) -match '(?i)WOMic') })
  if (Get-CimInstance Win32_SystemDriver -Filter "Name='WOVAD'" -ErrorAction SilentlyContinue) { & sc.exe config WOVAD start= disabled 2>&1 | Out-Null }
  Stop-Service -Name 'Audiosrv' -Force -ErrorAction SilentlyContinue
  Stop-Service -Name 'AudioEndpointBuilder' -Force -ErrorAction SilentlyContinue
  foreach ($d in $devs) { $o = @(& pnputil.exe /remove-device $d.InstanceId 2>&1); Write-Host "    removed $($d.FriendlyName) ($($d.InstanceId)): $("$($o | Select-Object -Last 1)".Trim())" }
  Start-Sleep -Seconds 2
  & sc.exe stop WOVAD 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  Start-Service -Name 'AudioEndpointBuilder' -ErrorAction SilentlyContinue
  Start-Service -Name 'Audiosrv' -ErrorAction SilentlyContinue
  $drv = Get-CimInstance Win32_SystemDriver -Filter "Name='WOVAD'" -ErrorAction SilentlyContinue
  Write-Host "    WOVAD driver now: $(if ($drv) { "$($drv.StartMode) $($drv.State)" } else { 'not installed' }) | Windows Audio: $((Get-Service -Name 'Audiosrv' -ErrorAction SilentlyContinue).Status)"
  if ($drv -and $drv.State -eq 'Running') { return 'WOVAD still loaded' }
  ''
}

# Apex / EA Javelin (19 Nov 2026): on clients Apex closed at "Starting EA Javelin Anticheat..." - EAAntiCheatService ended
# itself 4 s after it started (System log 7034), while on the master the same files ran. The client difference: the diskless
# program's hardware / temperature reader (C:\lwserver\client\lwclient64\lwhardware64.exe -> khwsdk64.dll) loads the CPU-Z
# driver C:\Windows\Temp\cpuz160\cpuz160_x64.sys, and CPU-Z's driver is on EA Javelin's denylist (help.ea.com lists
# C:\windows\temp\cpuz141\cpuz141_x64.sys). A loaded CPU-Z driver cannot be stopped, so this runs FIRST at boot, before the
# reader: its folder names (cpuz152, cpuz160 - the two in khwsdk64.dll) become read-only files, so the driver cannot be
# written there, and a disabled service of that name is made, so it cannot be started. Steam's own cpuz163 is not touched.
# Cost: the diskless program shows no CPU temperature for these PCs. Settings ClientBlockCpuz = on | off | PC names.
Step '0a Apex  - no CPU-Z driver (EA Javelin denylist)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientBlockCpuz' 'off').Trim()
  $clean = @((Get-Setting 'ClientApexClean' '').Trim() -split '[,; ]+') -contains $env:COMPUTERNAME   # step 9's clean test PCs too
  if (-not ($clean -or $v -match '^(?i)(on|yes|1|true)$' -or (@($v -split '[,; ]+') -contains $env:COMPUTERNAME))) { return "SKIP (ClientBlockCpuz=$v)" }
  $late = @()
  foreach ($n in 'cpuz152', 'cpuz160') {
    $drv = Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue
    if ($drv -and $drv.State -eq 'Running') { $late += $n }
    $p = Join-Path $env:SystemRoot "Temp\$n"
    if (Test-Path -LiteralPath $p -PathType Container) { try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } catch { Write-Host "    $p in use (driver loaded)" } }
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType File -Path $p -Force | Out-Null; (Get-Item -LiteralPath $p -Force).Attributes = 'ReadOnly, Hidden, System' }
    if ($drv) { & sc.exe config $n start= disabled | Out-Null } else { & sc.exe create $n type= kernel start= disabled binPath= "$p\${n}_x64.sys" | Out-Null }
    $now = Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue
    Write-Host "    $n : folder blocked=$(Test-Path -LiteralPath $p -PathType Leaf), service $($now.StartMode) $($now.State)"
  }
  if ($late.Count) { return "FAIL (already loaded before this step: $($late -join ', ') - Apex stays blocked on this boot)" }
}

# Sunshine 0JAYSHOP from the start of Windows (18 Nov 2026, the owner: "folded away, from when Windows loads - not on PCs that
# already have Sunshine"): FIRST step of the boot setup. A PC with a Sunshine of its own (service / C:\Program Files\Sunshine,
# C:\Sunshine, C:\Users\*\Sunshine) gets nothing. Any other PC: WebView2 first when it is missing (the panel needs it, else it
# asks), then Client-Sunshine0J.ps1 -Service = port for this PC + the Windows service SunshineService (Tools\Sunshine0J\tools\
# sunshinesvc.exe, automatic): sunshine.exe runs from the sign-in screen on, its panel in the tray. Settings
# ClientSunshineAutoStart=on | off | PC names.
Step '0 Sunshine - 0JAYSHOP from the start of Windows (PCs without their own)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  Unregister-ScheduledTask -TaskName 'OSYNC-Sunshine0J' -Confirm:$false -ErrorAction SilentlyContinue   # the logon task of the first version
  $v = (Get-Setting 'ClientSunshineAutoStart' 'off').Trim()
  if ($v -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientSunshineAutoStart=off)' }
  if ($v -notmatch '^(?i)(on|yes|1|true)$' -and @($v -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count -eq 0) { return "SKIP ($env:COMPUTERNAME not in ClientSunshineAutoStart=$v)" }
  $kit = Join-Path $ToolsDir 'Sunshine0J'
  if (-not (Test-Path -LiteralPath (Join-Path $kit 'sunshine.exe'))) { return 'SKIP (no Tools\Sunshine0J)' }
  $own = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '(?i)sunshine' -or $_.PathName -match '(?i)sunshine') -and $_.PathName -notlike "*$kit*" -and $_.StartMode -ne 'Disabled' } | ForEach-Object { "service $($_.Name)" })
  foreach ($p in @('C:\Program Files\Sunshine', 'C:\Sunshine') + @(Get-ChildItem 'C:\Users\*\Sunshine' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)) { if (Test-Path -LiteralPath (Join-Path $p 'sunshine.exe')) { $own += "installed $p" } }
  if ($own.Count) { return "SKIP (this PC has its own Sunshine: $($own -join '; '))" }
  $wv = ''; foreach ($sub in 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}') { $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub); if ($k) { $x = "$($k.GetValue('pv', ''))"; $k.Close(); if ($x -and $x -ne '0.0.0.0') { $wv = $x } } }
  if (-not $wv) { Write-Host '    WebView2 missing - installing it first (the Sunshine panel needs it)'; [void](Run-Script (Join-Path $ScriptsDir 'Client-Runtimes.ps1')) }
  Run-Script (Join-Path $ScriptsDir 'Client-Sunshine0J.ps1') @('-Service')
}
# FiveM servers' files to the master (18 Nov 2026): Client-FiveMShare.ps1 in the background (it notes FiveM's index now, before
# FiveM can start, then hands new server files to the master whenever FiveM is closed). Settings ClientFiveMShare=on | off.
Step '0b FiveM - hand new server files to the master (background)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if (-not $Boot) { return 'SKIP (only at boot)' }
  if ((Get-Setting 'ClientFiveMShare' 'off') -notmatch '^(?i)(on|yes|1|true)$') { return 'SKIP (ClientFiveMShare=off)' }
  Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $ScriptsDir 'Client-FiveMShare.ps1')`"")
  Write-Host '    started in the background (log C:\Users\Public\OSYNC-FiveMShare.log)'
}
Step '1 Riot  - silent start at logon' {
  $vbs = Join-Path $ClientDir 'Riot.vbs'
  if (-not (Test-Path -LiteralPath (Get-LauncherExe 'Riot'))) { return 'SKIP (no Riot Client in Launchers)' }
  Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotStart -Value ('wscript.exe "' + $vbs + '" background')
  Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotClient -ErrorAction SilentlyContinue
  Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotStart -ErrorAction SilentlyContinue
  Write-Host "    Run\RiotStart -> wscript.exe `"$vbs`" background"
  0
}
# at boot: the menu shortcuts are made again right away (seconds), before the slow installers below, so they are in place
# before Windows logs on - an image made with an older OSYNC layout (shortcut to GCafe\app) starts the menu from
# System\Client\Menu.vbs from this boot on
if ($Boot) {
  Step '1b Menu - menu shortcuts (repair, before logon)' {
    if (-not (Test-Path -LiteralPath (Get-MenuInfo).Exe)) { return 'SKIP (no menu program)' }
    Run-Script (Join-Path $ScriptsDir 'Client-Menu.ps1') @('-NoStart')
  }
}
# Roblox installs per user: at logon Roblox.vbs points this user's roblox:// links at Launchers\Roblox (seconds, no install)
Step '1c Roblox - play from the game disk (links at logon)' {
  if (-not (Get-RobloxExe)) { return 'SKIP (no Roblox in Launchers\Roblox)' }
  $vbs = Join-Path $ClientDir 'Roblox.vbs'
  Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RobloxPrep -Value ('wscript.exe "' + $vbs + '" background')
  Write-Host "    Run\RobloxPrep -> wscript.exe `"$vbs`" background"
  0
}
# Windows 11 "Resume" (CrossDeviceResume.exe) is not registered for the user on a diskless image and pops up
# "The parameter is incorrect": switch Resume off for every user through Active Setup (runs as the user at logon,
# before the desktop starts - no user hive is loaded or touched here)
Step '1d Win  - Resume off (CrossDeviceResume error popup)' {
  if (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResume.exe'))) { return 'SKIP (no CrossDeviceResume on this Windows)' }
  $cfg = 'HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
  $reg = Join-Path $env:SystemRoot 'System32\reg.exe'
  $stub = (Join-Path $env:SystemRoot 'System32\cmd.exe') + " /c `"`"$reg`" add `"$cfg`" /v IsResumeAllowed /t REG_DWORD /d 0 /f & `"$reg`" add `"$cfg`" /v IsOneDriveResumeAllowed /t REG_DWORD /d 0 /f`""
  $k = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\OSYNC-ResumeOff'
  if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
  Set-Item -LiteralPath $k -Value 'OSYNC: Windows Resume off (CrossDeviceResume popup)'
  New-ItemProperty -LiteralPath $k -Name StubPath -Value $stub -PropertyType String -Force | Out-Null
  New-ItemProperty -LiteralPath $k -Name Version -Value '1,0,0,0' -PropertyType String -Force | Out-Null
  New-ItemProperty -LiteralPath $k -Name IsInstalled -Value 1 -PropertyType DWord -Force | Out-Null
  # the same at every logon through Run (in case Windows logged on before this boot step wrote Active Setup); the taskbar
  # (sihost) starts CrossDeviceResume later, e.g. when a rental starts and the lock screen goes away
  Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OSYNC-ResumeOff' -Value $stub
  # machine policy "Phone-PC linking on this device" = off (Resume / continue-on-PC belongs to it)
  $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
  if (-not (Test-Path -LiteralPath $pol)) { New-Item -Path $pol -Force | Out-Null }
  New-ItemProperty -LiteralPath $pol -Name EnableMmx -Value 0 -PropertyType DWord -Force | Out-Null
  # image mode: the admin doing this is logged on now - set it for this user too
  if (-not $Boot) { & $reg add $cfg /v IsResumeAllowed /t REG_DWORD /d 0 /f 2>$null | Out-Null; & $reg add $cfg /v IsOneDriveResumeAllowed /t REG_DWORD /d 0 /f 2>$null | Out-Null }
  # the taskbar (sihost) starts CrossDeviceResume whatever the setting says: switch the feature itself off for the
  # whole PC (the same as ViVeTool /disable /id:56517033). Read by Windows at startup, so it works for sure once it is
  # in the image (OSYNC.bat client, then save the image); written at every boot too.
  $fo = 'HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\1387020943'
  if (-not (Test-Path -LiteralPath $fo)) { New-Item -Path $fo -Force | Out-Null }
  foreach ($kv in @(@('EnabledState', 1), @('EnabledStateOptions', 0), @('Variant', 0), @('VariantPayload', 0), @('VariantPayloadKind', 0))) { New-ItemProperty -LiteralPath $fo -Name $kv[0] -Value $kv[1] -PropertyType DWord -Force | Out-Null }
  # and in case it still pops up: a hidden guard per session closes that popup (same as pressing its OK).
  # Started by a task AT LOGON (Run entries start a minute or more later, the popup comes first); Run stays as a backup
  $gv = Join-Path $ClientDir 'PopupGuard.vbs'
  Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OSYNC-PopupGuard' -Value ('wscript.exe "' + $gv + '"')
  $ta = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $gv + '"')
  $tt = New-ScheduledTaskTrigger -AtLogOn
  $tp = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited      # BUILTIN\Users: runs as whoever logs on
  $ts = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName 'OSYNC-PopupGuard' -Action $ta -Trigger $tt -Principal $tp -Settings $ts -Force | Out-Null
  Write-Host "    Resume off: feature override 56517033 (whole PC), Active Setup + Run (IsResumeAllowed=0), EnableMmx=0; Run\OSYNC-PopupGuard closes the popup if it still shows"
  0
}
# customers cannot shut down / restart (Settings ClientPowerLock=on): Shut down / Restart / Sleep are hidden in Start,
# Alt+F4, Ctrl+Alt+Del and the sign-in screen. The shop's own restart / shutdown (agent: shutdown.exe as SYSTEM) still works.
Step '1e Power - customers cannot shut down / restart' {
  $on = (Get-Setting 'ClientPowerLock' 'on') -notmatch '^(?i)(off|no|0|false)$'
  $exp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
  $sys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
  foreach ($k in $exp, $sys) { if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null } }
  New-ItemProperty -LiteralPath $exp -Name NoClose -Value $(if ($on) { 1 } else { 0 }) -PropertyType DWord -Force | Out-Null
  New-ItemProperty -LiteralPath $sys -Name shutdownwithoutlogon -Value $(if ($on) { 0 } else { 1 }) -PropertyType DWord -Force | Out-Null
  Write-Host "    ClientPowerLock=$(if ($on) { 'on: power options hidden (NoClose=1, shutdownwithoutlogon=0)' } else { 'off: power options shown' })"
  0
}
# GTA V / FiveM graphics = the shop's file Settings\gta5_settings.xml (low graphics), written over every profile's GTA V and
# FiveM settings at every boot - seconds, so it runs before the installers below. Settings ClientGtaSettings=off skips this.
Step '1h GTA   - GTA V / FiveM graphics (shop file)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientGtaSettings' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientGtaSettings=off)' }
  if (-not (Test-Path -LiteralPath (Join-Path $SettingsDir 'gta5_settings.xml'))) { return 'SKIP (no Settings\gta5_settings.xml)' }
  Run-Script (Join-Path $ScriptsDir 'Client-GtaSettings.ps1')
}
# saved game logins of every user (FiveM / Rockstar / Steam / Epic / EA / Riot / Ubisoft / Battle.net / Garena / HoYoPlay /
# Discord) are deleted - a login saved into the image never reaches the customers. At boot nothing is closed (Riot starting
# at logon stays); in image mode the launchers are closed first. Settings ClientClearLogins=off skips this.
Step '1i Logins - clear saved game logins' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientClearLogins' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientClearLogins=off)' }
  Run-Script (Join-Path $ScriptsDir 'Client-ClearLogins.ps1') $(if ($Boot) { @('-Boot') } else { @() })
}
# OSLink's own drivers (LdVMou virtual mouse, LdVKbd virtual keyboard, LdScpVBus virtual gamepad bus - the remote player's
# input): installed silently from the OSLink folder only when not loaded (an image saved with them = a check of ms). Without
# them OSLink shows "driver error - click to repair", and on a diskless client what Repair installs is gone at the reboot.
# Runs before 1j / 1k: OSLink checks its drivers when it starts, and those steps restart it.
# Settings ClientOslinkDrivers=on | off | PC names (test on those only).
Step '1l OSLink - drivers (virtual mouse / keyboard / gamepad)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientOslinkDrivers' 'off').Trim()
  if ($v -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientOslinkDrivers=off)' }
  if ($v -notmatch '^(?i)(on|yes|1|true)$' -and @($v -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count -eq 0) { return "SKIP ($env:COMPUTERNAME not in ClientOslinkDrivers=$v)" }
  Run-Script (Join-Path $ScriptsDir 'Client-OslinkDrivers.ps1')
}
# OSLink (game disk LDPlayer\OSLink) carries the master's MAC ("cacheIpAdress") to every client: removed so each client
# writes its own; the signed-in support account stays. Settings ClientOslinkReset=on | off | PC names (test on those only).
Step '1j OSLink - own MAC, not the master''s' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientOslinkReset' 'off').Trim()
  if ($v -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientOslinkReset=off)' }
  if ($v -notmatch '^(?i)(on|yes|1|true)$' -and @($v -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count -eq 0) { return "SKIP ($env:COMPUTERNAME not in ClientOslinkReset=$v)" }
  Run-Script (Join-Path $ScriptsDir 'Client-OslinkReset.ps1')
}
# OSLink signed in with the master's support account as THIS PC (16 Nov): this PC's own sign-in, kept on the master
# (Master-OslinkLogins.ps1), is put back before OSLink starts; the first time, OSLink registers the PC itself and the logon
# helper (task OSYNC-OslinkHelper) sends the new sign-in to the master. Settings ClientOslinkLogin=on | off | PC names.
Step '1k OSLink - this PC''s own sign-in (from the master)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientOslinkLogin' 'off').Trim()
  if ($v -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientOslinkLogin=off)' }
  if ($v -notmatch '^(?i)(on|yes|1|true)$' -and @($v -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count -eq 0) { return "SKIP ($env:COMPUTERNAME not in ClientOslinkLogin=$v)" }
  Run-Script (Join-Path $ScriptsDir 'Client-OslinkLogin.ps1')
}
# OSLink in the tray from logon, no window (17 Nov, owner). Its service (LDRemoteSvc) starts ldremote.exe by itself; the task
# OSYNC-OslinkStart is the backup. At logon, with the user's highest rights (ldremote.exe requires administrator: from a Run
# entry Windows would ask or skip it), System\Client\OslinkStart.vbs starts "ldremote.exe --pcstart" hidden. That is OSLink's
# own start-with-Windows command. It waits for the drivers (1l) and starts only when OSLink is not running (never a 2nd copy).
# Settings ClientOslinkStart=on | off | PC names; not on for this PC = the task is removed.
Step '1m OSLink - in the tray at logon (no window)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientOslinkStart' 'off').Trim()
  $why = ''
  if ($v -match '^(?i)(off|no|0|false)$') { $why = 'SKIP (ClientOslinkStart=off)' }
  elseif ($v -notmatch '^(?i)(on|yes|1|true)$' -and @($v -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count -eq 0) { $why = "SKIP ($env:COMPUTERNAME not in ClientOslinkStart=$v)" }
  if ($why) { Unregister-ScheduledTask -TaskName 'OSYNC-OslinkStart' -Confirm:$false -ErrorAction SilentlyContinue; return $why }
  $vbs = Join-Path $ClientDir 'OslinkStart.vbs'
  if (-not (Test-Path -LiteralPath $vbs)) { return 'FAIL: System\Client\OslinkStart.vbs is missing' }
  $ta = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')
  $tt = New-ScheduledTaskTrigger -AtLogOn
  $tp = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest   # BUILTIN\Users: whoever logs on, elevated for an administrator (the shop account)
  $ts = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName 'OSYNC-OslinkStart' -Action $ta -Trigger $tt -Principal $tp -Settings $ts -Force | Out-Null
  Write-Host "    task OSYNC-OslinkStart: at logon -> wscript.exe `"$vbs`""
  # at boot Windows may have logged on before this step: run it for that session now (it does nothing when OSLink runs)
  if ($Boot -and @(Get-Process explorer -ErrorAction SilentlyContinue).Count) {
    try { Start-ScheduledTask -TaskName 'OSYNC-OslinkStart' -ErrorAction Stop; Write-Host '    a user is logged on already - started for this session' } catch { Write-Host "    could not start it now: $($_.Exception.Message)" }
  }
  0
}
# 17 Nov, temporary diagnosis: OSLink still said "driver error" on a client - a report of its drivers / processes / logs goes
# to the master (LAN, port 4670) 2.5 and 6 min after this step, in the background (the boot setup does not wait for it).
# Settings ClientOslinkReport=on; remove the line (or off) when OSLink is fixed.
if ($Boot -and (Get-Setting 'ClientOslinkReport' 'off') -match '^(?i)(on|yes|1|true)$' -and -not (Test-IsMaster)) {
  $rep = Join-Path $ScriptsDir 'Client-OslinkReport.ps1'
  foreach ($w in @(@('boot+150s', 150), @('boot+360s', 360))) {
    Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rep`"", '-Phase', $w[0], '-DelaySeconds', $w[1])
  }
  # 18 Nov 2026: one more report as soon as Steam has run on this PC ("Updating Steam..." at every start), waits up to 3 h
  Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rep`"", '-Phase', 'steam', '-WaitSteamMinutes', '180')
  # 18 Nov 2026: and one after FiveM joined a server (did it use the server files the master fetched?), waits up to 3 h
  Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rep`"", '-Phase', 'fivem', '-WaitFiveMMinutes', '180')
  # 18 Nov 2026: and one after Riot Client showed VALORANT ("UPDATING" on a client), waits up to 3 h
  Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rep`"", '-Phase', 'riot', '-WaitRiotMinutes', '180')
  # 19 Nov 2026: and one when someone starts Apex (closes at "Starting EA Javelin Anticheat..."): did the game stay open? waits up to 12 h
  Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rep`"", '-Phase', 'apex', '-WaitApexMinutes', '720')
  Write-Host "    OSLink report to the master in 2.5 and 6 min, Steam / FiveM / Riot / Apex reports after their first start (ClientOslinkReport=on)"
}
# 20 Nov 2026 (Apex, rule 1 of iPlay's anti-cheat guide: game files exactly as the publisher shipped them): on the PCs in
# Settings ClientSteamVerify (PC names, or on = every PC) the files of the Steam games in ClientSteamVerifyApps are checked as
# THIS PC reads them from the game disk, against Steam's depot manifests (size + SHA1), 4 min after boot in the background
# (Client-SteamVerify.ps1); the result goes to the master's ClientReports (phase=steamverify-<appid>). It reads the whole game
# once per boot (Apex 68 GB: about 5 min on the master's own disk, 10-12 min over 1 Gbit) - keep the list short.
if ($Boot -and -not (Test-IsMaster)) {
  $sv = (Get-Setting 'ClientSteamVerify' '').Trim()
  if ($sv -and ($sv -match '^(?i)(on|yes|1|true)$' -or (@($sv -split '[,;\s]+') -contains $env:COMPUTERNAME))) {
    $svScript = Join-Path $ScriptsDir 'Client-SteamVerify.ps1'
    $svApps = @((Get-Setting 'ClientSteamVerifyApps' '1172470') -split '[,;\s]+' | Where-Object { $_ -match '^\d+$' })
    # one after the other (one process, so the disk is read once at a time)
    $svCmd = ($svApps | ForEach-Object { "& '$svScript' -AppId $_ -Report -DelaySeconds $(if ($_ -eq $svApps[0]) { 240 } else { 0 })" }) -join '; '
    if ($svCmd) {
      Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $svCmd)
      Write-Host "    game files check (Steam size + SHA1) of app $($svApps -join ', ') in 4 min, result to the master (ClientSteamVerify)"
    }
  }
}
# WO Mic Client (the agent's phone-mic button needs it) and VB-CABLE: installed silently only when missing (an image saved
# with them = a quick check). Installers in Tools\WOMic and Tools\VBCABLE; Settings ClientMicDrivers=off skips this.
Step '1f Mic   - WO Mic + VB-CABLE (only if missing)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  # 19 Nov 2026 (Apex closes at "Starting EA Javelin Anticheat..."): WO Mic's driver (service WOVAD, womic.sys) is signed by its
  # maker with a certificate that expired in 2020, and EA's help says Javelin stops the game when expired / unsigned drivers
  # are loaded. Settings ClientNoWoMic=<PC names> (or on): on those PCs WO Mic's device is turned off at boot, so its driver
  # unloads - the phone-mic button does not work there. VB-CABLE stays.
  # ClientApexClean PCs (step 9) count as ClientNoWoMic too - nothing is installed there, WO Mic is taken out
  $nw = (Get-Setting 'ClientNoWoMic' '').Trim()
  $cleanPc = @((Get-Setting 'ClientApexClean' '').Trim() -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count
  if ($cleanPc -or $nw -match '^(?i)(on|yes|1|true)$' -or @($nw -split '[,;\s]+' | Where-Object { $_ -ieq $env:COMPUTERNAME }).Count) {
    $why = Stop-WoMicDriver
    if ($why) { return "FAIL ($why)" }
    return 'OK (WO Mic taken out on this PC - ClientNoWoMic / ClientApexClean)'
  }
  if ((Get-Setting 'ClientMicDrivers' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientMicDrivers=off)' }
  if (-not (Test-Path -LiteralPath (Join-Path $ToolsDir 'WOMic')) -and -not (Test-Path -LiteralPath (Join-Path $ToolsDir 'VBCABLE'))) { return 'SKIP (no Tools\WOMic or Tools\VBCABLE)' }
  Run-Script (Join-Path $ScriptsDir 'Client-Mic.ps1')
}
# Parsec (the menu's Parsec card opens Program Files\Parsec\parsecd.exe): installed silently only when missing. Installer
# in Tools\Parsec; Settings ClientParsec=off skips this.
Step '1g Parsec - Parsec app (only if missing)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientParsec' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientParsec=off)' }
  if (-not (Get-ChildItem -LiteralPath (Join-Path $ToolsDir 'Parsec') -Filter 'parsec-windows*.exe' -File -ErrorAction SilentlyContinue)) { return 'SKIP (no installer in Tools\Parsec)' }
  Run-Script (Join-Path $ScriptsDir 'Client-Parsec.ps1')
}
# Runtimes other programs need (18 Nov 2026): WebView2 installed silently only when missing (Tools\WebView2; e.g. the Sunshine
# 0JAYSHOP panel asks for it), Node.js and Python from Tools\NodeJS / Tools\Python (machine PATH + registration, nothing
# copied). Settings ClientWebView2 / ClientNodeJs / ClientPython = off skip a part.
Step '1o Runtimes - WebView2, Node.js, Python' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  Run-Script (Join-Path $ScriptsDir 'Client-Runtimes.ps1')
}
# Virtual monitor VDD 1920x1080 240 Hz (Tools\VirtualDisplay, 18 Nov 2026): installed only when this PC has no VDD at all; a
# VDD that is there - working, disabled or broken - is left exactly as it is. Settings ClientVdd=off skips this.
Step '1p VDD   - virtual monitor 1920x1080 (only if missing)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientVdd' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientVdd=off)' }
  Run-Script (Join-Path $ScriptsDir 'Client-Vdd.ps1')
}
# Steam on clients (18 Nov 2026): Steam re-installed itself at EVERY start on a client ("Updating Steam... Extracting package",
# about a minute; its log: "Unable to read and verify install manifest ...steam_client_win64.installed") although the files a
# client reads are byte-identical to the master's (SHA256 checked on KORI05) - Steam does not accept its install list on a PC
# other than the one that wrote it. steam.cfg next to steam.exe = no self-update / repair on THIS client, Steam starts at once.
# Written into this PC's own copy of the game disk only (diskless): the master's Steam keeps updating itself as before and
# clients run its new version from their next boot. Settings ClientSteamNoUpdate: on = every client, off = none, or PC names.
Step '1q Steam - start without self-update (steam.cfg)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientSteamNoUpdate' 'off').Trim()
  if (-not ($v -match '^(?i)(on|yes|1|true)$' -or (@($v -split '[,; ]+') -contains $env:COMPUTERNAME))) { return "SKIP (ClientSteamNoUpdate=$v)" }
  $cfg = "BootStrapperInhibitAll=enable`r`nBootStrapperForceSelfUpdate=disable`r`n"
  $done = @()
  $dirs = @(foreach ($d in (Get-SharedDrives).ToCharArray()) { "${d}:\Steam" }) + @(Join-Path $Root 'Launchers\Steam')
  foreach ($sd in $dirs) {
    if (-not (Test-Path -LiteralPath (Join-Path $sd 'steam.exe'))) { continue }
    $f = Join-Path $sd 'steam.cfg'
    $cur = if (Test-Path -LiteralPath $f) { [IO.File]::ReadAllText($f) } else { $null }
    if ($cur -ne $cfg) { [IO.File]::WriteAllText($f, $cfg, [Text.Encoding]::ASCII) }
    $done += $f
  }
  if (-not $done.Count) { return 'SKIP (no Steam on the game disks)' }
  Write-Host "    steam.cfg (no self-update on this PC): $($done -join ', ')"
}
# Steam accounts (18 Nov 2026, the owner): Steam on the game disk keeps the list of accounts signed in on the MASTER
# (config\loginusers.vdf) and every client showed them in "Who's playing?". On a client that list is emptied at boot, in this
# PC's own copy of the game disk only: customers get the normal sign-in, the master keeps its accounts. (The sign-in tokens
# are not on the game disk - they live in the master's own AppData - so nobody could sign in with them anyway.)
# Settings ClientClearLogins=off skips this too.
Step '1r Steam - no master accounts in the sign-in list' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientClearLogins' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientClearLogins=off)' }
  $done = @()
  $dirs = @(foreach ($d in (Get-SharedDrives).ToCharArray()) { "${d}:\Steam" }) + @(Join-Path $Root 'Launchers\Steam')
  foreach ($sd in $dirs) {
    $f = Join-Path $sd 'config\loginusers.vdf'
    if (-not (Test-Path -LiteralPath (Join-Path $sd 'steam.exe')) -or -not (Test-Path -LiteralPath $f)) { continue }
    $n = ([regex]::Matches([IO.File]::ReadAllText($f), '"AccountName"')).Count
    if ($n) { [IO.File]::WriteAllText($f, "`"users`"`n{`n}`n", (New-Object Text.UTF8Encoding($false))); $done += "$f ($n removed)" }
  }
  Write-Host "    $(if ($done.Count) { 'emptied: ' + ($done -join ', ') } else { 'no saved Steam accounts on this PC' })"
}
# Steam Client Service (18 Nov 2026, the owner: "press PLAY in Steam and nothing happens, nothing pops up" on almost every
# Steam game): Steam runs games' first-run setup and anti-cheat through its service. The master and most clients have it
# (reports: "Running Manual"), but the image of some clients has none (KORI06 / 12 / 13 / 19: "not installed") and Steam did
# not add it there. Installed here with Steam's own installer, <Steam>\bin\steamservice.exe /install (the game disk's copy =
# the master's version) - at every boot, as the diskless client forgets it. Settings ClientSteamService=off skips this.
Step '1u Steam - Steam Client Service (PLAY needs it)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientSteamService' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientSteamService=off)' }
  $svcFile = Join-Path ${env:ProgramFiles(x86)} 'Common Files\Steam\steamservice.exe'
  $svc = Get-CimInstance Win32_Service -Filter "Name='Steam Client Service'" -ErrorAction SilentlyContinue
  if ($svc -and (Test-Path -LiteralPath $svcFile)) { Write-Host "    already there: $($svc.PathName) ($($svc.State), $($svc.StartMode))"; return }
  $m = "$((Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath)".TrimEnd('\')
  $dirs = @($m) + @(foreach ($d in (Get-SharedDrives).ToCharArray()) { "${d}:\Steam" }) + @(Join-Path $Root 'Launchers\Steam')
  $src = $dirs | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\steamservice.exe')) } | ForEach-Object { Join-Path $_ 'bin\steamservice.exe' } | Select-Object -First 1
  if (-not $src) { return 'SKIP (no Steam\bin\steamservice.exe on this PC)' }
  $p = Start-Process -FilePath $src -ArgumentList '/install' -WindowStyle Hidden -PassThru
  if (-not $p.WaitForExit(120000)) { try { $p.Kill() } catch {}; return 'FAIL (steamservice.exe /install still running after 2 min)' }
  $svc = Get-CimInstance Win32_Service -Filter "Name='Steam Client Service'" -ErrorAction SilentlyContinue
  if (-not $svc) { return "FAIL (steamservice.exe /install exit $($p.ExitCode), still no service)" }
  Start-Service -Name 'Steam Client Service' -ErrorAction SilentlyContinue    # manual start; Steam starts it too (tested on the master: /install = 3 s, exit 0, no window)
  $svc = Get-CimInstance Win32_Service -Filter "Name='Steam Client Service'" -ErrorAction SilentlyContinue
  Write-Host "    installed from $src (exit $($p.ExitCode)): $($svc.PathName) ($($svc.State), $($svc.StartMode))"
}
# Battle.net (18 Nov 2026, the owner: "add Battle.net"; Overwatch on Steam did not start either): Battle.net lives on the game
# disk (Launchers\BattleNet) but needs its Update Agent in C:\ProgramData\Battle.net\Agent - and so does Overwatch on Steam
# (its Blizzard launcher checks the game through the Agent). The diskless client has none, so the master's copy
# (System\Data\BattleNet\Agent, Master-Snapshot-BattleNet.ps1 in OSYNC.bat > 1 / the watcher) is copied there at every boot
# (about 21 MB). The registry is not copied (its keys are encrypted for the master only; Battle.net writes its own).
# Settings ClientBattleNet=off skips this.
Step '1v Battle.net - Update Agent (Battle.net, Overwatch on Steam)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientBattleNet' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientBattleNet=off)' }
  $src = Join-Path $DataDir 'BattleNet\Agent'
  if (-not (Test-Path -LiteralPath (Join-Path $src 'Agent.exe'))) { return 'SKIP (no System\Data\BattleNet\Agent yet: OSYNC.bat > 1 on the master first)' }
  $dst = Join-Path $env:ProgramData 'Battle.net\Agent'
  & robocopy.exe $src $dst /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  $rc = $LASTEXITCODE
  if ($rc -ge 8) { return "FAIL (copy to $dst, robocopy $rc)" }
  $ver = (Get-ChildItem -LiteralPath $dst -Directory -Filter 'Agent.*' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).Name
  Write-Host "    Battle.net Update Agent $ver -> $dst ($(if ($rc -eq 0) { 'already there' } else { 'copied' }))"
}
# WinRAR (18 Nov 2026): installed silently only when missing (Tools\WinRAR, official setup), then .rar .zip .7z ... open with it
# where Windows has nothing / its own zip folder. Menu card "WinRAR". Settings ClientWinRAR=off skips this.
Step '1s WinRAR - archives (only if missing)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientWinRAR' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientWinRAR=off)' }
  Run-Script (Join-Path $ScriptsDir 'Client-WinRAR.ps1')
}
# Rockstar Games Launcher (18 Nov 2026): FiveM and GTA V (Steam) start it, and say "2. Rockstar Games Launcher could not be found!"
# when Windows does not know where it is. It lives on the game disk (Launchers\Rockstar since step B, 17 Nov), but the client
# image still has the old place: registry InstallFolder + the "Rockstar Service" (RockstarService.exe) are pointed at the game
# disk here, the same as on the master. Settings ClientRockstar=off skips this.
Step '1t Rockstar - launcher on the game disk (FiveM / GTA V)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientRockstar' 'on') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientRockstar=off)' }
  $dir = Join-Path $Root 'Launchers\Rockstar'
  $exe = Join-Path $dir 'Launcher.exe'
  if (-not (Test-Path -LiteralPath $exe)) { return 'SKIP (no Launchers\Rockstar\Launcher.exe)' }
  $ver = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
  $k = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey('SOFTWARE\WOW6432Node\Rockstar Games\Launcher')
  try {
    $old = "$($k.GetValue('InstallFolder', ''))"
    if ($old.Trim('"').TrimEnd('\') -ine $dir) { $k.SetValue('InstallFolder', $dir) }
    if ($ver -and "$($k.GetValue('Version', ''))" -ne $ver) { $k.SetValue('Version', $ver) }
    if ($null -eq $k.GetValue('Language')) { $k.SetValue('Language', '') }
  } finally { $k.Close() }
  $svcExe = Join-Path $dir 'RockstarService.exe'
  $svc = Get-CimInstance Win32_Service -Filter "Name='Rockstar Service'" -ErrorAction SilentlyContinue
  $svcMsg = 'service: none needed'
  if (Test-Path -LiteralPath $svcExe) {
    $want = "`"$svcExe`""
    if ($svc) {
      if ($svc.PathName -ne $want) { Set-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Rockstar Service' -Name ImagePath -Value $want; $svcMsg = "service path fixed (was $($svc.PathName))" } else { $svcMsg = 'service OK' }
    } else {
      & sc.exe create 'Rockstar Service' binPath= $want start= demand DisplayName= 'Rockstar Game Library Service' | Out-Null
      $svcMsg = $(if ($LASTEXITCODE -eq 0) { 'service created (manual start, like the master)' } else { "service create failed ($LASTEXITCODE)" })
    }
  }
  Write-Host "    Rockstar Games Launcher $ver : $dir (was: $(if ($old) { $old } else { 'not registered' })); $svcMsg"
}
Step '2 Steam - first-run setup of every game' {
  Run-Script (Join-Path $ScriptsDir 'Client-Steam-FirstRun.ps1') $(if ($Boot) { @('-SkipFailed') } else { @() })
}
Step '3 EA    - EA app, games, EA AntiCheat' {
  if (-not (Test-Path -LiteralPath (Join-Path $DataDir 'EA\ea-client.reg'))) { return 'SKIP (no EA data yet: OSYNC.bat > 1 on the master first)' }
  Run-Script (Join-Path $ScriptsDir 'Client-EA.ps1')
}
Step '4 EAC   - EasyAntiCheat (Epic and others)' {
  Run-Script (Join-Path $ScriptsDir 'Client-EAC.ps1')
}
# 5-7 stay in the image (menu shortcuts and NEWTHINGS are per user; nothing new comes with new games)
if (-not $Boot) {
  Step '5 Menu  - game menu' {
    if (-not (Test-Path -LiteralPath (Get-MenuInfo).Exe)) { return 'SKIP (build the menu on the master: OSYNC.bat > Tools)' }
    # shortcuts only: the menu's lock screen stays on top of every window, so started now it would cover this
    # window (and its "Press Enter") until the reboot
    Run-Script (Join-Path $ScriptsDir 'Client-Menu.ps1') @('-NoStart')
  }
  Step '6 NT    - NEWTHINGS-GAMES (GTA SA)' {
    Run-Script (Join-Path $ScriptsDir 'Client-NEWTHINGS.ps1') $(if ($fixThai) { @('-FixThaiText') } else { @() })
  }
  Step '7 Boot  - set up new games at every boot' {
    if (Test-IsMaster) { return 'SKIP (this is the master)' }
    $me = Join-Path $ClientDir 'Boot.ps1'
    # the game disk may appear a little after startup: wait up to 3 min for it, then run it
    $cmd = "`$f = '$me'; for (`$i = 0; `$i -lt 90 -and -not (Test-Path -LiteralPath `$f); `$i++) { Start-Sleep -Seconds 2 }; & `$f"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $enc"
    $t = New-ScheduledTaskTrigger -AtStartup
    $p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName 'OSYNC-Client-Boot' -Action $a -Trigger $t -Principal $p -Settings $s -Description "OSYNC: set up new games at boot ($me)" -Force | Out-Null
    Write-Host "    task OSYNC-Client-Boot: at startup as SYSTEM -> $me"
    0
  }
}
# 17 Nov (owner): the desktop shows ONLY the game menu icon - every other shortcut is moved aside (C:\ProgramData\OSYNC\DesktopRemoved).
# Last, at every boot and in image mode: after the installers above that add icons (WO Mic, Parsec ...). ClientDesktopMenuOnly=off skips it.
Step '8 Desktop - only the game menu icon' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  if ((Get-Setting 'ClientDesktopMenuOnly' 'off') -match '^(?i)(off|no|0|false)$') { return 'SKIP (ClientDesktopMenuOnly=off)' }
  Run-Script (Join-Path $ScriptsDir 'Client-DesktopClean.ps1')
}
# 19 Nov 2026: Apex closes at "Starting EA Javelin Anticheat..." on clients, but runs on the master (which has the OSLink, Parsec,
# VMware and Vanguard drivers too). Settings ClientApexClean=<PC names> makes those PCs a clean test: here, last, the client-only
# virtual devices are turned off so their drivers unload - WO Mic (WOVAD), ViGEm gamepad bus, VB-CABLE, Zako virtual display /
# mouse (Sunshine); step 0a keeps CPU-Z out on them. Costs there: no phone mic, no Sunshine gamepad / screen, no VB-CABLE.
Step '9 Apex  - clean test PC (ClientApexClean)' {
  if (Test-IsMaster) { return 'SKIP (this is the master)' }
  $v = (Get-Setting 'ClientApexClean' '').Trim()
  if (-not $v -or -not ($v -match '^(?i)(on|yes|1|true)$' -or (@($v -split '[,; ]+') -contains $env:COMPUTERNAME))) { return "SKIP (ClientApexClean=$v)" }
  $svcs = @('WOVAD', 'ViGEmBus', 'VBAudioVACMME')
  $devs = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $svcs -contains $_.Service -or (@($_.HardwareID) -match '(?i)zako') })
  if (-not $devs.Count) { Write-Host '    none of those devices on this PC' }
  foreach ($d in $devs) {
    try { Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop; Write-Host "    turned off: $($d.FriendlyName) [$($d.Service)] $($d.InstanceId)" }
    catch { Write-Host "    could not turn off $($d.InstanceId): $($_.Exception.Message)" }
  }
  Start-Sleep -Seconds 3
  $left = @()
  $names = $svcs + @(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)zako|^cpuz' } | ForEach-Object Name)
  foreach ($n in $names) {
    $drv = Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue
    if ($drv) { Write-Host "    driver $n : $($drv.StartMode) $($drv.State)"; if ($drv.State -eq 'Running') { $left += $n } }
  }
  # WO Mic: once more here (step 1f took it out already; anything that put it back since is removed again)
  if (Get-CimInstance Win32_SystemDriver -Filter "Name='WOVAD' AND State='Running'" -ErrorAction SilentlyContinue) { $null = Stop-WoMicDriver }
  $left = @($left | Where-Object { $_ -ne 'WOVAD' })
  if (Get-CimInstance Win32_SystemDriver -Filter "Name='WOVAD' AND State='Running'" -ErrorAction SilentlyContinue) { $left += 'WOVAD' }
  if ($left.Count) { return "FAIL (still loaded: $($left -join ', '))" }
}

Write-Host "`n================ RESULT ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ('{0,-42} {1,5} s  {2}' -f $_.Step, $_.Sec, $_.Result) -ForegroundColor $(if ($_.Result -eq 'OK') { 'Green' } elseif ($_.Result -like 'SKIP*') { 'DarkYellow' } else { 'Red' }) }
if ($fixThai) { Write-Host "`nThai text fix applied - it works after the restart." -ForegroundColor Yellow }
if (-not $Boot) {
  Write-Host "`nNow SAVE THE IMAGE (super workstation), then reboot this PC. From now on new games are set up at every boot." -ForegroundColor Cyan
  Write-Host 'The game menu was not opened now (its lock screen would cover this window): it opens by itself after the reboot.' -ForegroundColor Cyan
  try { [Console]::Title = 'OSYNC client install: done - see RESULT' } catch {}
}
Stop-Transcript | Out-Null
if ($results | Where-Object { $_.Result -like 'FAIL*' }) { exit 1 }
