# OSYNC.ps1 - what OSYNC.bat runs: a numbered menu, or one action by name (OSYNC.bat <action> [arg]).
# Actions: master update watch-on watch-off setup client check | move <Launcher> steam-library build-menu |
#          steam-firstrun ea-install ea-uninstall ea-anticheat eac newthings riot-startup-on riot-startup-off
#          firewall <master|lan|off> boot-off | riot-diag link-scan | migrate | branch [install line] branch-status branch-off
# Actions that change this PC ask for admin (UAC) and run in a new window.
param([string]$Action = '', [string]$Arg = '')
. (Join-Path $PSScriptRoot 'Common.ps1')
# a DOWNLOAD of the project (no Launchers\ and no System\Data\ - the setup makes both) is not an installed OSYNC: its
# settings.txt names the master PC of the shop it came from, so this PC would count as a client and a double-click
# would install client things here. Point to the Easy Install instead (an old layout before step B is not a download).
if (-not (Test-Path -LiteralPath $Launchers) -and -not (Test-Path -LiteralPath $DataDir) -and -not (Test-PreMigration)) {
    Write-Host 'This folder is a download of OSYNC, not an installed OSYNC - nothing was done.' -ForegroundColor Yellow
    Write-Host "Install it first: double-click $Root\EASY-INSTALL.bat   (guide: System\Docs\00-EASY-INSTALL.md)" -ForegroundColor Yellow
    if (-not $env:OSYNC_NOPAUSE) { [void](Read-Host 'Press Enter to close') }
    exit 1
}
$isMaster = Test-IsMaster
$adminActions = 'setup', 'client', 'move', 'steam-library', 'organize', 'steam-firstrun', 'ea-install', 'ea-uninstall', 'ea-anticheat', 'eac', 'newthings',
                'riot-startup-on', 'riot-startup-off', 'firewall', 'boot-off', 'migrate', 'branch', 'branch-off'
# before step B the old layout still runs this folder: actions that write what clients use are blocked
$preB = Test-PreMigration
$blockedPreB = 'master', 'update', 'watch-on', 'setup', 'client', 'move', 'steam-library'

function Pause-End { if (-not $env:OSYNC_NOPAUSE) { Write-Host ''; [void](Read-Host 'Press Enter to close') } }
function Ask([string]$q) { (Read-Host "$q [Y/N]") -match '^[Yy]' }
function Choose-Launcher {
    $i = 0
    foreach ($l in $LauncherTable) { $i++; Write-Host ('  {0,2}  {1}' -f $i, $l.Title) }
    $n = Read-Host 'Which launcher'
    if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $LauncherTable.Count) { return $LauncherTable[[int]$n - 1].Key }
    ''
}

function Invoke-Action([string]$a, [string]$x) {
    if ($preB -and $blockedPreB -contains $a) {
        Write-Host 'Not yet: this folder still runs the old layout (GAMELUNCHER, GCafe, the old buttons).' -ForegroundColor Yellow
        Write-Host 'Do step B first, with the shop closed and every client PC off: 7 Tools > 17.' -ForegroundColor Yellow
        return
    }
    if ($adminActions -contains $a -and -not (Test-Admin)) {
        Write-Host 'This needs administrator rights: press Yes on the Windows prompt.' -ForegroundColor DarkYellow
        $argList = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" ' + $a
        if ($x) { $argList += ' "' + $x + '"' }
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        return
    }
    switch ($a) {
        'update'   { [void](Run-Ps 'Master-Update.ps1') }
        'watch-on' { [void](Run-Ps 'Master-Watch.ps1' @('-Register')) }
        'watch-off' { [void](Run-Ps 'Master-Watch.ps1' @('-Unregister')) }
        'master'   { [void](Run-Ps 'Master-Update.ps1'); Write-Host ''; [void](Run-Ps 'Master-Watch.ps1' @('-Register')) }
        'setup'    { [void](Run-Ps 'Master-Setup.ps1') }
        'client'   {
            if ($isMaster -and -not (Ask 'This PC looks like the MASTER. Install the CLIENT setup here anyway?')) { return }
            [void](Run-Ps 'Client-Install.ps1')
        }
        'check'    { [void](Run-Ps 'Tool-Check.ps1') }
        'move'     {
            $k = if ($x) { $x } else { Choose-Launcher }
            if (-not $k) { return }
            $rc = Run-Ps 'Master-Move-Launcher.ps1' @('-Launcher', $k, '-DryRun')
            if ($rc -ne 0) { return }
            if (Ask "Move $k now (it will be closed)?") { [void](Run-Ps 'Master-Move-Launcher.ps1' @('-Launcher', $k)) }
        }
        'steam-library' {
            $rc = Run-Ps 'Master-Steam-Library.ps1' @('-DryRun')
            if ($rc -ne 0) { return }
            if (Ask 'Move these Steam games now (Steam will be closed)?') { [void](Run-Ps 'Master-Steam-Library.ps1') }
        }
        'build-menu' {
            $b = Join-Path $Menu 'tools\_system\Build-App.ps1'
            if (-not (Test-Path -LiteralPath $b)) { Write-Host "not found: $b"; return }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $b
        }
        'steam-firstrun' { [void](Run-Ps 'Client-Steam-FirstRun.ps1') }
        'ea-install'     { [void](Run-Ps 'Client-EA.ps1') }
        'ea-uninstall'   { [void](Run-Ps 'Client-EA.ps1' @('-Uninstall')) }
        'ea-anticheat'   { [void](Run-Ps 'Client-EA-AntiCheat.ps1') }
        'eac'            { [void](Run-Ps 'Client-EAC.ps1') }
        'newthings'      { [void](Run-Ps 'Client-NEWTHINGS.ps1' $(if (Ask 'Also fix Thai text in games (needs a restart)?') { @('-FixThaiText') } else { @() })) }
        'riot-startup-on' {
            $vbs = Join-Path $ClientDir 'Riot.vbs'
            Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotStart -Value ('wscript.exe "' + $vbs + '" background')
            Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name RiotClient -ErrorAction SilentlyContinue
            Write-Host "Riot silent start at logon: ON (all users) -> $vbs"
        }
        'riot-startup-off' {
            foreach ($k in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run') { Remove-ItemProperty $k -Name RiotStart -ErrorAction SilentlyContinue }
            Write-Host 'Riot silent start at logon: OFF'
        }
        'firewall' { [void](Run-Ps 'Client-Firewall.ps1' @('-From', $(if ($x) { $x } else { 'master' }))) }
        'boot-off' { & schtasks.exe /Delete /TN OSYNC-Client-Boot /F; Write-Host 'New games are no longer set up at boot. Back on: OSYNC.bat client' }
        'riot-diag' { [void](Run-Ps 'Tool-RiotDiag.ps1') }
        'link-scan' { [void](Run-Ps 'Tool-LinkScan.ps1') }
        'migrate'  { [void](Run-Ps 'Tool-Migrate.ps1') }
        'pack'     { [void](Run-Ps 'Tool-Pack.ps1') }
        'plan'     { [void](Run-Ps 'Setup-Plan.ps1' @('-OutFile', (Join-Path $DataDir 'setup-plan.txt'))) }
        'sunshine-profiles' {
            $rc = Run-Ps 'Tool-SunshineProfiles.ps1' @('-DryRun')
            if ($rc -eq 0 -and (Ask 'Write these PC profiles into the Sunshine 0JAYSHOP config?')) { [void](Run-Ps 'Tool-SunshineProfiles.ps1') }
        }
        'branch'   { [void](Run-Ps 'Branch-Runner.ps1' $(if ($x) { @('-Install', '-Command', $x) } else { @('-Install') })) }
        'branch-status' { [void](Run-Ps 'Branch-Runner.ps1' @('-Status')) }
        'branch-off' { if (Ask 'Remove the branch runner from this PC (the web can no longer wake this branch''s PCs)?') { [void](Run-Ps 'Branch-Runner.ps1' @('-Uninstall')) } }
        'organize' {
            $rc = Run-Ps 'Tool-Organize-Drive.ps1' @('-DryRun')
            if ($rc -eq 0 -and (Ask 'Shop closed and every client PC off - move these now?')) { [void](Run-Ps 'Tool-Organize-Drive.ps1') }
        }
        default    { Write-Host "Unknown action: $a" -ForegroundColor Red }
    }
}

function Show-Tools {
    $items = [ordered]@{
        '1' = @('move', 'Move a launcher into Launchers'); '2' = @('steam-library', 'Move Steam games into GAME\Steam')
        '3' = @('build-menu', 'Build the menu program (after a change in Menu\source or the logo)')
        '18' = @('organize', 'Tidy the game drive: Games\, Tools\ (shop closed)')
        '19' = @('pack', 'Make OSYNC-Setup.exe: one file that installs / updates OSYNC on any master')
        '23' = @('plan', 'Check this master: where each part should go (read only)')
        '24' = @('sunshine-profiles', 'Sunshine 0JAYSHOP: PC profiles from Settings SunshineIpBase / SunshinePcPrefix / SunshinePcCount')
        '4' = @('steam-firstrun', 'Steam first-run setup only'); '5' = @('ea-install', 'EA app + EA AntiCheat only'); '6' = @('ea-uninstall', 'EA app: remove')
        '7' = @('eac', 'EasyAntiCheat only'); '8' = @('newthings', 'NEWTHINGS-GAMES (GTA SA) + Thai text fix')
        '9' = @('riot-startup-on', 'Riot silent start at logon: ON'); '10' = @('riot-startup-off', 'Riot silent start at logon: OFF')
        '11' = @('firewall:master', 'Firewall ON + allow remote from the master'); '12' = @('firewall:lan', 'Firewall: allow remote from the whole LAN')
        '13' = @('firewall:off', 'Firewall: remove the allow rule'); '14' = @('boot-off', 'Stop setting up new games at boot')
        '15' = @('riot-diag', 'Riot shows REPAIR: make a report'); '16' = @('link-scan', 'Broken folder links: make a report')
        '20' = @('branch', 'Branch runner: install / move / re-install (install line from admin page > Branches)')
        '21' = @('branch-status', 'Branch runner: state (web link + OSYNC)'); '22' = @('branch-off', 'Branch runner: remove')
    }
    if (Test-Path -LiteralPath $OldLauncherRoot) { $items['17'] = @('migrate', 'Step B: switch this folder to the new layout (shop closed, client PCs off)') }
    Write-Host ''
    Write-Host ' Tools' -ForegroundColor Cyan
    Write-Host '  Master' -ForegroundColor DarkGray
    foreach ($k in '23', '1', '2', '18', '3', '19', '24') { Write-Host ('  {0,3}  {1}' -f $k, $items[$k][1]) }
    Write-Host '  Branch (this master <-> the shop web, folder C:\AT9-Branch)' -ForegroundColor DarkGray
    foreach ($k in '20', '21', '22') { Write-Host ('  {0,3}  {1}' -f $k, $items[$k][1]) }
    Write-Host '  Client (super workstation mode, then save the image)' -ForegroundColor DarkGray
    foreach ($k in '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14') { Write-Host ('  {0,3}  {1}' -f $k, $items[$k][1]) }
    Write-Host '  Problems' -ForegroundColor DarkGray
    foreach ($k in '15', '16') { Write-Host ('  {0,3}  {1}' -f $k, $items[$k][1]) }
    if ($items.Contains('17')) { Write-Host ('  {0,3}  {1}' -f '17', $items['17'][1]) -ForegroundColor Yellow }
    Write-Host '    0  Back'
    $c = Read-Host ' Choose'
    if (-not $items.Contains($c)) { return }
    $parts = $items[$c][0] -split ':', 2
    Invoke-Action $parts[0] $(if ($parts.Count -gt 1) { $parts[1] } else { '' })
}

# a client PC: no menu - a double-click on OSYNC.bat installs everything (super workstation mode, then save the image)
if (-not $Action -and -not $isMaster) { $Action = 'client' }
if ($Action) { Invoke-Action $Action.ToLower() $Arg; Pause-End; exit }

while ($true) {
    Clear-Host
    $role = if ($isMaster) { 'MASTER' } else { 'CLIENT' }
    Write-Host (" OSYNC   {0} = {1}   {2}" -f $env:COMPUTERNAME, $role, $Root) -ForegroundColor Cyan
    Write-Host ' ------------------------------------------------------------'
    if ($preB) { Write-Host '  Old layout still running here: 1, 2, 4, 5 wait for step B (7 Tools > 17, shop closed)' -ForegroundColor Yellow }
    Write-Host '  Master' -ForegroundColor DarkGray
    Write-Host '    1  Update clients now (after installing / updating games)'
    Write-Host '    2  Watcher ON  - keep launchers open, update clients by itself'
    Write-Host '    3  Watcher OFF'
    Write-Host '    4  First-time setup of a new master'
    Write-Host '  Client (super workstation mode, then save the image)' -ForegroundColor DarkGray
    Write-Host '    5  Install everything on this client'
    Write-Host '  Both' -ForegroundColor DarkGray
    Write-Host '    6  Check the system'
    Write-Host '    7  Tools ...'
    Write-Host '    0  Exit'
    $c = Read-Host ' Choose'
    switch ($c) {
        '1' { Invoke-Action 'update' '' }
        '2' { Invoke-Action 'watch-on' '' }
        '3' { Invoke-Action 'watch-off' '' }
        '4' { Invoke-Action 'setup' '' }
        '5' { Invoke-Action 'client' '' }
        '6' { Invoke-Action 'check' '' }
        '7' { Show-Tools }
        '0' { exit }
        default { continue }
    }
    Write-Host ''
    [void](Read-Host 'Press Enter for the menu')
}
