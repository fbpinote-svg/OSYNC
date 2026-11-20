# Master-GameList.ps1 - MASTER (Master-Update.ps1 step 5). Writes Menu\data\games.json for the game menu.
# Sources: Steam libraries, Riot games (System\Data\Riot), EA-app games, Epic games, Settings\extra-games.json,
#          new game folders in X:\Online|PvP|Mobile|Single Player|Offline|Web|Emulator, and every launcher in Launchers\.
# Poster: Menu\data\posters\<id>.jpg|png|webp  >  zPoster.jpg in the game folder  >  Steam header image  >  made from the icon.
#   -Out <file>   write the list somewhere else (tests); default Menu\data\games.json
param([string]$Out = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $Out) { Stop-IfPreMigration 'Game list' }
$menuData = Join-Path $Menu 'data'
$out     = if ($Out) { $Out } else { Join-Path $menuData 'games.json' }
$games   = New-Object System.Collections.Generic.List[object]
$warn    = New-Object System.Collections.Generic.List[string]
$iconOf  = @{}                                                         # id -> exe/ico used for a poster when no artwork exists
$artOf   = @{}                                                         # id -> picture inside the game (e.g. Unreal Splash.bmp) to crop into a poster
$knownDirs = New-Object System.Collections.Generic.List[string]       # game folders the launcher scanners already listed (no AUTO copy of them)
$riotVbs = Join-Path $ClientDir 'Riot.vbs'
$epicVbs = Join-Path $ClientDir 'Epic.vbs'
$extra   = try { Read-ExtraGames } catch { $warn.Add("Settings\extra-games.json is not valid JSON: $($_.Exception.Message)"); $null }
Add-Type -AssemblyName System.Drawing
if (-not ('IconX' -as [type])) {
  Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class IconX {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, uint[] ids, uint n, uint flags);
  [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
}
'@
}
# 256px icon of an .exe/.ico -> png
function Export-Icon([string]$file, [string]$png) {
  $h = New-Object IntPtr[] 1; $ids = New-Object uint32[] 1
  if ([IconX]::PrivateExtractIcons($file, 0, 256, 256, $h, $ids, 1, 0) -lt 1 -or $h[0] -eq [IntPtr]::Zero) { return $false }
  try {
    $bmp = ([System.Drawing.Icon]::FromHandle($h[0])).ToBitmap()
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $png) | Out-Null
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $true
  } finally { [void][IconX]::DestroyIcon($h[0]) }
}

function Poster([string]$id, [string]$root) {
  foreach ($ext in 'jpg', 'png', 'webp') { $p = Join-Path $menuData "posters\$id.$ext"; if (Test-Path -LiteralPath $p) { return '/poster/' + [uri]::EscapeDataString($p) } }
  if ($root) { $p = Join-Path $root 'zPoster.jpg'; if (Test-Path -LiteralPath $p) { return '/poster/' + [uri]::EscapeDataString($p) } }
  return ''
}
# Steam artwork: copy the header Steam already cached on this PC into posters\_auto (works offline on clients),
# else ask the Steam store for the header URL (new games use hashed CDN paths), else the classic CDN path.
function SteamPoster([string]$appid) {
  $img = Poster "steam-$appid" ''
  if ($img) { return $img }
  $cache = Join-Path $steamDir "appcache\librarycache\$appid"
  $src = foreach ($n in 'header.jpg', 'library_header.jpg') { Get-ChildItem -LiteralPath $cache -Recurse -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
  $src = @($src)[0]
  if ($src) {
    $dst = Join-Path $menuData "posters\_auto\steam-$appid.jpg"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src.FullName -Destination $dst -Force
    return '/poster/' + [uri]::EscapeDataString($dst)
  }
  $auto = Join-Path $menuData "posters\_auto\steam-$appid.jpg"
  if (Test-Path -LiteralPath $auto) { return '/poster/' + [uri]::EscapeDataString($auto) }
  try {
    $r = Invoke-RestMethod "https://store.steampowered.com/api/appdetails?appids=$appid&filters=basic" -TimeoutSec 8
    if ($r.$appid.success -and $r.$appid.data.header_image) { return $r.$appid.data.header_image }
  } catch { }
  return "https://cdn.akamai.steamstatic.com/steam/apps/$appid/header.jpg"
}
function Add-Game($id, $title, $cat, $cmd, $cwd, $img, $platform) {
  $games.Add([pscustomobject][ordered]@{ id = $id; title = $title; cat = $cat; img = $img; cmd = $cmd; cwd = $cwd; platform = $platform })
}

# ---------- Steam ----------
$steamDir = Get-SteamDir
$steamExe = if ($steamDir) { Join-Path $steamDir 'steam.exe' } else { '' }
$skipApps = @('228980', '431960')                                     # Steamworks redist, Wallpaper Engine
$catOf = @{}
$steamDirOf = @{}                                                     # card id -> game folder (game-start cards below)
if ($extra -and $extra.steamCategories) { foreach ($p in $extra.steamCategories.PSObject.Properties) { $catOf[$p.Name] = "$($p.Value)" } }
if ($steamExe -and (Test-Path -LiteralPath $steamExe)) {
  foreach ($lib in Get-SteamLibraries) {
    foreach ($m in Get-ChildItem -LiteralPath (Join-Path $lib 'steamapps') -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) {
      $t = Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8
      $appid = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
      $name = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value -replace '[\u2122\u00AE]', ''
      $dir = Join-Path $lib ('steamapps\common\' + [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value)
      if (-not $appid -or $skipApps -contains $appid -or -not (Test-Path -LiteralPath $dir)) { continue }
      $img = SteamPoster $appid
      $cat = if ($catOf.ContainsKey($appid)) { $catOf[$appid] } else { 'Steam' }
      $steamDirOf["steam-$appid"] = $dir
      Add-Game "steam-$appid" $name.Trim() $cat ('"' + $steamExe + '" -applaunch ' + $appid) $steamDir $img 'Steam'
    }
  }
} else { $warn.Add('Steam not found (Launchers\Steam)') }

# ---------- Riot (System\Client\Riot.vbs prepares the PC, then starts the game) ----------
$riotMeta = Join-Path $DataDir 'Riot\Metadata'
$riot = [ordered]@{ 'valorant' = 'VALORANT'; 'league_of_legends' = 'League of Legends'; 'teamfighttactics' = 'Teamfight Tactics' }
if (Test-Path -LiteralPath (Get-LauncherExe 'Riot')) {
  foreach ($k in $riot.Keys) {
    $y = Join-Path $riotMeta "$k.live\$k.live.product_settings.yaml"
    if (-not (Test-Path -LiteralPath $y)) { continue }
    $dir = ([regex]::Match((Get-Content -LiteralPath $y -Raw), 'product_install_full_path:\s*"([^"]+)"').Groups[1].Value) -replace '/', '\'
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
    Add-Game "riot-$k" $riot[$k] 'Riot' ('wscript.exe "' + $riotVbs + '" ' + $k) '' (Poster "riot-$k" $dir) 'Riot'
    $iconOf["riot-$k"] = Join-Path $riotMeta "$k.live\$k.live.ico"
    $knownDirs.Add($dir); $knownDirs.Add((Split-Path -Parent $dir))
  }
}

# ---------- EA app games (installed through the EA app, not Steam) ----------
# Every game installed through the EA app (registry "Install Dir" with __Installer\installerdata.xml, not a Steam copy).
# Known offer ids (Settings\extra-games.json eaOffers) start the game directly; others open the EA app on the game.
$eaOffers = @{}
if ($extra -and $extra.eaOffers) { foreach ($p in $extra.eaOffers.PSObject.Properties) { $eaOffers[$p.Name] = @($p.Value) } }
$eaLauncher = Get-LauncherExe 'EA'
foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node' -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue }) {
  $dir = "$($k.GetValue('Install Dir'))"
  if (-not $dir -or $dir -match '\\steamapps\\' -or -not (Test-Path -LiteralPath (Join-Path $dir '__Installer\installerdata.xml'))) { continue }
  $rel = ($k.Name -split '\\')[-2..-1] -join '\'
  $id = 'ea-' + (($k.Name -split '\\')[-1] -replace '[^A-Za-z0-9]', '').ToLower()
  $title = "$($k.GetValue('DisplayName'))"; if (-not $title) { $title = Split-Path -Leaf $dir.TrimEnd('\') }
  $img = Poster $id $dir
  if ($eaOffers.ContainsKey($rel)) {
    if (-not $img -and $steamDir -and $eaOffers[$rel].Count -gt 1) { $img = SteamPoster $eaOffers[$rel][1] }
    Add-Game $id $title 'EA' ("origin2://game/launch?offerIds=" + $eaOffers[$rel][0]) '' $img 'EA app'
  } elseif (Test-Path -LiteralPath $eaLauncher) {
    Add-Game $id $title 'EA' ('"' + $eaLauncher + '"') (Split-Path -Parent $eaLauncher) $img 'EA app'
    $warn.Add("EA app game without a direct-start id (opens the EA app): $title - add its offer id to Settings\extra-games.json eaOffers (key $rel)")
  }
  $iconOf[$id] = $eaLauncher
  $knownDirs.Add($dir)
}

# ---------- Epic games (System\Client\Epic.vbs gives clients the install list, then starts the game) ----------
if (Test-Path -LiteralPath (Get-LauncherExe 'Epic')) {
  foreach ($f in Get-ChildItem (Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests') -Filter *.item -ErrorAction SilentlyContinue) {
    $m = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $m.InstallLocation -or -not (Test-Path -LiteralPath $m.InstallLocation) -or $m.bIsApplication -eq $false) { continue }
    $id = 'epic-' + $m.AppName.ToLower()
    Add-Game $id $m.DisplayName 'Epic' ('wscript.exe "' + $epicVbs + '" ' + $m.AppName) '' (Poster $id $m.InstallLocation) 'Epic'
    $iconOf[$id] = Join-Path $m.InstallLocation $m.LaunchExecutable
    $knownDirs.Add($m.InstallLocation)
    $splash = Get-ChildItem -LiteralPath $m.InstallLocation -Filter 'Splash.bmp' -Recurse -Depth 4 -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($splash) { $artOf[$id] = $splash.FullName }
  }
}

# ---------- extra games + overrides (Settings\extra-games.json) ----------
function Expand-Path([string]$p) { $p.Replace('{GAMES}', $GamesRoot).Replace('{LAUNCHERS}', $Launchers).Replace('{GAMELUNCHER}', $Launchers).Replace('{OSYNC}', $Root) }
$overrides = @{}
$custom = @(if ($extra -and $extra.games) { $extra.games })
foreach ($g in $custom) {
  if (-not $g.exe) { $overrides[$g.id] = $g; continue }
  $exe = $null
  foreach ($c in @($g.exe)) { $c = Expand-Path $c; if (Test-Path -LiteralPath $c) { $exe = $c; break } }
  if (-not $exe) { $warn.Add("not found, skipped: $($g.title)"); continue }
  $fi = Get-Item -LiteralPath $exe -Force
  if ($fi.Length -eq 0 -and -not ($fi.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $warn.Add("empty exe (not fully installed?), skipped: $($g.title)"); continue }
  $gameRoot = if ($g.root) { Expand-Path $g.root } else { Split-Path -Parent $exe }
  $cmd = '"' + $exe + '"' + $(if ($g.args) { ' ' + $g.args } else { '' })
  $img = if ($g.img) { $g.img } else { Poster $g.id $gameRoot }
  Add-Game $g.id $g.title $g.cat $cmd (Split-Path -Parent $exe) $img $(if ($g.platform) { $g.platform } else { '' })
  # "icon": an .ico/.exe for the poster when the start program has no icon of its own (Discord's Update.exe)
  $iconOf[$g.id] = if ($g.icon -and (Test-Path -LiteralPath (Expand-Path $g.icon))) { Expand-Path $g.icon } else { $exe }
}

# ---------- games nobody listed yet: added by themselves ----------
# 1 folders: <GamesFolder>\<kind>\<game> (Online, Garena, HoYoPlay, Gacha, Mobile ...), a game straight in <GamesFolder>,
#   X:\Games\<kind>\<game>, the older top-level X:\Online / X:\Mobile ..., and games HoYoPlay keeps in its own folder
# 2 Windows "Installed apps" entries of games on the shared drives (Ubisoft, Battle.net, GOG, Rockstar, any game installer):
#   title from the entry, category from the publisher
# Picks the most likely start exe; each one is listed as "AUTO" so it can be checked. To fix one, add an entry to
# Settings\extra-games.json with "root" = that folder (or {"id": "auto-...", "hide": true} to hide it).
$autoCats = @{ 'Online' = 'Online'; 'PvP' = 'Online'; 'Mobile' = 'Mobile'; 'Single Player' = 'Single Player'; 'Offline' = 'Single Player'; 'Web' = 'Apps'; 'Emulator' = 'Emulator'
               'Garena' = 'Garena'; 'HoYoPlay' = 'HoYoPlay'; 'Gacha' = 'Gacha' }
$launcherKinds = 'Steam', 'Epic', 'EA', 'Ubisoft', 'BattleNet', 'Battle.net', 'GOG', 'Amazon', 'Rockstar', 'Riot', 'Nexon'   # games of these come from their own scanners / installer entries
$nonGame = '(?i)OSLink|RustDesk|Discord|LDPlayer|Sunshine|CooperAgent|Redistributable|Runtime|Visual C\+\+|DirectX|\.NET|\bSDK\b|Driver|Anti-?Cheat|EasyAntiCheat|BattlEye|Vanguard|Overwolf|Updater|Social Club'
$notStart = '(?i)unins|setup|install|updat|patch|crash|report|redist|dxsetup|prereq|easyanticheat|beservice|battleye|^cef|chrome_|webview|qtwebengine|7z|helper|notif|service|bugtrap|dump|elevat|repair|diag|benchmark|unitycrash|xigncode|^xldr|gameguard|anticheat|^ace-|tenprotect|_pwa|proxy|^python|^java|^node'
function Slug([string]$s) { ($s -replace '[^A-Za-z0-9]', '').ToLower() }
# start-exe score: launcher / portable wrapper > start / play; + name like the folder; - each subfolder level
function ExeScore($e, [string]$folderName, [string]$folderPath) {
  $s = 0; $n = Slug $e.BaseName; $fs = Slug $folderName
  if ($n -match 'launcher|portable') { $s += 5 } elseif ($n -match 'start|play') { $s += 3 }
  if ($fs -and $n -and ($n.Contains($fs) -or $fs.Contains($n))) { $s += 3 }
  $s - $e.DirectoryName.Substring($folderPath.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries).Count
}
function Find-StartExe([string]$folderPath, [string]$name) {
  Get-ChildItem -LiteralPath $folderPath -Filter *.exe -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 100KB -and $_.BaseName -notmatch $notStart } |
    Sort-Object @{ e = { ExeScore $_ $name $folderPath }; Descending = $true }, @{ e = { $_.Length }; Descending = $true } | Select-Object -First 1
}
$covered = New-Object System.Collections.Generic.List[string]
foreach ($g in $games) {
  if ($g.cwd) { $covered.Add($g.cwd.TrimEnd('\')) }
  $m = [regex]::Match("$($g.cmd)", '^"([^"]+)"'); if ($m.Success) { $covered.Add((Split-Path -Parent $m.Groups[1].Value)) }
}
foreach ($d in $knownDirs) { $covered.Add($d.TrimEnd('\')) }
foreach ($g in $custom) { if ($g.root) { $covered.Add($g.root.TrimEnd('\')) }; foreach ($c in @($g.exe)) { if ($c) { $covered.Add((Split-Path -Parent (Expand-Path $c))) } } }
# a folder already listed: a listed path is the folder, inside it, or the folder is inside a listed game
function Test-Covered([string]$fp) { [bool]($covered | Where-Object { $_ -ieq $fp -or $_.StartsWith($fp + '\', [StringComparison]::OrdinalIgnoreCase) -or $fp.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }) }
function Add-AutoGame([string]$fp, [string]$idName, [string]$title, [string]$cat, [string]$platform, $exe = $null) {
  if (Test-Covered $fp) { return }
  if (-not $exe) { $exe = Find-StartExe $fp $idName }
  if (-not $exe) { $warn.Add("new folder without a start exe: $fp"); return }
  $id = $(if ($idName -match '^app-') { $idName } else { 'auto-' + (Slug $idName) })
  Add-Game $id $title $cat ('"' + $exe.FullName + '"') $exe.DirectoryName (Poster $id $fp) $platform
  $iconOf[$id] = $exe.FullName
  $covered.Add($fp.TrimEnd('\'))
  $warn.Add("AUTO added $title [$cat] -> $($exe.FullName)  (check it once)")
}
# 1 folders
$folderSets = New-Object System.Collections.Generic.List[object]
foreach ($gr in Get-GameFolders) {                 # GamesFolder + Settings GameFolders (more game drives)
  foreach ($c in Get-ChildItem -LiteralPath $gr -Directory -ErrorAction SilentlyContinue) {
    if ($autoCats.ContainsKey($c.Name)) { $folderSets.Add(@($c.FullName, $autoCats[$c.Name])) }
    elseif ($launcherKinds -notcontains $c.Name -and $c.Name -notmatch $nonGame) { Add-AutoGame $c.FullName $c.Name $c.Name 'Online' '' }   # a game straight in GAME\
  }
}
foreach ($drv in Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[D-Z]:\\$' }) {
  foreach ($catDir in $autoCats.Keys) { $folderSets.Add(@((Join-Path $drv.Root "Games\$catDir"), $autoCats[$catDir])); $folderSets.Add(@((Join-Path $drv.Root $catDir), $autoCats[$catDir])) }
}
$folderSets.Add(@((Join-Path (Get-LauncherDir 'HoYoPlay') 'games'), 'HoYoPlay'))     # HoYoPlay's default: games inside its own folder
foreach ($set in $folderSets) {
  foreach ($f in Get-ChildItem -LiteralPath $set[0] -Directory -ErrorAction SilentlyContinue) {
    if ($f.Name -match $nonGame) { continue }
    Add-AutoGame $f.FullName $f.Name $f.Name $set[1] ''
  }
}
# 2 installed-apps entries on the shared drives (not launchers, tools or Steam copies)
$shared = Get-SharedDrives
$skipUnder = @($Launchers, $OldLauncherRoot, $SystemDir, $Menu, $OldMenuDir, $ToolsDir) + @($shared.ToCharArray() | ForEach-Object { "${_}:\Tools"; "${_}:\LDPlayer"; "${_}:\Agen"; "${_}:\Appdata" })
$pubCat = [ordered]@{ 'Ubisoft' = 'Ubisoft'; 'Blizzard' = 'Battle.net'; 'GOG' = 'GOG'; 'Rockstar' = 'Rockstar'; 'Garena|Tencent' = 'Garena'; 'COGNOSPHERE|miHoYo|HoYoverse' = 'HoYoPlay'
            'Kuro|Gryph|Hypergryph|Infold|Seasun|Sunborn|MICA|Perfect World|Hotta|Pan Studio|Hero Games|iDreamSky|Yostar' = 'Gacha'; 'Electronic Arts|EA Games' = 'EA'; 'Amazon' = 'Amazon'; 'Nexon' = 'Nexon' }
foreach ($r in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
  foreach ($k in Get-ChildItem $r -ErrorAction SilentlyContinue) {
    $name = "$($k.GetValue('DisplayName'))".Trim()
    if (-not $name -or $name -match $nonGame -or $k.PSChildName -match '^Steam App \d+$' -or $k.GetValue('SystemComponent') -eq 1) { continue }
    if ("$($k.GetValue('Publisher')) $($k.PSChildName)" -match '(?i)Riot Games|^Riot Game ') { continue }        # Riot games come from the Riot scanner
    $dir = ("$($k.GetValue('InstallLocation'))" -replace '"', '' -replace '/', '\').TrimEnd('\')
    $icon = [regex]::Match("$($k.GetValue('DisplayIcon'))", '^"?([A-Za-z]:\\[^",]+?\.exe)').Groups[1].Value
    if (-not $dir -and $icon) { $dir = Split-Path -Parent $icon }
    if (-not $dir -or $dir.Length -lt 4 -or $shared.IndexOf($dir.Substring(0, 1).ToUpper()) -lt 0 -or -not (Test-Path -LiteralPath $dir)) { continue }
    if ($dir -match '\\steamapps\\' -or ($skipUnder | Where-Object { $_ -and ($dir -ieq $_ -or $dir.StartsWith($_.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) })) { continue }
    $pub = "$($k.GetValue('Publisher')) $name"
    $cat = 'Online'; foreach ($p in $pubCat.Keys) { if ($pub -match "(?i)$p") { $cat = $pubCat[$p]; break } }
    $exe = if ($icon -and (Test-Path -LiteralPath $icon) -and $icon.StartsWith($dir, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $icon) -notmatch $notStart) { Get-Item -LiteralPath $icon } else { $null }
    Add-AutoGame $dir ('app-' + (Slug $name)) $name $cat $(if ($cat -ne 'Online') { $cat } else { '' }) $exe
  }
}

# ---------- launchers in Launchers\ (category "Launchers") ----------
foreach ($l in $LauncherTable) {
  $exe = if ($l.Key -eq 'Steam') { $steamExe } else { Get-LauncherExe $l.Key }
  if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { continue }
  $id = 'launcher-' + $l.Key.ToLower()
  if ($l.Key -eq 'Riot') { Add-Game $id $l.Title 'Launchers' ('wscript.exe "' + $riotVbs + '" riotclient') '' (Poster $id '') 'Launcher' }   # prepares the PC first
  else { Add-Game $id $l.Title 'Launchers' ('"' + $exe + '"') (Split-Path -Parent $exe) (Poster $id '') 'Launcher' }
  $iconOf[$id] = $exe
}
# Roblox: per-user app kept in Launchers\Roblox; Roblox.vbs points the client's roblox:// links there, then starts it
$rbx = Get-RobloxExe
if ($rbx) { $id = 'launcher-roblox'; Add-Game $id 'Roblox' 'Launchers' ('wscript.exe "' + (Join-Path $ClientDir 'Roblox.vbs') + '" launch') '' (Poster $id '') 'Launcher'; $iconOf[$id] = $rbx }
# WO Mic / VB-CABLE: the clients install them at boot from Tools\WOMic and Tools\VBCABLE (Client-Mic.ps1). WO Mic Client is
# not on the master, so its card starts WOMic.vbs, which finds the program on the client. Rename / hide: extra-games.json by id.
$wmSetup = Get-ChildItem -LiteralPath (Join-Path $ToolsDir 'WOMic') -Filter 'WOMicClientSetup*.exe' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($wmSetup) { $id = 'tool-womic'; Add-Game $id 'WO Mic' 'Apps' ('wscript.exe "' + (Join-Path $ClientDir 'WOMic.vbs') + '"') '' (Poster $id '') 'WO Mic'; $iconOf[$id] = $wmSetup.FullName }
$vbCp = Join-Path $ToolsDir 'VBCABLE\VBCABLE_ControlPanel.exe'
if (Test-Path -LiteralPath $vbCp) { $id = 'tool-vbcable'; Add-Game $id 'VB-CABLE' 'Apps' ('"' + $vbCp + '"') (Split-Path -Parent $vbCp) (Poster $id '') 'VB-Audio'; $iconOf[$id] = $vbCp }
# OSLink (LDPlayer remote play): where its service / installer says, else <shared drive>:\LDPlayer\OSLink\bin - one card
# (category Apps) unless Settings\extra-games.json has one already (id app-oslink). 20 Nov 2026: a new shop gets it by itself.
if (-not @($games | Where-Object { $_.id -eq 'app-oslink' }).Count) {
  $olc = New-Object System.Collections.Generic.List[string]
  $olIp = "$((Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\LDRemoteSvc' -ErrorAction SilentlyContinue).ImagePath)"
  $olM = [regex]::Match($olIp, '^\s*"?([^"]+?\.exe)'); if ($olM.Success) { $olc.Add((Split-Path -Parent $olM.Groups[1].Value)) }
  foreach ($d in (Get-SharedDrives).ToCharArray()) { $olc.Add("${d}:\LDPlayer\OSLink\bin") }
  $olBin = $olc | Where-Object { $_ -and (Get-SharedDrives).Contains($_.Substring(0, 1).ToUpper()) -and (Test-Path -LiteralPath (Join-Path $_ 'ldremote.exe')) } | Select-Object -First 1
  if ($olBin) { $id = 'app-oslink'; $olExe = Join-Path $olBin 'ldremote.exe'; Add-Game $id 'OSLink' 'Apps' ('"' + $olExe + '"') $olBin (Poster $id (Split-Path -Parent $olBin)) 'OSLink'; $iconOf[$id] = $olExe }
}

# ---------- apply overrides, write ----------
# 20 Nov 2026 (iPlay's way of starting anti-cheat games): the cards in Settings\game-start.json start through
# System\Client\GameStart.vbs <id> (Client-GameStart.ps1: closes hung copies, checks the PC, then runs the card's old
# command, kept in "direct"); cwd = the game folder, so "open file location" still opens the game
$gsIds = @{}
$gsFile = Join-Path $SettingsDir 'game-start.json'
if (Test-Path -LiteralPath $gsFile) {
  try { foreach ($p in (Get-Content -LiteralPath $gsFile -Raw -Encoding UTF8 | ConvertFrom-Json).games.PSObject.Properties) { $gsIds[$p.Name] = $true } }
  catch { $warn.Add("Settings\game-start.json is not valid JSON: $($_.Exception.Message)") }
}
$final = foreach ($g in $games) {
  $o = $overrides[$g.id]
  if ($o) {
    if ($o.hide) { continue }
    foreach ($prop in 'title', 'cat', 'img', 'cmd', 'cwd') { if ($o.$prop) { $g.$prop = $o.$prop } }
  }
  if ($gsIds.ContainsKey($g.id) -and $g.cmd -notmatch 'GameStart\.vbs') {
    $g | Add-Member -NotePropertyName direct -NotePropertyValue $g.cmd -Force
    $g.cmd = 'wscript.exe "' + (Join-Path $ClientDir 'GameStart.vbs') + '" ' + $g.id
    if ($steamDirOf[$g.id]) { $g.cwd = $steamDirOf[$g.id] }
  }
  $g
}
$order = @{ 'Steam' = 1; 'Riot' = 2; 'Epic' = 2.5; 'EA' = 3; 'Rockstar' = 4; 'Ubisoft' = 5; 'Garena' = 6; 'HoYoPlay' = 6.5; 'Gacha' = 6.8; 'Online' = 7; 'Mobile' = 8; 'Apps' = 98; 'Launchers' = 99 }
$final = @($final | Sort-Object @{ e = { if ($order.ContainsKey($_.cat)) { $order[$_.cat] } else { 50 } } }, title)

# ---------- no artwork: poster made from the program icon (posters\_auto\<id>.jpg) ----------
# renderer: the packaged menu (<exe> --imagetool) or, before the first build, Electron from Menu\source\node_modules
$appExe = (Get-MenuInfo).Exe
$electron = Join-Path $Menu 'source\node_modules\electron\dist\electron.exe'
$jobs = @(); $made = @{}
foreach ($g in $final | Where-Object { -not $_.img }) {
  $jpg = Join-Path $menuData "posters\_auto\$($g.id).jpg"
  $made[$g.id] = $jpg
  if (Test-Path -LiteralPath $jpg) { continue }
  if ($artOf[$g.id]) { $jobs += [ordered]@{ mode = 'cover'; src = $artOf[$g.id]; out = $jpg; w = 920; h = 586 }; continue }
  $src = $iconOf[$g.id]
  if (-not $src -or -not (Test-Path -LiteralPath $src)) { continue }
  $png = Join-Path $menuData "posters\_auto\icons\$($g.id).png"
  if (Export-Icon $src $png) { $jobs += [ordered]@{ mode = 'icon'; src = $png; out = $jpg; w = 920; h = 586 } }
}
if ($jobs) {
  $jobFile = Join-Path $env:TEMP 'gcafe-poster-jobs.json'
  [IO.File]::WriteAllText($jobFile, (ConvertTo-Json -InputObject @($jobs) -Depth 3), (New-Object Text.UTF8Encoding $false))
  $env:ELECTRON_RUN_AS_NODE = $null
  if (Test-Path -LiteralPath $appExe) {
    Start-Process -FilePath $appExe -ArgumentList '--imagetool', ('"' + $jobFile + '"') -Wait -WindowStyle Hidden
  } elseif (Test-Path -LiteralPath $electron) {
    Start-Process -FilePath $electron -ArgumentList ('"' + (Join-Path $Menu 'tools\_system\imagetool') + '"'), ('"' + $jobFile + '"') -Wait -WindowStyle Hidden
  } else { $warn.Add('posters skipped: build the menu first (OSYNC.bat > Tools > Build the menu program)') }
}
foreach ($g in $final) { if (-not $g.img -and $made[$g.id] -and (Test-Path -LiteralPath $made[$g.id])) { $g.img = '/poster/' + [uri]::EscapeDataString($made[$g.id]) } }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
$json = ConvertTo-Json -InputObject $final -Depth 4
# rewrite only when the list changed: a diskless client that is already running cannot read a file rewritten
# under it (it reads garbage -> empty menu) until it reboots, and the watcher runs this every hour
$prev = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out) } else { $null }
$state = if ($prev -ceq $json) { 'unchanged, not rewritten' } else { [IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding $false)); 'updated' }
$final | Group-Object cat | ForEach-Object { Write-Output ("{0,-10} {1,3}  {2}" -f $_.Name, $_.Count, (($_.Group | ForEach-Object title) -join ', ')) }
Write-Output "total: $($final.Count) -> $out ($state)"
$warn | ForEach-Object { Write-Output "WARNING $_" }
