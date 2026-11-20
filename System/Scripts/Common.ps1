# Common.ps1 - dot-sourced by every script in System\Scripts. The ONLY place that knows where things are.
# Works from any folder on any game drive (nothing below is tied to E: or to one shop):
#   <drive>:\Autosync\       OSYNC.bat, README.md
#     Settings\              settings.txt (SharedDrives, MasterIP, Role, GamesFolder), extra-games.json   <- the shop edits these
#     Launchers\             Steam\ Riot Client\ EA\ Epic\ Garena\ Ubisoft\ Rockstar\ HoYoPlay\ Modrinth\ BattleNet\ GOG\ Nexon\ Amazon\
#     GAME\                  the games: Steam\ Garena\ HoYoPlay\ Online\ Gacha\ ... (GamesFolder)
#     Menu\                  game menu program (GCafe): app\ data\ source\ tools\ config.json
#     Tools\                 shop tools that are not games (Discord, RustDesk ...; OSLink stays in X:\LDPlayer)
#     System\Client\         files the client image / menu call: Boot.ps1 Riot.vbs Epic.vbs Menu.vbs  (never move)
#     System\Scripts\        this folder
#     System\Data\           made by the master for clients: Riot\ EA\ Epic\ EAC\
#     System\Docs\  System\Backup\
# Tests before the move (step B): $env:OSYNC_LAUNCHERS / $env:OSYNC_MENU point at the old folders.
$ScriptsDir  = $PSScriptRoot
$SystemDir   = Split-Path -Parent $ScriptsDir
$Root        = Split-Path -Parent $SystemDir
$SettingsDir = Join-Path $Root 'Settings'
$Launchers   = Join-Path $Root 'Launchers'
$Menu        = Join-Path $Root 'Menu'
$ClientDir   = Join-Path $SystemDir 'Client'
$DataDir     = Join-Path $SystemDir 'Data'
$DocsDir     = Join-Path $SystemDir 'Docs'
$BackupDir   = Join-Path $SystemDir 'Backup'
if ($env:OSYNC_LAUNCHERS) { $Launchers = $env:OSYNC_LAUNCHERS }
if ($env:OSYNC_MENU)      { $Menu = $env:OSYNC_MENU }
if ($env:OSYNC_SETTINGS)  { $SettingsDir = $env:OSYNC_SETTINGS }     # tests (admin console simulation)
# the layout before step B, in this same folder: GAMELUNCHER\ (launchers + ClientSetup), GCafe\, _system\
$OldLauncherRoot = Join-Path $Root 'GAMELUNCHER'
$OldMenuDir      = Join-Path $Root 'GCafe'
# $true while the old layout still runs this folder (step B not done): scripts that write what clients use must not run
function Test-PreMigration { (-not $env:OSYNC_LAUNCHERS) -and (Test-Path -LiteralPath $OldLauncherRoot) -and -not (Test-Path -LiteralPath (Join-Path $Root 'Launchers')) }
function Stop-IfPreMigration([string]$What) {
    if (Test-PreMigration) {
        Write-Host "$What : not yet - this folder still runs the old layout (GAMELUNCHER, GCafe)." -ForegroundColor Yellow
        Write-Host 'Do step B first (shop closed, client PCs off): OSYNC.bat > 7 Tools > 17' -ForegroundColor Yellow
        exit 2
    }
}
$SettingsFile   = Join-Path $SettingsDir 'settings.txt'
$ExtraGamesFile = Join-Path $SettingsDir 'extra-games.json'

# ---------- settings ----------
# Settings\settings.txt: "Key=Value" lines, # = comment
function Get-Setting([string]$Name, [string]$Default = '') {
    if (Test-Path -LiteralPath $SettingsFile) {
        $line = Get-Content -LiteralPath $SettingsFile -Encoding UTF8 | Where-Object { $_ -match "^\s*$Name\s*=" } | Select-Object -First 1
        if ($line) { $v = ($line -split '=', 2)[1].Trim(); if ($v) { return $v } }
    }
    $Default
}
# drive letters the CLIENT PCs see (same letters as on the master); empty = every fixed drive except the system drive
function Get-SharedDrives {
    $v = ((Get-Setting 'SharedDrives') -replace '[^A-Za-z]', '').ToUpper()
    if (-not $v) {
        $sys = $env:SystemDrive.Substring(0, 1).ToUpper()
        $v = ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID.Substring(0, 1).ToUpper() } | Where-Object { $_ -ne $sys }) -join '')
    }
    $v
}
# the games folder (Settings GamesFolder, relative to this OSYNC folder or a full path; default GAME) and the tools folder
$GamesRoot = Get-Setting 'GamesFolder' 'GAME'
if (-not [IO.Path]::IsPathRooted($GamesRoot)) { $GamesRoot = Join-Path $Root $GamesRoot }
$ToolsDir = Join-Path $Root 'Tools'
# every game folder: GamesFolder (the main one = {GAMES}) + Settings GameFolders (more drives, e.g. D:\GAME;F:\GAME - each
# laid out like GAME\: Online\ Mobile\ Garena\ ...). Folders that exist only; the main one first. The admin console adds them.
function Get-GameFolders {
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add($GamesRoot.TrimEnd('\'))
    $more = if ($env:OSYNC_GAMEFOLDERS) { $env:OSYNC_GAMEFOLDERS } else { Get-Setting 'GameFolders' '' }   # env = tests
    foreach ($p in ($more -split '[;,|]')) {
        $p = $p.Trim().Trim('"')
        if (-not $p) { continue }
        if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $Root $p }
        $p = $p.TrimEnd('\')
        if (-not ($list | Where-Object { $_ -ieq $p })) { $list.Add($p) }
    }
    @($list | Where-Object { Test-Path -LiteralPath $_ })
}
# the online library's shared key (hub + every branch): System\Data\Online\online.key - not in Settings (that goes to git)
function Get-OnlineSecret {
    if ($env:OSYNC_ONLINEKEY) { return $env:OSYNC_ONLINEKEY }
    $f = Join-Path $DataDir 'Online\online.key'
    if (Test-Path -LiteralPath $f) { "$(Get-Content -LiteralPath $f -Raw)".Trim() } else { '' }
}
function Read-ExtraGames {
    if (-not (Test-Path -LiteralPath $ExtraGamesFile)) { return $null }
    (Get-Content -LiteralPath $ExtraGamesFile -Raw -Encoding UTF8) | ConvertFrom-Json
}
# run another script of System\Scripts in this console (its output and colors go straight to the screen,
# it can ask questions); returns only its exit code
function Run-Ps([string]$File, [string[]]$ArgList = @()) {
    $list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $ScriptsDir $File) + '"'))
    foreach ($a in $ArgList) { $list += $(if ($a -match '\s' -or $a -eq '') { '"' + $a + '"' } else { $a }) }
    (Start-Process -FilePath powershell.exe -ArgumentList $list -NoNewWindow -Wait -PassThru).ExitCode
}
# this PC's shop-LAN IPv4: the adapter that has the default gateway, else the first private address
function Get-LanIP {
    $c = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue)
    $ip = $c | Where-Object { $_.DefaultIPGateway } | ForEach-Object { $_.IPAddress } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -notmatch '^169\.254\.' } | Select-Object -First 1
    if (-not $ip) { $ip = $c | ForEach-Object { $_.IPAddress } | Where-Object { $_ -match '^(10|192\.168|172\.(1[6-9]|2\d|3[01]))\.' } | Select-Object -First 1 }
    "$ip"
}
# Sunshine 0JAYSHOP port plan (Tools\Sunshine0J; Client-Sunshine0J.ps1 and Tool-SunshineProfiles.ps1): client PC n has the IP
# <net>.(offset + n) and the port 20000 + n x 100 (web page = port + 1), name <prefix><n, 2 digits>. Settings SunshineIpBase
# (<net>.<offset>), SunshinePcPrefix, SunshinePcCount; empty = this shop's plan 192.168.51.100 / KORI / 72.
function Get-SunshinePlan {
    $b = Get-Setting 'SunshineIpBase' '192.168.51.100'
    if (-not ($b -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})$')) { [void]('192.168.51.100' -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})$') }
    $net = $Matches[1]; $off = [int]$Matches[2]
    $c = 0; if (-not [int]::TryParse((Get-Setting 'SunshinePcCount' '72'), [ref]$c)) { $c = 72 }
    $c = [Math]::Max(0, [Math]::Min([Math]::Min(99, 254 - $off), $c))
    [pscustomobject]@{ Net = $net; Offset = $off; Prefix = (Get-Setting 'SunshinePcPrefix' 'KORI'); Count = $c }
}function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
# master or client: Settings Role=master|client wins; else a diskless SERVER program on this PC (LW / Kritidet / CCU,
# CCBoot, iCafeCloud, NxD, ggRock ...) or the OSYNC watcher's autostart = master; anything else = client
$DisklessServerFolders  = 'C:\lwserver', 'C:\Program Files\CCBoot', 'C:\Program Files (x86)\CCBoot', 'C:\iCafeCloud\Server', 'C:\Program Files\iCafeCloud Server', 'C:\NxD\Server', 'C:\ggRock'
$DisklessServerServices = '(?i)^(lwdiskless|lwserver|CCBoot|iCafeCloudServer|iCafe8Server|NxdServer|ggRock|SmartBoot|DisklessServer)'
function Test-IsMaster {
    # MasterPC=<computer name> (written by OSYNC-Setup): settings.txt is shared with the clients, so naming the master
    # PC is the only setting that is right on every PC of the shop, whatever the diskless program
    $mp = Get-Setting 'MasterPC' ''
    if ($mp) { return ($env:COMPUTERNAME -ieq $mp.Trim()) }
    $role = (Get-Setting 'Role' 'auto').ToLower()
    if ($role -eq 'master') { return $true }
    if ($role -eq 'client') { return $false }
    if ($DisklessServerFolders | Where-Object { Test-Path -LiteralPath $_ }) { return $true }
    if (Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $DisklessServerServices }) { return $true }
    [bool](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).'OSYNC-Master'
}

# ---------- launchers ----------
# Dir = folder in Launchers\ (Old = name used before, still found); Exe = start program inside it; Proc = process names
$LauncherTable = @(
    [pscustomobject]@{ Key = 'Steam';    Title = 'Steam';                Dir = 'Steam';    Old = '';                        Exe = 'steam.exe';                                     Proc = @('steam');                        Args = '-silent' }
    # Riot: the folder MUST be named "Riot Client" - Riot Client reinstalls itself into <parent>\Riot Client otherwise
    [pscustomobject]@{ Key = 'Riot';     Title = 'Riot Client';          Dir = 'Riot Client'; Old = @('Riot', 'RiotClient');   Exe = 'RiotClientServices.exe';                        Proc = @('RiotClientServices', 'Riot Client'); Args = '' }
    [pscustomobject]@{ Key = 'EA';       Title = 'EA app';               Dir = 'EA';       Old = 'EA Desktop';              Exe = 'EA Desktop\EALauncher.exe';                     Proc = @('EADesktop', 'EALauncher');      Args = '-silentOs' }
    [pscustomobject]@{ Key = 'Epic';     Title = 'Epic Games';           Dir = 'Epic';     Old = 'Epic Games';              Exe = 'Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'; Proc = @('EpicGamesLauncher');   Args = '-silent' }
    [pscustomobject]@{ Key = 'Garena';   Title = 'Garena';               Dir = 'Garena';   Old = '';                        Exe = 'Garena.exe';                                    Proc = @('Garena');                       Args = '' }
    [pscustomobject]@{ Key = 'Ubisoft';  Title = 'Ubisoft Connect';      Dir = 'Ubisoft';  Old = '';                        Exe = 'Ubisoft Game Launcher\UbisoftConnect.exe';      Proc = @('upc', 'UbisoftConnect');        Args = '' }
    [pscustomobject]@{ Key = 'Rockstar'; Title = 'Rockstar Games';       Dir = 'Rockstar'; Old = 'Rockstar Games Launcher'; Exe = 'LauncherPatcher.exe';                           Proc = @('Launcher', 'LauncherPatcher');  Args = '' }
    [pscustomobject]@{ Key = 'HoYoPlay'; Title = 'HoYoPlay';             Dir = 'HoYoPlay'; Old = '';                        Exe = 'launcher.exe';                                  Proc = @('HYP');                          Args = '' }
    [pscustomobject]@{ Key = 'Modrinth'; Title = 'Modrinth (Minecraft)'; Dir = 'Modrinth'; Old = 'Modrinth App';            Exe = 'Modrinth App.exe';                              Proc = @('Modrinth App');                 Args = '' }
    [pscustomobject]@{ Key = 'BattleNet'; Title = 'Battle.net';          Dir = 'BattleNet'; Old = 'Battle.net';             Exe = 'Battle.net Launcher.exe';                       Proc = @('Battle.net');                   Args = '' }
    [pscustomobject]@{ Key = 'GOG';      Title = 'GOG Galaxy';           Dir = 'GOG';      Old = 'GOG Galaxy';              Exe = 'GalaxyClient.exe';                              Proc = @('GalaxyClient');                 Args = '' }
    [pscustomobject]@{ Key = 'Nexon';    Title = 'Nexon Plug';           Dir = 'Nexon';    Old = 'Nexon Plug';              Exe = 'NexonPlug.exe';                                 Proc = @('NexonPlug');                    Args = '' }
    [pscustomobject]@{ Key = 'Amazon';   Title = 'Amazon Games';         Dir = 'Amazon';   Old = 'Amazon Games';            Exe = 'Amazon Games.exe';                              Proc = @('Amazon Games');                 Args = '' }
)
# install folder of a program from its uninstall entry (DisplayName matched as a regex): InstallLocation, else the folder of its icon / uninstaller
function Find-UninstallPath([string]$NamePattern) {
    foreach ($r in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in Get-ChildItem $r -ErrorAction SilentlyContinue) {
            if ("$($k.GetValue('DisplayName'))" -notmatch $NamePattern) { continue }
            $p = ("$($k.GetValue('InstallLocation'))" -replace '"', '').TrimEnd('\')
            if (-not $p) { foreach ($v in 'DisplayIcon', 'UninstallString') { $m = [regex]::Match("$($k.GetValue($v))", '^"?([A-Za-z]:\\[^",]+?\.exe)'); if ($m.Success) { $p = Split-Path -Parent $m.Groups[1].Value; break } } }
            if ($p -and (Test-Path -LiteralPath $p)) { return $p }
        }
    }
    ''
}
function Get-Launcher([string]$Key) { $LauncherTable | Where-Object Key -eq $Key | Select-Object -First 1 }
function Get-LauncherDir([string]$Key) {
    $l = Get-Launcher $Key
    $d = Join-Path $Launchers $l.Dir
    if (-not (Test-Path -LiteralPath $d)) { foreach ($n in @($l.Old)) { if ($n) { $o = Join-Path $Launchers $n; if (Test-Path -LiteralPath $o) { return $o } } } }
    $d
}
function Get-LauncherExe([string]$Key) { Join-Path (Get-LauncherDir $Key) (Get-Launcher $Key).Exe }
# Roblox (per-user app, not in the table: nothing keeps it open): Launchers\Roblox\Versions\version-<hash>\RobloxPlayerBeta.exe,
# newest one; the master's %LOCALAPPDATA%\Roblox\Versions is a junction to that folder so Roblox updates land there
function Get-RobloxExe {
    $v = Join-Path $Launchers 'Roblox\Versions'
    $e = Get-ChildItem -LiteralPath $v -Directory -Filter 'version-*' -ErrorAction SilentlyContinue | ForEach-Object { Get-Item -LiteralPath (Join-Path $_.FullName 'RobloxPlayerBeta.exe') -ErrorAction SilentlyContinue } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($e) { $e.FullName } else { '' }
}
# where the launcher is installed according to its own registry/config (wherever that is), '' = not installed
function Get-LauncherInstallPath([string]$Key) {
    function RegVal($k, $n) { try { (Get-ItemProperty -Path $k -ErrorAction Stop).$n } catch { $null } }
    $p = switch ($Key) {
        'Steam'    { RegVal 'HKCU:\Software\Valve\Steam' 'SteamPath' }
        'Riot'     { try { Split-Path -Parent ((Get-Content (Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json') -Raw | ConvertFrom-Json).rc_default) } catch { $null } }
        'EA'       { RegVal 'HKLM:\SOFTWARE\Electronic Arts\EA Desktop' 'InstallLocation' }
        'Epic'     { RegVal 'HKLM:\SOFTWARE\EpicGames\Unreal Engine' 'INSTALLDIR' }
        'Garena'   { $g = RegVal 'HKLM:\SOFTWARE\WOW6432Node\Garena\gxx' 'path'; if ($g) { Split-Path -Parent $g } }
        'Ubisoft'  { RegVal 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher' 'InstallDir' }
        'Rockstar' { RegVal 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Launcher' 'InstallFolder' }
        'HoYoPlay' { RegVal 'HKCU:\Software\Cognosphere\HYP\1_0' 'InstallPath' }
        'Modrinth' { (RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Modrinth App' 'InstallLocation') -replace '"', '' }
        'BattleNet' { Find-UninstallPath '^Battle\.net$' }
        'GOG'      { Find-UninstallPath '^GOG GALAXY' }
        'Nexon'    { Find-UninstallPath '(?i)nexon ?plug' }
        'Amazon'   { Find-UninstallPath '^Amazon Games$' }
    }
    $p = ("$p" -replace '/', '\').TrimEnd('\')
    if ($p -and (Test-Path -LiteralPath $p)) { $p } else { '' }
}

# ---------- Steam ----------
# the Steam folder in Launchers (shared, so clients use it too); on a master not set up yet: where Steam says it is
function Get-SteamDir {
    $d = Get-LauncherDir 'Steam'
    if (Test-Path -LiteralPath (Join-Path $d 'steam.exe')) { return $d }
    $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($p) { return ($p -replace '/', '\') }
    ''
}
# every Steam library folder on the shared drives (read from Steam's libraryfolders.vdf, plus X:\Games\Steam / X:\SteamLibrary / X:\Steam)
function Get-SteamLibraries {
    $shared = Get-SharedDrives
    $libs = New-Object System.Collections.Generic.List[string]
    $steam = Get-SteamDir
    if ($steam) {
        $libs.Add($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) { [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"') | ForEach-Object { $libs.Add(($_.Groups[1].Value -replace '\\\\', '\')) } }
    }
    $libs.Add((Join-Path $GamesRoot 'Steam'))
    foreach ($d in $shared.ToCharArray()) { $libs.Add("${d}:\Games\Steam"); $libs.Add("${d}:\SteamLibrary"); $libs.Add("${d}:\Steam") }
    $seen = @{}
    foreach ($l in $libs) {
        $l = $l.TrimEnd('\')
        if (-not $l -or $seen.ContainsKey($l.ToLower())) { continue }
        $seen[$l.ToLower()] = 1
        if ($shared.IndexOf($l.Substring(0, 1).ToUpper()) -lt 0) { continue }
        if (Test-Path -LiteralPath (Join-Path $l 'steamapps\common')) { $l }
    }
}

# ---------- FiveM / RedM ----------
# FiveM runs on GTA V Legacy (Steam 271590 - not Enhanced 3240220), RedM on Red Dead Redemption 2 (Steam 1174180). They look
# for the game in Rockstar's registry keys - which diskless clients do not have - then ask in a file dialog, and keep the
# answer in <FiveM|RedM>.app\CitizenFX.ini [Game] IVPath=. That file sits on the game disk next to FiveM / RedM, so the
# master writes it once for every client (Master-CitizenFX.ps1, a step of Master-Update).
$CfxGames = @(
    [pscustomobject]@{ Name = 'FiveM'; Game = 'GTA V Legacy'; AppId = '271590'; Exe = 'GTA5.exe'; NotExe = 'GTA5_Enhanced.exe'; Reg = 'Grand Theft Auto V'; Folders = @('Rockstar\Grand Theft Auto V', 'Rockstar Games\Grand Theft Auto V', 'Epic\GTAV') }
    [pscustomobject]@{ Name = 'RedM'; Game = 'Red Dead Redemption 2'; AppId = '1174180'; Exe = 'RDR2.exe'; NotExe = ''; Reg = 'Red Dead Redemption 2'; Folders = @('Rockstar\Red Dead Redemption 2', 'Rockstar Games\Red Dead Redemption 2', 'Epic\RDR2') }
)
# a game folder FiveM / RedM can use: on a drive the clients see, with the game exe (and for FiveM not the Enhanced one)
function Test-CfxGameDir($g, [string]$dir) {
    if (-not $dir -or $dir.Length -lt 3 -or (Get-SharedDrives).IndexOf($dir.Substring(0, 1).ToUpper()) -lt 0) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $dir $g.Exe))) { return $false }
    -not ($g.NotExe -and (Test-Path -LiteralPath (Join-Path $dir $g.NotExe)))
}
# where the game is: Steam libraries (appmanifest), then Rockstar's registry keys, then GAME\Rockstar / GAME\Epic
function Find-CfxGameDir($g) {
    $c = New-Object System.Collections.Generic.List[string]
    foreach ($lib in @(Get-SteamLibraries)) {
        $m = Join-Path $lib "steamapps\appmanifest_$($g.AppId).acf"
        if (Test-Path -LiteralPath $m) { $d = [regex]::Match([IO.File]::ReadAllText($m), '"installdir"\s+"([^"]+)"').Groups[1].Value; if ($d) { $c.Add((Join-Path $lib "steamapps\common\$d")) } }
    }
    foreach ($k in "HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\$($g.Reg)", "HKLM:\SOFTWARE\Rockstar Games\$($g.Reg)") {
        $p = Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
        if ($p) { foreach ($v in 'InstallFolder', 'InstallFolderSteam', 'InstallFolderEpic') { $x = "$($p.$v)".Trim('"').TrimEnd('\'); if ($x) { $c.Add($x); $c.Add((Split-Path -Parent $x)) } } }
    }
    foreach ($f in $g.Folders) { $c.Add((Join-Path $GamesRoot $f)) }
    $d = $c | Where-Object { Test-CfxGameDir $g $_ } | Select-Object -First 1
    if ($d) { Get-RealCasePath $d }
}
# the same path with the folders' real upper / lower case (Steam's libraryfolders.vdf keeps library paths in lower case)
function Get-RealCasePath([string]$p) {
    $parts = $p.TrimEnd('\').Split('\')
    $cur = $parts[0].ToUpper() + '\'
    for ($i = 1; $i -lt $parts.Count; $i++) {
        if (-not $parts[$i]) { continue }
        $n = Get-ChildItem -LiteralPath $cur -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $parts[$i] } | Select-Object -First 1
        $cur = Join-Path $cur $(if ($n) { $n.Name } else { $parts[$i] })
    }
    $cur.TrimEnd('\')
}
# FiveM / RedM on the game disk: where the menu starts them (Menu\data\games.json), and the game folders (not Steam)
function Get-CfxApps {
    $exes = New-Object System.Collections.Generic.List[string]
    $gj = Join-Path $Menu 'data\games.json'
    if (Test-Path -LiteralPath $gj) {
        try { foreach ($x in @((Get-Content -LiteralPath $gj -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ })) { $m = [regex]::Match("$($x.cmd)", '"([^"]+\\(FiveM|RedM)\.exe)"'); if ($m.Success) { $exes.Add($m.Groups[1].Value) } } } catch { }
    }
    foreach ($kind in @(Get-GameFolders | ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -ErrorAction SilentlyContinue }) | Where-Object { $_.Name -ne 'Steam' }) {
        Get-ChildItem -LiteralPath $kind.FullName -Recurse -Depth 1 -File -Include 'FiveM.exe', 'RedM.exe' -ErrorAction SilentlyContinue | ForEach-Object { $exes.Add($_.FullName) }
    }
    $seen = @{}
    foreach ($e in $exes) {
        $name = [IO.Path]::GetFileNameWithoutExtension($e)
        $app = Join-Path (Split-Path -Parent $e) "$name.app"
        if ($seen.ContainsKey($app.ToLower()) -or -not (Test-Path -LiteralPath (Join-Path $app 'CoreRT.dll'))) { continue }
        $seen[$app.ToLower()] = 1
        [pscustomobject]@{ Name = $(if ($name -ieq 'RedM') { 'RedM' } else { 'FiveM' }); App = $app; Ini = (Join-Path $app 'CitizenFX.ini') }
    }
}
# CitizenFX.ini lines (Windows INI: ANSI, or UTF-16 with a BOM)
function Read-CfxIni([string]$Ini) {
    if (-not (Test-Path -LiteralPath $Ini)) { return ,@() }
    $b = [IO.File]::ReadAllBytes($Ini)
    $enc = if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { [Text.Encoding]::Unicode } elseif ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { [Text.Encoding]::UTF8 } else { [Text.Encoding]::Default }
    ,@($enc.GetString($b).TrimStart([char]0xFEFF) -split "\r?\n")
}
function Get-CfxIVPath([string]$Ini) {
    $sec = ''
    foreach ($l in (Read-CfxIni $Ini)) { if ($l -match '^\s*\[(.+?)\]') { $sec = $Matches[1] } elseif ($sec -ieq 'Game' -and $l -match '^\s*IVPath\s*=(.*)$') { return $Matches[1].Trim().Trim('"') } }
    ''
}
# sets [Game] IVPath= and keeps every other line of the file
function Set-CfxIVPath([string]$Ini, [string]$Path) {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($l in (Read-CfxIni $Ini)) { $lines.Add($l) }
    while ($lines.Count -and -not $lines[$lines.Count - 1].Trim()) { $lines.RemoveAt($lines.Count - 1) }
    $sec = ''; $gameAt = -1; $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[(.+?)\]') { $sec = $Matches[1]; if ($sec -ieq 'Game' -and $gameAt -lt 0) { $gameAt = $i }; continue }
        if ($sec -ieq 'Game' -and $lines[$i] -match '^\s*IVPath\s*=') { $lines[$i] = "IVPath=$Path"; $done = $true; break }
    }
    if (-not $done) { if ($gameAt -ge 0) { $lines.Insert($gameAt + 1, "IVPath=$Path") } else { $lines.Add('[Game]'); $lines.Add("IVPath=$Path") } }
    $text = ($lines -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText($Ini, $text, $(if ($text -match '[^\x00-\x7F]') { [Text.Encoding]::Unicode } else { [Text.Encoding]::ASCII }))
}
# per FiveM / RedM: the game folder found, what CitizenFX.ini says, and whether that is usable
function Get-CfxStatus {
    foreach ($a in @(Get-CfxApps)) {
        $g = $CfxGames | Where-Object { $_.Name -eq $a.Name }
        $have = Get-CfxIVPath $a.Ini
        [pscustomobject]@{ Name = $a.Name; Game = $g.Game; App = $a.App; Ini = $a.Ini; Have = $have; HaveOk = (Test-CfxGameDir $g $have); Want = (Find-CfxGameDir $g) }
    }
}

# what the watcher compares to notice a new / removed game without a launcher telling it: the game folders
# (GAME\<kind>\<game>, X:\Games\<kind>\<game>, top-level X:\Online ...) and installed-apps entries on the shared drives
function Get-GameFolderStamp {
    $out = New-Object System.Collections.Generic.List[string]
    $kinds = 'Online', 'PvP', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'Garena', 'HoYoPlay', 'Gacha'
    foreach ($gr in Get-GameFolders) {
        foreach ($c in Get-ChildItem -LiteralPath $gr -Directory -ErrorAction SilentlyContinue) {
            $out.Add($c.FullName)
            if ($kinds -contains $c.Name) { Get-ChildItem -LiteralPath $c.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { $out.Add($_.FullName) } }
        }
    }
    foreach ($d in (Get-SharedDrives).ToCharArray()) {
        foreach ($k in $kinds) { foreach ($p in "${d}:\Games\$k", "${d}:\$k") { Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { $out.Add($_.FullName) } } }
    }
    $hy = Join-Path (Get-LauncherDir 'HoYoPlay') 'games'
    Get-ChildItem -LiteralPath $hy -Directory -ErrorAction SilentlyContinue | ForEach-Object { $out.Add($_.FullName + '|' + @(Get-ChildItem -LiteralPath $_.FullName -Filter *.exe -File -ErrorAction SilentlyContinue).Count) }
    foreach ($r in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
        Get-ChildItem $r -ErrorAction SilentlyContinue | ForEach-Object { $l = "$($_.GetValue('InstallLocation'))"; if ($l -match '^"?[D-Za-z]:' -and $l -notmatch '^"?[Cc]:') { $out.Add('app|' + $_.PSChildName + '|' + $l) } }
    }
    $out
}

# ---------- game menu ----------
# the menu program is Menu\app\<brandName>.exe (Menu\config.json brandName), or the older Menu\app\0JAYSHOP.exe
function Get-MenuInfo {
    $cfg = try { Get-Content -LiteralPath (Join-Path $Menu 'config.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json } catch { $null }
    $name = if ($cfg -and $cfg.brandName) { ($cfg.brandName -replace '[\\/:*?"<>|]', '').Trim() } else { '' }
    if (-not $name) { $name = '0JAYSHOP' }
    $exe = Join-Path $Menu "app\$name.exe"
    if (-not (Test-Path -LiteralPath $exe)) { $alt = Join-Path $Menu 'app\0JAYSHOP.exe'; if (Test-Path -LiteralPath $alt) { $exe = $alt } }
    # renamed by hand / by OSYNC-Setup to another shop name: the one big exe in Menu\app (like System\Client\Menu.vbs)
    if (-not (Test-Path -LiteralPath $exe)) { $any = Get-ChildItem -LiteralPath (Join-Path $Menu 'app') -Filter *.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 50MB } | Select-Object -First 1; if ($any) { $exe = $any.FullName; $name = $any.BaseName } }
    [pscustomobject]@{ Name = $name; Exe = $exe; Names = @($name, '0JAYSHOP') | Select-Object -Unique; Config = $cfg }
}

# ---------- console helpers ----------
# Live status line, redrawn in place (and in the window title) so a long install visibly moves; '' clears it.
# Never logged: with output piped (scripts run by Client-Install.ps1) it goes up as a "~" line drawn in place there.
function Show-Live([string]$text) {
    try {
        if ([Console]::IsOutputRedirected) { Write-Host "~$text"; return }
        if (-not $text -and -not $script:LiveOn) { return }
        $w = [math]::Max(20, [Console]::WindowWidth - 1)
        if ($text.Length -gt $w) { $text = $text.Substring(0, $w) }
        [Console]::Write("`r" + $text.PadRight($w) + $(if ($text) { '' } else { "`r" }))
        $script:LiveOn = [bool]$text
        if ($text) { [Console]::Title = 'OSYNC ' + $text.Trim() }
    } catch {}
}
function Format-Sec([int]$s) { '{0}:{1:00}' -f [math]::Floor($s / 60), ($s % 60) }

# Run an installer hidden and wait at most $TimeoutSec, with a live line while it runs; on timeout kill the whole
# process tree (a leftover child keeps Windows Installer busy). Returns @{ Code = exit code or $null; Sec }.
function Invoke-Installer([string]$Exe, $ArgList, [string]$Label, [int]$TimeoutSec = 300) {
    $sp = @{ FilePath = $Exe; PassThru = $true; WindowStyle = 'Hidden' }
    if ($ArgList) { $sp.ArgumentList = $ArgList }
    if ([IO.Path]::IsPathRooted($Exe) -and (Test-Path -LiteralPath (Split-Path -Parent $Exe))) { $sp.WorkingDirectory = Split-Path -Parent $Exe }
    $t = [Diagnostics.Stopwatch]::StartNew()
    $code = $null
    try {
        $p = Start-Process @sp -ErrorAction Stop
        $noted = $false
        while (-not $p.WaitForExit(1000)) {
            $s = [int]$t.Elapsed.TotalSeconds
            if ($s -ge $TimeoutSec) { break }
            if ($s -ge 15 -and -not $noted) { $noted = $true; Show-Live ''; Write-Host "  ...  $Label still running" }
            Show-Live ('  {0} {1} / {2}  {3}' -f '|/-\'[$s % 4], (Format-Sec $s), (Format-Sec $TimeoutSec), $Label)
        }
        Show-Live ''
        if ($p.HasExited) { $code = $p.ExitCode }
        else {
            Start-Process taskkill.exe -ArgumentList "/PID $($p.Id) /T /F" -WindowStyle Hidden -Wait
            Write-Host ("  TIMEOUT {0} (stopped after {1})" -f $Label, (Format-Sec $TimeoutSec))
        }
    } catch { Show-Live ''; Write-Host "  FAIL $Label ($($_.Exception.Message))" }
    [pscustomobject]@{ Code = $code; Sec = [int]$t.Elapsed.TotalSeconds }
}

# Riot products still downloading/patching on this PC: <name>.manifest is written when a patch starts,
# <name>.ok when it is done. A manifest older than 3 h without an .ok is an abandoned download, not counted.
# RiotClient in the list = a Riot Client self-update is waiting (installed when Riot Client restarts).
function Get-RiotBusy {
    $meta = Join-Path $env:ProgramData 'Riot Games\Metadata'
    foreach ($d in Get-ChildItem -LiteralPath $meta -Directory -ErrorAction SilentlyContinue) {
        $man = Get-Item -LiteralPath (Join-Path $d.FullName "$($d.Name).manifest") -ErrorAction SilentlyContinue
        if (-not $man -or $man.LastWriteTime -lt (Get-Date).AddHours(-3)) { continue }
        $ok = Get-Item -LiteralPath (Join-Path $d.FullName "$($d.Name).ok") -ErrorAction SilentlyContinue
        # never installed on this PC (the PBE test servers): Riot only refreshes its manifest, no .ok / .db ever comes -
        # do not wait 3 hours for it (18 Nov 2026: held the client refresh after a LoL patch)
        if (-not $ok -and -not (Test-Path -LiteralPath (Join-Path $d.FullName "$($d.Name).db"))) { continue }
        if (-not $ok -or $man.LastWriteTime -gt $ok.LastWriteTime.AddSeconds(1)) { $d.Name }
    }
}
