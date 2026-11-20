# Client-Firewall.ps1 - CLIENT PC in super workstation (image edit) mode, then save the image (OSYNC.bat > Tools).
# Keeps Windows Firewall ON and still allows remote control from the diskless console on the master.
#   Client-Firewall.ps1 -From master   firewall ON + allow everything that comes from the MASTER only (Settings MasterIP)
#   Client-Firewall.ps1 -From lan      firewall ON + allow everything from the shop LAN (MasterIP's /24)
#   Client-Firewall.ps1 -From off      remove the allow rule (the firewall itself is left as it is)
param([ValidateSet('master', 'lan', 'off')][string]$From = 'master')
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not (Test-Admin)) { Write-Output 'Run as administrator.'; exit 1 }
$rule   = 'OSYNC allow remote'
$master = Get-Setting 'MasterIP' ''
if (-not $master -and $From -ne 'off') { Write-Output 'MasterIP is empty in Settings\settings.txt - set the master PC IP there first (OSYNC-Setup / first-time setup writes it).'; exit 1 }
$lan    = ($master -replace '\.\d+$', '.0') + '/24'
& netsh.exe advfirewall firewall delete rule name="$rule" | Out-Null
& netsh.exe advfirewall firewall delete rule name="OSYNC allow master" | Out-Null
if ($From -eq 'off') { Write-Output "Rule `"$rule`" removed."; exit 0 }
$ip = if ($From -eq 'lan') { $lan } else { $master }
# 1) the firewall service must run (some images disable it)
$svc = Get-Service -Name mpssvc -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') { Write-Output 'Windows Firewall service is not running - starting it...'; & sc.exe config mpssvc start= auto | Out-Null; Start-Service mpssvc }
# 2) firewall ON for all profiles  3) allow the remote side in (all ports, only from $ip)
& netsh.exe advfirewall set allprofiles state on | Out-Null
& netsh.exe advfirewall firewall add rule name="$rule" dir=in action=allow remoteip=$ip profile=any enable=yes | Out-Null
# a group policy can force the firewall off - warn about it
$pol = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile' -ErrorAction SilentlyContinue).EnableFirewall
if ($pol -eq 0) { Write-Output 'WARNING a policy turns the firewall off on this image (HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall) - remove it, or the firewall stays off.' }
& netsh.exe advfirewall show allprofiles state
Write-Output "Firewall is ON and remote is allowed from $ip. Test remote from the console now; if it works: SAVE THE IMAGE."
