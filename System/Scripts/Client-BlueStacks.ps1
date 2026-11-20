# Client-BlueStacks.ps1 - CLIENT: BlueStacks 5 straight from the game disk (Master-Move-BlueStacks.ps1 put it on a shared
# drive, e.g. F:\Emulator\BlueStacks). Nothing is copied to C:. At boot (Client-Install step 1w, as SYSTEM):
#   1 System\Data\BlueStacks\bluestacks.reg (exported on the master: HKLM\SOFTWARE\BlueStacks_nxt = where it is, and its COM
#     classes / interfaces / type library, as its installer writes them) is imported - skipped when it is there already
#   2 its kernel driver service BlueStacksDrv_nxt points at <program>\BstkDrv_nxt.sys on the game disk, and is started
# The game menu card "BlueStacks 5" then starts <program>\HD-Player.exe like on the master.
#   Client-BlueStacks.ps1            do it          -Check   report only
param([switch]$Check)
. (Join-Path $PSScriptRoot 'Common.ps1')
$src = Join-Path $DataDir 'BlueStacks'
$reg = Join-Path $src 'bluestacks.reg'; $txt = Join-Path $src 'bluestacks.txt'
if (-not (Test-Path -LiteralPath $reg) -or -not (Test-Path -LiteralPath $txt)) { Write-Host 'BlueStacks: not on a game disk yet (no System\Data\BlueStacks - OSYNC.bat > 7 > 25 on the master) - skipped'; exit 0 }
$info = @(Get-Content -LiteralPath $txt -Encoding UTF8)
$prog = "$($info[0])".Trim().TrimEnd('\')
$exe = Join-Path $prog 'HD-Player.exe'; $sys = Join-Path $prog 'BstkDrv_nxt.sys'
if (-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath $sys)) { Write-Host "BlueStacks: $exe / BstkDrv_nxt.sys not found on this PC" ; exit 1 }
$now = "$((Get-ItemProperty -Path 'HKLM:\SOFTWARE\BlueStacks_nxt' -ErrorAction SilentlyContinue).InstallDir)".TrimEnd('\')
$drv = Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'" -ErrorAction SilentlyContinue
if ($Check) { Write-Host "BlueStacks $($info[1]) at $prog | registry: $(if ($now) { $now } else { 'none' }) | driver: $(if ($drv) { "$($drv.State) $($drv.PathName)" } else { 'none' })"; exit 0 }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-Host 'BlueStacks: needs administrator / SYSTEM'; exit 1 }

# 1 registry (where it is + COM) - the export is the master's, made after the move
$stamp = (Get-Item -LiteralPath $reg).LastWriteTimeUtc.ToString('yyyyMMddHHmmss')
$mark = "$((Get-ItemProperty -Path 'HKLM:\SOFTWARE\OSYNC' -Name 'BlueStacksReg' -ErrorAction SilentlyContinue).BlueStacksReg)"
if ($now -ieq $prog -and $mark -eq $stamp) { Write-Host "BlueStacks: registry already from this export ($prog)" }
else {
  $o = @(& reg.exe import $reg 2>&1)
  if ($LASTEXITCODE -ne 0) { Write-Host "BlueStacks: reg import failed ($LASTEXITCODE): $($o -join ' ')"; exit 1 }
  New-Item -Path 'HKLM:\SOFTWARE\OSYNC' -Force | Out-Null; Set-ItemProperty -Path 'HKLM:\SOFTWARE\OSYNC' -Name 'BlueStacksReg' -Value $stamp
  Write-Host "BlueStacks: registry imported (where it is: $prog, COM classes and interfaces)"
}
# 2 the kernel driver from the game disk
$want = "\??\$sys"
if (-not $drv) {
  $o = @(& sc.exe create BlueStacksDrv_nxt type= kernel start= demand binPath= "$want" DisplayName= 'BlueStacksDrv_nxt' 2>&1)
  Write-Host "BlueStacks: driver service created ($($o -join ' ' -replace '\s+', ' '))"
} elseif ($drv.PathName -ine $want) {
  if ($drv.State -eq 'Running') { & sc.exe stop BlueStacksDrv_nxt 2>&1 | Out-Null; Start-Sleep -Seconds 2 }
  & sc.exe config BlueStacksDrv_nxt binPath= "$want" 2>&1 | Out-Null
  Write-Host "BlueStacks: driver service repointed ($($drv.PathName) -> $want)"
}
$drv = Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'" -ErrorAction SilentlyContinue
if ($drv -and $drv.State -ne 'Running') { $o = @(& sc.exe start BlueStacksDrv_nxt 2>&1); Start-Sleep -Seconds 2; $drv = Get-CimInstance Win32_SystemDriver -Filter "Name='BlueStacksDrv_nxt'" -ErrorAction SilentlyContinue; if ($drv.State -ne 'Running') { Write-Host "BlueStacks: driver did not start: $(($o -join ' ') -replace '\s+', ' ')"; exit 1 } }
Write-Host "BlueStacks $($info[1]): ready - driver $($drv.State) from $sys"
exit 0
