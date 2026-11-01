# Install-All.ps1 - CLIENT PC: everything a client needs, in one run (CLIENT-Install-All.bat).
# Run as administrator in super-workstation (image edit) mode, then save the image.
#   1 Riot   : start Riot silently at logon (prepares the PC for VALORANT / LoL / TFT)
#   2 Steam  : every Steam game's first-run setup (BattlEye, ACE, Ricochet, EasyAntiCheat, Social Club,
#              DirectX, VC++ ...) - also covers Steam games installed later
#   3 EA     : EA app, EA games and EA AntiCheat (Apex, Battlefield)
#   4 EAC    : EasyAntiCheat for games outside Steam's scripts (Fortnite, Dead by Daylight, VRChat ...)
#   5 Menu   : 0JAYSHOP game menu at logon + desktop icon
#   6 NT     : NEWTHINGS-GAMES (GTA SA / SA-MP) registry + shortcuts; asks first whether to fix Thai text
#              (alien letters in-game = "Beta: UTF-8" code page 65001; fix = Thai 874, restart needed)
#   7 Boot   : task OSYNC-Client-Boot (at startup, SYSTEM) runs this script with -Boot on every boot
# -Boot: steps 1-4 only, no questions - installs just what is new since the image was saved (new games need
#        no image edit, only a client reboot). Log: C:\Users\Public\OSYNC-Boot-Setup.log
# Log: C:\Users\Public\OSYNC-Install-All.log
param([switch]$Boot)
$root = Split-Path -Parent $PSScriptRoot                                    # ...\OSYNC
$kit  = Join-Path $root 'GAMELUNCHER\ClientSetup'
$sys  = Join-Path $kit '_system'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host 'Run as administrator (CLIENT-Install-All.bat asks for it).' -ForegroundColor Red; exit 1 }
Start-Transcript -Path (Join-Path $env:PUBLIC $(if ($Boot) { 'OSYNC-Boot-Setup.log' } else { 'OSYNC-Install-All.log' })) -Force | Out-Null
Write-Host "OSYNC client $(if ($Boot) { 'boot setup' } else { 'install' }) on $env:COMPUTERNAME  ($root)" -ForegroundColor Cyan

# the only question, asked up front so the rest runs unattended
$acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP
$fixThai = $false
if ($acp -ne '874' -and -not $Boot) {
  Write-Host "Thai text in games shows as alien letters on this PC (code page $acp)." -ForegroundColor DarkYellow
  $fixThai = (Read-Host 'Fix it now? Sets system locale Thai, UTF-8 beta off, needs a restart [Y/N]') -match '^[Yy]'
}

. (Join-Path $sys 'Settings.ps1')                                           # Show-Live
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

Step '1 Riot  - silent start at logon' {
  $vbs = Join-Path $kit 'RiotSilent.vbs'
  if (-not (Test-Path -LiteralPath $vbs)) { return 'SKIP (no RiotSilent.vbs)' }
  Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotStart -Value ('wscript.exe "' + $vbs + '" background')
  Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotClient -ErrorAction SilentlyContinue
  Write-Host "    Run\RiotStart -> wscript.exe `"$vbs`" background"
  0
}
Step '2 Steam - first-run setup of every game' {
  Run-Script (Join-Path $sys 'Steam-FirstRun.ps1') $(if ($Boot) { @('-SkipFailed') } else { @() })
}
Step '3 EA    - EA app, games, EA AntiCheat' {
  if (-not (Test-Path -LiteralPath (Join-Path $sys 'ea-client.reg'))) { return 'SKIP (run MASTER-Update-All.bat on the master first)' }
  Run-Script (Join-Path $sys 'EA-ClientInstall.ps1')
}
Step '4 EAC   - EasyAntiCheat (Epic and others)' {
  Run-Script (Join-Path $sys 'EAC-Install.ps1')
}
# 5-7 stay in the image (menu shortcuts and NEWTHINGS are per user; nothing new comes with new games)
if (-not $Boot) {
  Step '5 Menu  - 0JAYSHOP game menu' {
    $s = Join-Path $root 'GCafe\tools\_system\Install-Client.ps1'
    if (-not (Test-Path -LiteralPath (Join-Path $root 'GCafe\app\0JAYSHOP.exe'))) { return 'SKIP (build the menu on the master: GCafe\tools\Build-App.bat)' }
    Run-Script $s
  }
  Step '6 NT    - NEWTHINGS-GAMES (GTA SA)' {
    Run-Script (Join-Path $sys 'NEWTHINGS-ClientInstall.ps1') $(if ($fixThai) { @('-FixThaiText') } else { @() })
  }
  Step '7 Boot  - set up new games at every boot' {
    if (Test-Path -LiteralPath 'C:\lwserver') { return 'SKIP (this is the master)' }
    $me = Join-Path $PSScriptRoot 'Install-All.ps1'
    # the game disk may appear a little after startup: wait up to 3 min for it, then run with -Boot
    $cmd = "`$f = '$me'; for (`$i = 0; `$i -lt 90 -and -not (Test-Path -LiteralPath `$f); `$i++) { Start-Sleep -Seconds 2 }; & `$f -Boot"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $enc"
    $t = New-ScheduledTaskTrigger -AtStartup
    $p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName 'OSYNC-Client-Boot' -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null
    Write-Host "    task OSYNC-Client-Boot: at startup as SYSTEM -> $me -Boot"
    0
  }
}

Write-Host "`n================ RESULT ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ('{0,-42} {1,5} s  {2}' -f $_.Step, $_.Sec, $_.Result) -ForegroundColor $(if ($_.Result -eq 'OK') { 'Green' } elseif ($_.Result -like 'SKIP*') { 'DarkYellow' } else { 'Red' }) }
if ($fixThai) { Write-Host "`nThai text fix applied - it works after the restart." -ForegroundColor Yellow }
if (-not $Boot) { Write-Host "`nNow SAVE THE IMAGE (super workstation), then reboot this PC. From now on new games are set up at every boot." -ForegroundColor Cyan }
Stop-Transcript | Out-Null
if ($results | Where-Object { $_.Result -like 'FAIL*' }) { exit 1 }
