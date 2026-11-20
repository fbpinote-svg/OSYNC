# Client-Roblox.ps1 - Roblox from the game disk (System\Client\Roblox.vbs runs this as the logged-on user).
# Roblox installs per user (%LOCALAPPDATA%\Roblox) and renames its folder at every update (Versions\version-<hash>).
# On the master %LOCALAPPDATA%\Roblox\Versions is a junction to Launchers\Roblox\Versions, so Roblox updates land
# on the game disk. On a client this script points the roblox:// and roblox-player:// links (HKCU) at the newest
# version there, so "Play" on roblox.com and the menu card start Roblox straight from the game disk - no install.
# If the game disk is behind Roblox's current version, Roblox updates itself into the client's own %LOCALAPPDATA%
# (gone at reboot): open Roblox on the master once to update the game disk.
#   -Mode background   only point the links (at logon: Run\RobloxPrep, set by Client-Install.ps1)
#   -Mode launch       point the links, then start Roblox (menu card)
#   -DryRun            show what would be written, change nothing
# Log: C:\Users\Public\OSYNC-Roblox.log
param([ValidateSet('background', 'launch')][string]$Mode = 'launch', [switch]$DryRun)
. (Join-Path $PSScriptRoot 'Common.ps1')
$log = Join-Path $env:PUBLIC 'OSYNC-Roblox.log'
function Log([string]$m) {
  $line = '{0:yyyy-MM-dd HH:mm:ss} {1} {2} {3}' -f (Get-Date), $env:COMPUTERNAME, $env:USERNAME, $m
  if ($DryRun) { Write-Output $line } else { try { Add-Content -LiteralPath $log -Value $line -Encoding UTF8 } catch { } }
}
$exe = Get-RobloxExe
if (-not $exe) { Log "no Roblox in $(Join-Path $Launchers 'Roblox\Versions')"; exit 1 }
$dir = Split-Path -Parent $exe
$ver = Split-Path -Leaf $dir

# the master keeps Roblox's own registration (its updater writes it, through the junction); only clients are pointed
if (Test-IsMaster) { Log "master: Roblox's own links are kept ($ver)" }
else {
  $want = New-Object System.Collections.Generic.List[object]
  foreach ($p in 'roblox', 'roblox-player') {
    $c = "HKCU:\Software\Classes\$p"
    $want.Add(@($c, '(default)', 'URL: Roblox Protocol')); $want.Add(@($c, 'URL Protocol', '')); $want.Add(@("$c\DefaultIcon", '(default)', "`"$exe`",0"))
    $want.Add(@("$c\shell\open\command", '(default)', "`"$exe`" %1")); $want.Add(@("$c\shell\open\command", 'version', $ver))
  }
  $env0 = 'HKCU:\Software\ROBLOX Corporation\Environments\roblox-player'
  $want.Add(@($env0, '(default)', (Join-Path $dir 'RobloxPlayerInstaller.exe'))); $want.Add(@($env0, 'baseHost', 'www.roblox.com'))
  $want.Add(@($env0, 'version', $ver)); $want.Add(@($env0, 'clientExe', $exe))
  $changed = 0
  foreach ($w in $want) {
    $k = $w[0]; $n = $w[1]; $v = $w[2]
    $o = try { Get-ItemProperty -LiteralPath $k -ErrorAction Stop } catch { $null }
    if ($o -and ($o.PSObject.Properties.Name -contains $n) -and ("$($o.$n)" -ceq $v)) { continue }
    $changed++
    if ($DryRun) { Write-Output "  would set $k [$n] = $v"; continue }
    if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
    if ($n -eq '(default)') { Set-Item -LiteralPath $k -Value $v } else { New-ItemProperty -LiteralPath $k -Name $n -Value $v -PropertyType String -Force | Out-Null }
  }
  Log "links -> $exe ($changed values $(if ($DryRun) { 'to change' } else { 'changed' }))"
}
if ($Mode -eq 'launch') {
  if ($DryRun) { Write-Output "  would start $exe" }
  else { Start-Process -FilePath $exe -WorkingDirectory $dir; Log "started $ver" }
}
