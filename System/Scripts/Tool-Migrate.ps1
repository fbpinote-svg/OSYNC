# Tool-Migrate.ps1 - step B, ONCE: switch this folder from the old layout (GAMELUNCHER\, GCafe\, _system\, 3 buttons)
# to the new one (Launchers\, Menu\, System\, OSYNC.bat). Normally in place (E:\Autosync stays E:\Autosync);
# -OldRoot <folder> moves from another folder instead. Run while the shop is CLOSED and every client PC is OFF:
# a folder renamed on the game drive while clients are on makes them read broken files until they reboot.
#   Tool-Migrate.ps1 -DryRun      show every step (each launcher move is a dry-run too) - changes nothing
#   Tool-Migrate.ps1              do it, as administrator (asks before it starts and before closing programs)
#   -SkipSteamGames               leave the Steam games where they are
# Steps: 1 stop the watcher  2 close the menu here  3 launchers -> Launchers\ (registry, services, shortcuts follow)
#        4 GCafe -> Menu\  4b build the menu if its source is newer   5 compare settings   6 Steam games -> GAME\Steam
#        6b tidy the games (Tool-Organize-Drive.ps1: X:\Online, FiveM, RedM -> GAME\Online, Delta Force -> GAME\Garena, tools -> Tools\, icons)
#        7 old layout files -> X:\_<delete>\ (nothing is deleted), new README / git files into place
#        8 update clients (System\Data + game list)    9 watcher ON (opens the launchers)   10 open the menu   11 check
# After this: client images still point at the old files -> on one client per image: OSYNC.bat client, save the image.
# Log: C:\Users\Public\OSYNC-Migrate.log
#   -Yes            answer yes to its questions (all client PCs were checked to be off)   -NoMenuStart   do not open the menu at the end
param([switch]$DryRun, [string]$OldRoot = '', [switch]$SkipSteamGames, [switch]$Yes, [switch]$NoMenuStart)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
if (-not $OldRoot) { $OldRoot = $Root }
$OldRoot = $OldRoot.TrimEnd('\')
$inPlace = $OldRoot -ieq $Root
$oldGl   = Join-Path $OldRoot 'GAMELUNCHER'
$oldMenu = Join-Path $OldRoot 'GCafe'
$trash   = $OldRoot.Substring(0, 3) + '_' + [string]::new([char[]](0x0E25, 0x0E1A, 0x0E44, 0x0E14, 0x0E49))     # X:\_<delete-ok> (Thai name the shop uses)
$stamp   = Get-Date -Format 'yyyyMMdd'
function Head([string]$t) { Write-Host "`n== $t" -ForegroundColor Yellow }
function Ask([string]$q) { if ($DryRun -or $Yes) { if ($Yes) { Write-Host "$q -> yes (-Yes)" }; return $true }; (Read-Host "$q [Y/N]") -match '^[Yy]' }
if ($env:OSYNC_LAUNCHERS -or $env:OSYNC_MENU) { Write-Host 'OSYNC_LAUNCHERS / OSYNC_MENU are set (test mode) - open a new window without them.' -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $oldGl)) { Write-Host "Nothing to move: $oldGl not found." -ForegroundColor Yellow; exit 0 }
if (-not $DryRun -and -not (Test-Admin)) { Write-Host 'Run as administrator (OSYNC.bat asks for it).' -ForegroundColor Red; exit 1 }
if (-not $DryRun) { Start-Transcript -Path (Join-Path $env:PUBLIC 'OSYNC-Migrate.log') -Append | Out-Null }
Write-Host "OSYNC step B: $(if ($inPlace) { "$Root (in place)" } else { "$OldRoot  ->  $Root" })$(if ($DryRun) { '   (DryRun: nothing changes)' })" -ForegroundColor Cyan
if (-not $DryRun -and -not (Ask 'The shop is closed and EVERY client PC is turned off?')) { Write-Host 'Stopped. Run again when all client PCs are off.'; exit 1 }

Head '1 Stop the watcher (old and new)'
if ($DryRun) { Write-Host '  would run Master-Watch.ps1 -Unregister' } else { [void](Run-Ps 'Master-Watch.ps1' @('-Unregister')) }

Head '2 Close the game menu on this PC'
$menuProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($oldMenu + '\', [StringComparison]::OrdinalIgnoreCase) })
if (-not $menuProcs) { Write-Host '  not running' }
elseif ($DryRun) { Write-Host "  would close: $(($menuProcs | ForEach-Object Name | Sort-Object -Unique) -join ', ')" }
elseif (Ask "  Close $(($menuProcs | ForEach-Object Name | Sort-Object -Unique) -join ', ') now?") { $menuProcs | Stop-Process -Force; Start-Sleep -Seconds 3 }
else { Write-Host 'Stopped (the menu must be closed to move it).'; exit 1 }

Head '3 Launchers -> Launchers\'
$moved = @()
foreach ($l in $LauncherTable) {
  $w = Get-LauncherInstallPath $l.Key
  if (-not $w -or -not $w.StartsWith($oldGl + '\', [StringComparison]::OrdinalIgnoreCase)) {
    if ($w -ieq $oldGl) { Write-Host "  $($l.Title) is installed straight into $oldGl (no folder of its own) - gather it into a folder first" -ForegroundColor Red }
    continue
  }
  Write-Host "  -- $($l.Title): $w" -ForegroundColor Cyan
  $rc = Run-Ps 'Master-Move-Launcher.ps1' $(if ($DryRun) { @('-Launcher', $l.Key, '-DryRun') } else { @('-Launcher', $l.Key) })
  if ($rc -ne 0) {
    Write-Host "  $($l.Title) FAILED (exit $rc) - fix it, then run Tool-Migrate.ps1 again (moved ones are skipped)" -ForegroundColor Red
    if (-not $DryRun) {
      $ml = Join-Path $env:PUBLIC 'OSYNC-Move-Launcher.log'
      if (Test-Path -LiteralPath $ml) { Write-Host "  why (last lines of $ml):"; Get-Content -LiteralPath $ml -Tail 12 | ForEach-Object { Write-Host "    $_" } }
      Write-Host '  The watcher is off now (clients are not updated by themselves): run step B again soon.' -ForegroundColor Yellow
      exit 1
    }
  }
  $moved += $l.Title
}
if (-not $moved) { Write-Host '  no launcher left in the old folder' }

Head '4 GCafe -> Menu\'
if (Test-Path -LiteralPath $Menu) { Write-Host "  $Menu already there" }
elseif (-not (Test-Path -LiteralPath $oldMenu)) { Write-Host "  $oldMenu not found" -ForegroundColor Yellow }
else {
  $sh = New-Object -ComObject WScript.Shell
  $lnks = @(foreach ($d in 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\Public\Desktop', [Environment]::GetFolderPath('Desktop'), "$env:APPDATA\Microsoft\Windows\Start Menu") {
    Get-ChildItem -LiteralPath $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | Where-Object { $sh.CreateShortcut($_.FullName).TargetPath -like "$oldMenu\*" } | ForEach-Object FullName })
  $obsolete = @('tools\Build-GameList.bat', 'tools\Install-Client.bat', 'tools\Uninstall-Client.bat', 'tools\_system\Build-GameList.ps1', 'tools\_system\Install-Client.ps1', 'data\games.custom.json', 'data\games.custom.mainbranch.json')
  Write-Host "  rename $oldMenu -> $Menu (same drive, no copy)"
  Write-Host "  shortcuts to repoint: $($lnks.Count) $(($lnks | ForEach-Object { Split-Path -Leaf $_ }) -join ', ')"
  Write-Host "  old OSYNC files inside the menu folder -> System\Backup: $($obsolete -join ', ')"
  if (-not $DryRun) {
    [IO.Directory]::Move($oldMenu, $Menu)
    foreach ($l in $lnks) {
      $s = $sh.CreateShortcut($l)
      $s.TargetPath = $Menu + $s.TargetPath.Substring($oldMenu.Length)
      if ($s.WorkingDirectory -like "$oldMenu*") { $s.WorkingDirectory = $Menu + $s.WorkingDirectory.Substring($oldMenu.Length) }
      if ($s.IconLocation -like "$oldMenu*") { $s.IconLocation = $Menu + $s.IconLocation.Substring($oldMenu.Length) }
      $s.Save()
    }
    $bk = Join-Path $BackupDir "menu-old-files-$stamp"
    foreach ($o in $obsolete) { $p = Join-Path $Menu $o; if (Test-Path -LiteralPath $p) { $q = Join-Path $bk $o; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $q) | Out-Null; Move-Item -LiteralPath $p -Destination $q } }
    Write-Host '  done' -ForegroundColor Green
  }
}

Head '4b Menu program up to date (the menu is closed now, so it can be rebuilt)'
$mi = Get-MenuInfo
$menuSrc = Join-Path $(if (Test-Path -LiteralPath $Menu) { $Menu } else { $oldMenu }) 'source'
$newestSrc = Get-ChildItem (Join-Path $menuSrc 'src'), (Join-Path $menuSrc 'electron'), (Join-Path $menuSrc 'public') -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$appTime = if (Test-Path -LiteralPath $mi.Exe) { (Get-Item -LiteralPath $mi.Exe).LastWriteTime } else { [datetime]::MinValue }
if ($newestSrc -and $newestSrc.LastWriteTime -gt $appTime) {
  Write-Host "  source changed after the last build ($($newestSrc.Name), $($newestSrc.LastWriteTime)) -> build"
  if ($DryRun) { Write-Host '  would run Menu\tools\_system\Build-App.ps1 -NoTest' }
  else {
    $b = Join-Path $Menu 'tools\_system\Build-App.ps1'
    $p = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $b + '"'), '-NoTest') -NoNewWindow -Wait -PassThru
    Write-Host $(if ($p.ExitCode -eq 0) { '  menu built' } else { "  menu build FAILED (exit $($p.ExitCode)) - the old menu program stays; build later: OSYNC.bat > 7 > 3" }) -ForegroundColor $(if ($p.ExitCode -eq 0) { 'Green' } else { 'Red' })
  }
} else { Write-Host '  up to date' }

Head '5 Settings'
$oldSet = Join-Path $oldGl 'ClientSetup\settings.txt'
if (Test-Path -LiteralPath $oldSet) {
  $o = ((Get-Content -LiteralPath $oldSet | Where-Object { $_ -match '^\s*SharedDrives\s*=' } | Select-Object -First 1) -split '=', 2)[1]
  $o = "$o" -replace '[^A-Za-z]', ''
  if ($o -and $o.ToUpper() -ne ((Get-Setting 'SharedDrives') -replace '[^A-Za-z]', '').ToUpper()) { Write-Host "  WARNING old SharedDrives=$o differs from Settings\settings.txt - check it" -ForegroundColor Yellow } else { Write-Host '  SharedDrives: same' }
}
$oldCustom = @((Join-Path $Menu 'data\games.custom.json'), (Join-Path $oldMenu 'data\games.custom.json')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($oldCustom -and (Get-Item $oldCustom).LastWriteTime -gt (Get-Item $ExtraGamesFile).LastWriteTime) { Write-Host "  WARNING $oldCustom changed after Settings\extra-games.json was made - copy the new entries over" -ForegroundColor Yellow }
else { Write-Host '  extra games: Settings\extra-games.json is the one in use' }

Head "6 Steam games -> $GamesRoot\Steam"
if ($SkipSteamGames) { Write-Host '  skipped (-SkipSteamGames); later: OSYNC.bat > 7 Tools > 2' }
else {
  $rc = Run-Ps 'Master-Steam-Library.ps1' @('-DryRun')
  if ($rc -ne 0) { Write-Host '  left where they are (they work there); later: OSYNC.bat > 7 Tools > 2' -ForegroundColor Yellow }
  elseif (-not $DryRun) { [void](Run-Ps 'Master-Steam-Library.ps1') }
}

Head '6b Tidy the drive (Games\, Tools\)'
[void](Run-Ps 'Tool-Organize-Drive.ps1' $(if ($DryRun) { @('-DryRun') } else { @() }))

Head '7 Old layout files'
$stillLaunchers = @(Get-ChildItem -LiteralPath $oldGl -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin 'ClientSetup', '_archive' } | ForEach-Object Name)
# .git is not in the list: a folder that is a git clone keeps its history, the new layout is committed on top
$oldItems = 'GAMELUNCHER', 'GCafe', '_system', 'README.md', 'HOW-IT-WORKS.md', 'KNOWLEDGE.md', 'SETUP-AI.md', 'OSYNC-All-In-One.bat', 'MASTER-Update-All.bat', 'CLIENT-Install-All.bat', '.gitignore', '.gitattributes'
if ($inPlace) {
  # this folder stays: only the old layout's own files move out; anything else (e.g. GAME\ a launcher downloads into) stays and is listed
  $dest = Join-Path $trash "Autosync-old-$stamp"
  $present = @($oldItems | Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) })
  $others = @(Get-ChildItem -LiteralPath $Root -Force | Where-Object { $_.Name -notin $oldItems -and $_.Name -notin 'OSYNC.bat', 'Settings', 'Launchers', 'Menu', 'System' } | ForEach-Object Name)
  Write-Host "  old files -> $dest : $($present -join ', ')"
  if (Test-Path -LiteralPath (Join-Path $oldGl '_archive')) { Write-Host "  GAMELUNCHER\_archive (launcher backups) -> System\Backup\GAMELUNCHER-archive" }
  Write-Host "  new README.md / .gitignore / .gitattributes: System\Staging -> $Root"
  if ($others) { Write-Host "  left where they are (not part of the old layout): $($others -join ', ')" -ForegroundColor Yellow }
  if ($stillLaunchers) { Write-Host "  launcher folders still in GAMELUNCHER: $($stillLaunchers -join ', ') - GAMELUNCHER stays until they are moved" -ForegroundColor $(if ($DryRun) { 'DarkGray' } else { 'Red' }) }
  if (-not $DryRun) {
    $arc = Join-Path $oldGl '_archive'
    if (Test-Path -LiteralPath $arc) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null; [IO.Directory]::Move($arc, (Join-Path $BackupDir 'GAMELUNCHER-archive')) }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($n in $present) {
      if ($n -eq 'GAMELUNCHER' -and $stillLaunchers) { continue }
      $p = Join-Path $Root $n
      if ((Get-Item -LiteralPath $p -Force).PSIsContainer) { [IO.Directory]::Move($p, (Join-Path $dest $n)) } else { [IO.File]::Move($p, (Join-Path $dest $n)) }
    }
    $stg = Join-Path $SystemDir 'Staging'
    # client images made with the old layout run <OSYNC>\_system\Install-All.ps1 at boot: a hidden forwarder keeps them working
    $compat = Join-Path $stg 'compat\Install-All.ps1'
    if (Test-Path -LiteralPath $compat) {
      $cs = Join-Path $Root '_system'
      New-Item -ItemType Directory -Force -Path $cs | Out-Null
      Move-Item -LiteralPath $compat -Destination (Join-Path $cs 'Install-All.ps1') -Force
      (Get-Item -LiteralPath $cs -Force).Attributes = 'Directory, Hidden'
      [IO.Directory]::Delete((Join-Path $stg 'compat'))
      Write-Host '  hidden _system\Install-All.ps1 forwards old client images to the new boot setup'
    }
    foreach ($f in Get-ChildItem -LiteralPath $stg -Force -ErrorAction SilentlyContinue) { $t = Join-Path $Root $f.Name; if (-not (Test-Path -LiteralPath $t)) { Move-Item -LiteralPath $f.FullName -Destination $t } }
    if ((Test-Path -LiteralPath $stg) -and -not (Get-ChildItem -LiteralPath $stg -Force)) { [IO.Directory]::Delete($stg) }
    foreach ($h in '.gitignore', '.gitattributes') { $p = Join-Path $Root $h; if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p -Force).Attributes = 'Hidden, Archive' } }
    Write-Host "  done (delete $dest yourself when all is fine)" -ForegroundColor Green
  }
} else {
  $dest = Join-Path $trash ((Split-Path -Leaf $OldRoot) + "-old-$stamp")
  $left = @(Get-ChildItem -LiteralPath $OldRoot -Force -ErrorAction SilentlyContinue | ForEach-Object Name)
  $unknown = @($left | Where-Object { $oldItems -notcontains $_ })
  Write-Host "  left: $($left -join ', ')"
  Write-Host "  would move $OldRoot -> $dest (nothing is deleted; delete it yourself when all is fine)"
  if ($unknown) { Write-Host "  NOT moved: not OSYNC files in $OldRoot : $($unknown -join ', ') - move them yourself" -ForegroundColor Red }
  elseif ($stillLaunchers -and -not $DryRun) { Write-Host "  NOT moved: launcher folders still in $oldGl : $($stillLaunchers -join ', ')" -ForegroundColor Red }
  elseif (-not $DryRun -and $left) { New-Item -ItemType Directory -Force -Path $trash | Out-Null; [IO.Directory]::Move($OldRoot, $dest); Write-Host "  moved -> $dest" -ForegroundColor Green }
}

Head '8 Update clients (System\Data + game list with the new paths)'
if ($DryRun) { Write-Host '  would run Master-Update.ps1' } else { [void](Run-Ps 'Master-Update.ps1') }

Head '9 Watcher ON (opens the launchers again)'
if ($DryRun) { Write-Host '  would run Master-Watch.ps1 -Register' } else { [void](Run-Ps 'Master-Watch.ps1' @('-Register')) }

Head '10 Open the game menu on this PC'
if ($DryRun -or $NoMenuStart) { Write-Host "  $(if ($NoMenuStart) { 'skipped (-NoMenuStart)' } else { 'would open' }) $(Join-Path $ClientDir 'Menu.vbs')" } else { Start-Process explorer.exe -ArgumentList ('"' + (Join-Path $ClientDir 'Menu.vbs') + '"') }

Head '11 Check'
[void](Run-Ps 'Tool-Check.ps1' @('-Mode', 'master'))
Write-Host "`nNext: on ONE client PC per image (every image) in super workstation mode: OSYNC.bat client, then save the image." -ForegroundColor Cyan
if (-not $DryRun) { Stop-Transcript | Out-Null }
