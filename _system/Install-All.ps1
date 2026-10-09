# Install-All.ps1 - CLIENT PC: everything a client needs, in one run (CLIENT-Install-All.bat).
# Run as administrator in super-workstation (image edit) mode, then save the image.
#   1 Riot   : start Riot silently at logon (prepares the PC for VALORANT / LoL / TFT)
#   2 Steam  : every Steam game's first-run setup (BattlEye, ACE, Ricochet, EasyAntiCheat, Social Club,
#              DirectX, VC++ ...) - also covers Steam games installed later
#   3 EA     : EA app, EA games and EA AntiCheat (Apex, Battlefield)
#   4 EAC    : EasyAntiCheat for games outside Steam's scripts (Fortnite, Dead by Daylight, VRChat ...)
#   5 Menu   : 0JAYSHOP game menu at logon + desktop icon
# Log: C:\Users\Public\OSYNC-Install-All.log
$root = Split-Path -Parent $PSScriptRoot                                    # ...\OSYNC
$kit  = Join-Path $root 'GAMELUNCHER\ClientSetup'
$sys  = Join-Path $kit '_system'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host 'Run as administrator (CLIENT-Install-All.bat asks for it).' -ForegroundColor Red; exit 1 }
Start-Transcript -Path (Join-Path $env:PUBLIC 'OSYNC-Install-All.log') -Force | Out-Null
Write-Host "OSYNC client install on $env:COMPUTERNAME  ($root)" -ForegroundColor Cyan

function Run-Script([string]$file, [string[]]$extra = @()) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @extra 2>&1 | ForEach-Object { "    $_" } | Out-Host
  $LASTEXITCODE
}
$results = New-Object System.Collections.Generic.List[object]
function Step([string]$name, [scriptblock]$body) {
  Write-Host "`n== $name" -ForegroundColor Yellow
  try { $r = & $body } catch { $r = "FAIL: $($_.Exception.Message)" }
  if ($null -eq $r -or $r -eq 0) { $r = 'OK' } elseif ($r -is [int]) { $r = "FAIL (exit $r)" }
  $results.Add([pscustomobject]@{ Step = $name; Result = $r })
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
  Run-Script (Join-Path $sys 'Steam-FirstRun.ps1')
}
Step '3 EA    - EA app, games, EA AntiCheat' {
  if (-not (Test-Path -LiteralPath (Join-Path $sys 'ea-client.reg'))) { return 'SKIP (run MASTER-Update-All.bat on the master first)' }
  Run-Script (Join-Path $sys 'EA-ClientInstall.ps1')
}
Step '4 EAC   - EasyAntiCheat (Epic and others)' {
  Run-Script (Join-Path $sys 'EAC-Install.ps1')
}
Step '5 Menu  - 0JAYSHOP game menu' {
  $s = Join-Path $root 'GCafe\tools\_system\Install-Client.ps1'
  if (-not (Test-Path -LiteralPath (Join-Path $root 'GCafe\app\0JAYSHOP.exe'))) { return 'SKIP (build the menu on the master: GCafe\tools\Build-App.bat)' }
  Run-Script $s
}

Write-Host "`n================ RESULT ================" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ('{0,-42} {1}' -f $_.Step, $_.Result) -ForegroundColor $(if ($_.Result -eq 'OK') { 'Green' } elseif ($_.Result -like 'SKIP*') { 'DarkYellow' } else { 'Red' }) }
Write-Host "`nNow SAVE THE IMAGE (super workstation), then reboot this PC." -ForegroundColor Cyan
Stop-Transcript | Out-Null
if ($results | Where-Object { $_.Result -like 'FAIL*' }) { exit 1 }
