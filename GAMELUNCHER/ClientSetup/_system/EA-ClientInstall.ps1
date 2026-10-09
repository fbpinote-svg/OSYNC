# EA-ClientInstall.ps1 - register the shared EA app (H:\OSYNC\GAMELUNCHER\EA Desktop) on a client.
# Diskless: run ONCE as administrator in super-workstation (image edit) mode so it stays in the image.
#   EA-ClientInstall.ps1              install (registry, EABackgroundService, protocols, shortcuts)
#   EA-ClientInstall.ps1 -Autostart   also start EA silently at logon
#   EA-ClientInstall.ps1 -Uninstall   remove what this script added
#   EA-ClientInstall.ps1 -DryRun      show only
param([switch]$Autostart, [switch]$Uninstall, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
$setupDir = Split-Path -Parent $MyInvocation.MyCommand.Path               # ...\ClientSetup\_system
$eaRoot   = Join-Path (Split-Path -Parent (Split-Path -Parent $setupDir)) 'EA Desktop'
$exeDir   = Join-Path $eaRoot 'EA Desktop'
$svcExe   = Join-Path $exeDir 'EABackgroundService.exe'
$launcher = Join-Path $exeDir 'EALauncher.exe'
$regFile  = Join-Path $setupDir 'ea-client.reg'
$svcPath  = '"' + $svcExe + '" -start'
$lnks     = @('C:\Users\Public\Desktop\EA.lnk', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\EA\EA.lnk')
function Say($m) { Write-Host $m }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run as administrator.' }
$svc = Get-CimInstance Win32_Service -Filter "Name='EABackgroundService'"

if ($Uninstall) {
    Say 'Uninstall shared EA registration'
    if ($DryRun) { Say "  would remove service, HKLM EA keys pointing to $eaRoot, shortcuts, autostart"; return }
    if ($svc) {
        if ($svc.PathName -notlike "*$eaRoot*") { Say "  service points elsewhere ($($svc.PathName)) - left alone" }
        else { Stop-Service EABackgroundService -Force -ErrorAction SilentlyContinue; Invoke-CimMethod -InputObject $svc -MethodName Delete | Out-Null; Say '  service removed' }
    }
    foreach ($k in 'HKLM:\SOFTWARE\Electronic Arts\EA Desktop', 'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts\EA Desktop') {
        if ((Test-Path $k) -and ((Get-ItemProperty $k).ClientPath -like "$eaRoot*")) { Remove-Item $k -Recurse -Force; Say "  removed $k" }
    }
    Remove-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name EADM -ErrorAction SilentlyContinue
    foreach ($l in $lnks) { if (Test-Path $l) { Remove-Item $l -Force; Say "  removed $l" } }
    return
}

foreach ($f in $svcExe, $launcher, $regFile) { if (-not (Test-Path -LiteralPath $f)) { throw "missing: $f  (move EA to H: on the master and run Snapshot-EA.ps1 first)" } }
Say "EA app: $exeDir"
if ($svc) { Say "existing service: $($svc.PathName)" } else { Say 'service: will be created' }
if ($DryRun) { Say "would import $regFile, set service -> $svcPath, shortcuts, autostart=$Autostart"; return }

# 1) registry: install paths + origin/origin2/link2ea/ealink protocols
# reg.exe prints its success message on stderr, which Windows PowerShell 5.1 turns into a
# terminating error under -ErrorAction Stop; run it as a process and check the exit code instead.
$p = Start-Process -FilePath reg.exe -ArgumentList ('import "' + $regFile + '"') -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0) { throw "reg import failed ($($p.ExitCode))" }
Say 'registry imported'

# 1b) EA-app games on the shared disks: install-check keys, uninstall keys and EA install records
$gamesReg = Join-Path $setupDir 'ea-games.reg'
if (Test-Path -LiteralPath $gamesReg) {
    $p = Start-Process -FilePath reg.exe -ArgumentList ('import "' + $gamesReg + '"') -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0) { Say "WARNING game registry import failed ($($p.ExitCode))" } else { Say 'game registry imported' }
}
$srcData = Join-Path $setupDir 'EA-InstallData'
if (Test-Path -LiteralPath $srcData) {
    $dstData = Join-Path $env:ProgramData 'EA Desktop\InstallData'
    New-Item -ItemType Directory -Force -Path $dstData | Out-Null
    & robocopy.exe $srcData $dstData /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
    Say ("EA install records copied: " + ((Get-ChildItem $srcData -Directory | ForEach-Object Name) -join ', '))
}

# 2) background service (needed to install/launch EA games)
if ($svc) {
    if ($svc.State -ne 'Stopped') { Stop-Service EABackgroundService -Force }
    $r = Invoke-CimMethod -InputObject $svc -MethodName Change -Arguments @{ PathName = $svcPath }
    if ($r.ReturnValue -ne 0) { throw "service change failed ($($r.ReturnValue))" }
} else {
    New-Service -Name EABackgroundService -BinaryPathName $svcPath -DisplayName 'EABackgroundService' -StartupType Manual | Out-Null
}
Say "service -> $svcPath"

# 3) shortcuts
$sh = New-Object -ComObject WScript.Shell
foreach ($l in $lnks) {
    New-Item -ItemType Directory -Force -Path (Split-Path $l) | Out-Null
    $s = $sh.CreateShortcut($l); $s.TargetPath = $launcher; $s.WorkingDirectory = $exeDir; $s.IconLocation = "$launcher,0"; $s.Save()
}
Say 'shortcuts created'

# 4) optional silent start at logon (all users)
if ($Autostart) {
    Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name EADM -Value ('"' + $launcher + '" -silentOs')
    Say 'autostart: EA starts silently at logon'
}

# 5) check
Start-Service EABackgroundService
Start-Sleep -Seconds 2
$svc = Get-CimInstance Win32_Service -Filter "Name='EABackgroundService'"
Say ("EABackgroundService: {0}  {1}" -f $svc.State, $svc.PathName)
Say ("registry ClientPath: " + (Get-ItemProperty 'HKLM:\SOFTWARE\Electronic Arts\EA Desktop').ClientPath)
Say 'Done.'
