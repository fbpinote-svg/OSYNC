# Master-Setup.ps1 - first-time setup of a MASTER (OSYNC.bat > 4, or OSYNC.bat setup). Asks before every change.
#   1 drives the clients see -> Settings\settings.txt      2 move launchers into Launchers\
#   3 Steam library                                         4 game menu (shop name, build)
#   5 update clients now                                    6 watcher ON                     7 check
# Steps that are already done just say so. Run it again any time.
#   Master-Setup.ps1 -DryRun    only show what each step would do (asks nothing, changes nothing)
param([switch]$DryRun)
. (Join-Path $PSScriptRoot 'Common.ps1')
function Ask([string]$q) { if ($DryRun) { Write-Host "  (DryRun) would ask: $q" -ForegroundColor DarkGray; return $false }; (Read-Host "  $q [Y/N]") -match '^[Yy]' }
function Head([string]$t) { Write-Host "`n== $t" -ForegroundColor Yellow }
if (-not $DryRun) { Stop-IfPreMigration 'First-time setup' }
if (-not $DryRun -and -not (Test-Admin)) { Write-Host 'Run as administrator (OSYNC.bat asks for it).' -ForegroundColor Red; exit 1 }
Write-Host "OSYNC first-time setup on $env:COMPUTERNAME  ($Root)$(if ($DryRun) { '  - DryRun, nothing changes' })" -ForegroundColor Cyan

# 1) shared drives: read the diskless server's own list when Node.js is there (read only), else fixed drives
Head '1 Drives the client PCs see'
$cur = ((Get-Setting 'SharedDrives') -replace '[^A-Za-z]', '').ToUpper()
$found = ''
$db = 'C:\lwserver\config\lwservice.db'
if ((Test-Path -LiteralPath $db) -and (Get-Command node -ErrorAction SilentlyContinue)) {
  $js = "try{const{DatabaseSync}=require('node:sqlite');const d=new DatabaseSync(process.argv[1],{readOnly:true});console.log(d.prepare('select drive,type,vdiskletter from tServerDiskMng').all().filter(r=>+r.type===1&&+r.vdiskletter).map(r=>String.fromCharCode(+r.vdiskletter)).join(''))}catch(e){}"
  $found = (& node --no-warnings -e $js $db 2>$null | Select-Object -First 1)
  if ($found) { $found = ($found -replace '[^A-Za-z]', '').ToUpper() }
}
if (-not $found) { $sys = $env:SystemDrive.Substring(0, 1); $found = ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID.Substring(0, 1) } | Where-Object { $_ -ne $sys }) -join '').ToUpper(); $how = 'fixed drives except C:' } else { $how = 'from the diskless server settings' }
Write-Host "  now: SharedDrives=$cur     found: $found ($how)"
if ($found -and $found -ne $cur) {
  if (Ask "Set SharedDrives=$found ?") {
    $lines = @(Get-Content -LiteralPath $SettingsFile -Encoding UTF8)
    $lines = $lines | ForEach-Object { if ($_ -match '^\s*SharedDrives\s*=') { "SharedDrives=$found" } else { $_ } }
    [IO.File]::WriteAllLines($SettingsFile, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
    Write-Host "  saved: SharedDrives=$found"
  }
} else { Write-Host '  OK' -ForegroundColor Green }
# this PC is the master (MasterPC: right on every PC, whatever the diskless program) and its LAN IP (remote / firewall)
foreach ($kv in @(@('MasterPC', $env:COMPUTERNAME), @('MasterIP', (Get-LanIP)))) {
  $k = $kv[0]; $v = $kv[1]; $c = Get-Setting $k ''
  if (-not $v) { continue }
  if ($c -ieq $v) { Write-Host "  $k=$c  OK" -ForegroundColor Green; continue }
  if ($c) { Write-Host "  $k=$c (this PC: $v) - left as it is" -ForegroundColor Yellow; continue }
  if ($DryRun) { Write-Host "  (DryRun) would set $k=$v" -ForegroundColor DarkGray; continue }
  $lines = @(Get-Content -LiteralPath $SettingsFile -Encoding UTF8)
  if ($lines -match "^\s*$k\s*=") { $lines = $lines | ForEach-Object { if ($_ -match "^\s*$k\s*=") { "$k=$v" } else { $_ } } } else { $lines += "$k=$v" }
  [IO.File]::WriteAllLines($SettingsFile, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
  Write-Host "  saved: $k=$v"
}

# 2) launchers into Launchers\ (clients cannot use a launcher on C:)
Head '2 Launchers into Launchers\'
foreach ($l in $LauncherTable) {
  if (Test-Path -LiteralPath (Get-LauncherExe $l.Key)) { Write-Host ('  {0,-22} OK in {1}' -f $l.Title, (Get-LauncherDir $l.Key)) -ForegroundColor Green; continue }
  $w = Get-LauncherInstallPath $l.Key
  if (-not $w) { Write-Host ('  {0,-22} not installed (install it first if the shop needs it)' -f $l.Title) -ForegroundColor DarkGray; continue }
  Write-Host ('  {0,-22} installed at {1}' -f $l.Title, $w) -ForegroundColor Yellow
  $rc = Run-Ps 'Master-Move-Launcher.ps1' @('-Launcher', $l.Key, '-DryRun')
  if ($rc -eq 0 -and (Ask "Move $($l.Title) into $Launchers now (it will be closed)?")) { [void](Run-Ps 'Master-Move-Launcher.ps1' @('-Launcher', $l.Key)) }
}

# 3) Steam library on a shared drive (games inside the Steam folder work, GAME\Steam is tidier)
Head '3 Steam games'
$sd = Get-SteamDir
if ($sd) {
  Get-SteamLibraries | ForEach-Object { Write-Host "  library: $_" }
  $inside = @(Get-ChildItem -LiteralPath (Join-Path $sd 'steamapps') -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_228980\.acf$' }).Count
  if ($inside) { Write-Host "  $inside games are inside the Steam folder - to move them to $GamesRoot\Steam: OSYNC.bat > 7 Tools > 2" -ForegroundColor Yellow }
  Write-Host "  new games: install them into $GamesRoot\Steam (Steam > Settings > Storage, set it as default); other launchers: $GamesRoot\<launcher>"
} else { Write-Host '  Steam not installed' -ForegroundColor DarkGray }

# 4) game menu
Head '4 Game menu'
$mi = Get-MenuInfo
if (-not (Test-Path -LiteralPath $Menu)) { Write-Host "  $Menu missing - copy the Menu folder (GCafe) here" -ForegroundColor Red }
else {
  Write-Host "  shop name: $(if ($mi.Config) { $mi.Config.brandName } else { '(no config.json)' })   (change it in $Menu\config.json)"
  if (Ask 'Open config.json in Notepad to change the shop name / badge?') { Start-Process notepad.exe (Join-Path $Menu 'config.json') -Wait }
  if (Test-Path -LiteralPath $mi.Exe) { Write-Host "  program: $($mi.Exe)" -ForegroundColor Green }
  elseif (Test-Path -LiteralPath (Join-Path $Menu 'source\node_modules\electron')) {
    if (Ask 'The menu program is not built yet. Build it now (a few minutes)?') { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Menu 'tools\_system\Build-App.ps1') }
  } else { Write-Host "  not built and Menu\source\node_modules is missing: install Node.js LTS, run 'npm ci' in $Menu\source, then OSYNC.bat > 7 Tools > 3" -ForegroundColor Yellow }
}

# 5-7
Head '5 Update clients now (game data + game list)'
if (Ask 'Run it now?') { [void](Run-Ps 'Master-Update.ps1') }
Head '6 Watcher (keep launchers open, update clients by itself)'
$run = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).'OSYNC-Master'
$wt = Get-ScheduledTask -TaskName 'OSYNC-Master-Watch' -ErrorAction SilentlyContinue
if ($run -like "*$ScriptsDir*" -and $wt) { Write-Host '  already ON' -ForegroundColor Green }
elseif ($run -like "*$ScriptsDir*") { Write-Host '  ON through the Run entry only: adding the logon task' -ForegroundColor DarkYellow; [void](Run-Ps 'Master-Watch.ps1' @('-Register')) }
elseif (Ask 'Turn the watcher ON?') { [void](Run-Ps 'Master-Watch.ps1' @('-Register')) }
Head '7 Check'
[void](Run-Ps 'Tool-Check.ps1' @('-Mode', 'master'))
Write-Host "`nNext: on ONE client PC in super workstation mode run OSYNC.bat > 5, then save the image." -ForegroundColor Cyan
