# Build-GameList.ps1 - run on the MASTER. Writes <GCafe>\data\games.json for the offline game menu.
# Sources: Steam libraries, Riot games (GAMELUNCHER kit), EA-app games, data\games.custom.json,
#          and every launcher found in GAMELUNCHER (category "Launchers").
# Poster: data\posters\<id>.jpg|png|webp  >  zPoster.jpg in the game folder  >  Steam header image.
# -GameLuncher: the GAMELUNCHER folder next to GCafe (e.g. H:\OSYNC\GAMELUNCHER) unless given.
param([string]$GameLuncher = (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'GAMELUNCHER'))
$ErrorActionPreference = 'Stop'
$gcafe   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)       # ...\GCafe
$dataDir = Join-Path $gcafe 'data'
$out     = Join-Path $dataDir 'games.json'
$games   = New-Object System.Collections.Generic.List[object]
$warn    = New-Object System.Collections.Generic.List[string]
$iconOf  = @{}                                                         # id -> exe/ico used for a poster when no artwork exists
$artOf   = @{}                                                         # id -> picture inside the game (e.g. Unreal Splash.bmp) to crop into a poster
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
  foreach ($ext in 'jpg', 'png', 'webp') { $p = Join-Path $dataDir "posters\$id.$ext"; if (Test-Path -LiteralPath $p) { return '/poster/' + [uri]::EscapeDataString($p) } }
  if ($root) { $p = Join-Path $root 'zPoster.jpg'; if (Test-Path -LiteralPath $p) { return '/poster/' + [uri]::EscapeDataString($p) } }
  return ''
}
# Steam artwork: copy the header Steam already cached on this PC into data\posters\_auto (works offline on clients),
# else ask the Steam store for the header URL (new games use hashed CDN paths), else the classic CDN path.
function SteamPoster([string]$appid) {
  $img = Poster "steam-$appid" ''
  if ($img) { return $img }
  $cache = Join-Path $steamDir "appcache\librarycache\$appid"
  $src = foreach ($n in 'header.jpg', 'library_header.jpg') { Get-ChildItem -LiteralPath $cache -Recurse -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
  $src = @($src)[0]
  if ($src) {
    $dst = Join-Path $dataDir "posters\_auto\steam-$appid.jpg"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src.FullName -Destination $dst -Force
    return '/poster/' + [uri]::EscapeDataString($dst)
  }
  $auto = Join-Path $dataDir "posters\_auto\steam-$appid.jpg"
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
$steamDir = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
if ($steamDir) { $steamDir = $steamDir -replace '/', '\' }
$steamExe = if ($steamDir) { Join-Path $steamDir 'steam.exe' } else { '' }
$skipApps = @('228980', '431960')                                     # Steamworks redist, Wallpaper Engine
$catOf = @{ '1172470' = 'EA'; '1238810' = 'EA'; '2807960' = 'EA'; '1222670' = 'EA';
            '271590' = 'Rockstar'; '3240220' = 'Rockstar'; '1174180' = 'Rockstar'; '359550' = 'Ubisoft' }
if ($steamExe -and (Test-Path -LiteralPath $steamExe)) {
  $vdf = Get-Content -LiteralPath (Join-Path $steamDir 'steamapps\libraryfolders.vdf') -Raw -Encoding UTF8
  $libs = [regex]::Matches($vdf, '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' } | Sort-Object -Unique
  foreach ($lib in $libs) {
    foreach ($m in Get-ChildItem -LiteralPath (Join-Path $lib 'steamapps') -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) {
      $t = Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8
      $appid = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
      $name = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value -replace '[\u2122\u00AE]', ''
      $dir = Join-Path $lib ('steamapps\common\' + [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value)
      if (-not $appid -or $skipApps -contains $appid -or -not (Test-Path -LiteralPath $dir)) { continue }
      $img = SteamPoster $appid
      $cat = if ($catOf.ContainsKey($appid)) { $catOf[$appid] } else { 'Steam' }
      Add-Game "steam-$appid" $name.Trim() $cat ('"' + $steamExe + '" -applaunch ' + $appid) $steamDir $img 'Steam'
    }
  }
} else { $warn.Add('Steam not found') }

# ---------- Riot (GAMELUNCHER\ClientSetup prepares the PC, then starts the game) ----------
$riotVbs = Join-Path $GameLuncher 'ClientSetup\RiotSilent.vbs'
$riotMeta = Join-Path $GameLuncher 'ClientSetup\_system\Metadata'
$riot = [ordered]@{ 'valorant' = 'VALORANT'; 'league_of_legends' = 'League of Legends'; 'teamfighttactics' = 'Teamfight Tactics' }
if (Test-Path -LiteralPath $riotVbs) {
  foreach ($k in $riot.Keys) {
    $y = Join-Path $riotMeta "$k.live\$k.live.product_settings.yaml"
    if (-not (Test-Path -LiteralPath $y)) { continue }
    $dir = ([regex]::Match((Get-Content -LiteralPath $y -Raw), 'product_install_full_path:\s*"([^"]+)"').Groups[1].Value) -replace '/', '\'
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
    Add-Game "riot-$k" $riot[$k] 'Riot' ('wscript.exe "' + $riotVbs + '" ' + $k) '' (Poster "riot-$k" $dir) 'Riot'
    $iconOf["riot-$k"] = Join-Path $riotMeta "$k.live\$k.live.ico"
  }
}

# ---------- EA app games (installed through the EA app, not Steam) ----------
# Every game installed through the EA app (registry "Install Dir" with __Installer\installerdata.xml, not a Steam copy).
# Known offer ids start the game directly; others open the EA app on the game (add an offer id below when known).
$eaOffers = @{ 'Respawn\Apex' = @('Origin.OFR.50.0002694', '1172470') }      # registry key = offer id, Steam appid (artwork)
$eaLauncher = Join-Path $GameLuncher 'EA Desktop\EA Desktop\EALauncher.exe'
foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node' -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue }) {
  $dir = "$($k.GetValue('Install Dir'))"
  if (-not $dir -or $dir -match '\\steamapps\\' -or -not (Test-Path -LiteralPath (Join-Path $dir '__Installer\installerdata.xml'))) { continue }
  $rel = ($k.Name -split '\\')[-2..-1] -join '\'
  $id = 'ea-' + (($k.Name -split '\\')[-1] -replace '[^A-Za-z0-9]', '').ToLower()
  $title = "$($k.GetValue('DisplayName'))"; if (-not $title) { $title = Split-Path -Leaf $dir.TrimEnd('\') }
  $img = Poster $id $dir
  if ($eaOffers.ContainsKey($rel)) {
    if (-not $img -and $steamDir) { $img = SteamPoster $eaOffers[$rel][1] }
    Add-Game $id $title 'EA' ("origin2://game/launch?offerIds=" + $eaOffers[$rel][0]) '' $img 'EA app'
  } elseif (Test-Path -LiteralPath $eaLauncher) {
    Add-Game $id $title 'EA' ('"' + $eaLauncher + '"') (Split-Path -Parent $eaLauncher) $img 'EA app'
    $warn.Add("EA app game without a direct-start id (opens the EA app): $title - add its offer id in Build-GameList.ps1 `$eaOffers")
  }
  $iconOf[$id] = $eaLauncher
}

# ---------- Epic games (ClientSetup\EpicSilent.vbs gives clients the install list, then starts the game) ----------
$epicVbs = Join-Path $GameLuncher 'ClientSetup\EpicSilent.vbs'
if (Test-Path -LiteralPath $epicVbs) {
  foreach ($f in Get-ChildItem (Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests') -Filter *.item -ErrorAction SilentlyContinue) {
    $m = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $m.InstallLocation -or -not (Test-Path -LiteralPath $m.InstallLocation) -or $m.bIsApplication -eq $false) { continue }
    $id = 'epic-' + $m.AppName.ToLower()
    Add-Game $id $m.DisplayName 'Epic' ('wscript.exe "' + $epicVbs + '" ' + $m.AppName) '' (Poster $id $m.InstallLocation) 'Epic'
    $iconOf[$id] = Join-Path $m.InstallLocation $m.LaunchExecutable
    $splash = Get-ChildItem -LiteralPath $m.InstallLocation -Filter 'Splash.bmp' -Recurse -Depth 4 -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($splash) { $artOf[$id] = $splash.FullName }
  }
}

# ---------- custom games + overrides ----------
$customFile = Join-Path $dataDir 'games.custom.json'
$overrides = @{}
if (Test-Path -LiteralPath $customFile) {
  $custom = (Get-Content -LiteralPath $customFile -Raw -Encoding UTF8) | ConvertFrom-Json
  foreach ($g in $custom.games) {
    if (-not $g.exe) { $overrides[$g.id] = $g; continue }
    $exe = $null
    foreach ($c in @($g.exe)) { $c = $c.Replace('{GAMELUNCHER}', $GameLuncher); if (Test-Path -LiteralPath $c) { $exe = $c; break } }
    if (-not $exe) { $warn.Add("not found, skipped: $($g.title)"); continue }
    $fi = Get-Item -LiteralPath $exe -Force
    if ($fi.Length -eq 0 -and -not ($fi.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $warn.Add("empty exe (not fully installed?), skipped: $($g.title)"); continue }
    $root = if ($g.root) { $g.root } else { Split-Path -Parent $exe }
    $cmd = '"' + $exe + '"' + $(if ($g.args) { ' ' + $g.args } else { '' })
    $img = if ($g.img) { $g.img } else { Poster $g.id $root }
    Add-Game $g.id $g.title $g.cat $cmd (Split-Path -Parent $exe) $img $(if ($g.platform) { $g.platform } else { '' })
    $iconOf[$g.id] = $exe
  }
}

# ---------- new game folders nobody listed yet (X:\Online, X:\Mobile, X:\PvP, X:\Single Player, X:\Web ...) ----------
# Picks the most likely start exe; the result is shown as "AUTO" so it can be checked. To fix one, add an entry to
# games.custom.json with "root" = that folder (or {"id": "auto-...", "hide": true} to hide it).
$autoCats = @{ 'Online' = 'Online'; 'PvP' = 'Online'; 'Mobile' = 'Mobile'; 'Single Player' = 'Single Player'; 'Offline' = 'Single Player'; 'Web' = 'Apps'; 'Emulator' = 'Emulator' }
$notStart = '(?i)unins|setup|install|updat|patch|crash|report|redist|dxsetup|prereq|easyanticheat|beservice|battleye|^cef|chrome_|webview|qtwebengine|7z|helper|notif|service|bugtrap|dump|elevat|repair|diag|benchmark|unitycrash|xigncode|^xldr|gameguard|anticheat|^ace-|tenprotect|_pwa|proxy|^python|^java|^node'
# start-exe score: launcher / portable wrapper > start / play; + name like the folder; - each subfolder level
# (tested against the 28 hand-made entries of the main branch: all picked right)
function ExeScore($e, [string]$folderName, [string]$folderPath) {
  $s = 0; $n = Slug $e.BaseName; $fs = Slug $folderName
  if ($n -match 'launcher|portable') { $s += 5 } elseif ($n -match 'start|play') { $s += 3 }
  if ($fs -and $n -and ($n.Contains($fs) -or $fs.Contains($n))) { $s += 3 }
  $s - $e.DirectoryName.Substring($folderPath.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries).Count
}
$covered = New-Object System.Collections.Generic.List[string]
foreach ($g in $games) {
  if ($g.cwd) { $covered.Add($g.cwd.TrimEnd('\')) }
  $m = [regex]::Match("$($g.cmd)", '^"([^"]+)"'); if ($m.Success) { $covered.Add((Split-Path -Parent $m.Groups[1].Value)) }
}
if ($custom) { foreach ($g in $custom.games) { if ($g.root) { $covered.Add($g.root.TrimEnd('\')) }; foreach ($c in @($g.exe)) { if ($c) { $covered.Add((Split-Path -Parent $c.Replace('{GAMELUNCHER}', $GameLuncher))) } } } }
function Slug([string]$s) { ($s -replace '[^A-Za-z0-9]', '').ToLower() }
foreach ($drv in Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[D-Z]:\\$' }) {
  foreach ($catDir in $autoCats.Keys) {
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $drv.Root $catDir) -Directory -ErrorAction SilentlyContinue) {
      $fp = $f.FullName
      if ($covered | Where-Object { $_ -ieq $fp -or $_.StartsWith($fp + '\', [StringComparison]::OrdinalIgnoreCase) }) { continue }
      $best = Get-ChildItem -LiteralPath $fp -Filter *.exe -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 100KB -and $_.BaseName -notmatch $notStart } |
        Sort-Object @{ e = { ExeScore $_ $f.Name $fp }; Descending = $true }, @{ e = { $_.Length }; Descending = $true } | Select-Object -First 1
      if (-not $best) { $warn.Add("new folder without a start exe: $fp"); continue }
      $id = 'auto-' + (Slug $f.Name)
      Add-Game $id $f.Name $autoCats[$catDir] ('"' + $best.FullName + '"') $best.DirectoryName (Poster $id $fp) ''
      $iconOf[$id] = $best.FullName
      $warn.Add("AUTO added $($f.Name) [$($autoCats[$catDir])] -> $($best.FullName)  (check it once)")
    }
  }
}

# ---------- launchers in GAMELUNCHER ----------
$launchers = @(
  @('launcher-steam', 'Steam', $steamExe),
  @('launcher-riot', 'Riot Client', (Join-Path $GameLuncher 'ClientSetup\Riot Client.bat')),
  @('launcher-ea', 'EA app', (Join-Path $GameLuncher 'EA Desktop\EA Desktop\EALauncher.exe')),
  @('launcher-epic', 'Epic Games', (Join-Path $GameLuncher 'Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe')),
  @('launcher-garena', 'Garena', (Join-Path $GameLuncher 'Garena\Garena.exe')),
  @('launcher-ubisoft', 'Ubisoft Connect', (Join-Path $GameLuncher 'Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe')),
  @('launcher-rockstar', 'Rockstar Games', (Join-Path $GameLuncher 'Rockstar Games Launcher\LauncherPatcher.exe')),
  @('launcher-hoyoplay', 'HoYoPlay', (Join-Path $GameLuncher 'HoYoPlay\launcher.exe')),
  @('launcher-modrinth', 'Modrinth (Minecraft)', (Join-Path $GameLuncher 'Modrinth App\Modrinth App.exe')))
foreach ($l in $launchers) {
  if ($l[2] -and (Test-Path -LiteralPath $l[2])) {
    Add-Game $l[0] $l[1] 'Launchers' ('"' + $l[2] + '"') (Split-Path -Parent $l[2]) (Poster $l[0] '') 'Launcher'
    $iconOf[$l[0]] = $l[2]
  }
}
$iconOf['launcher-riot'] = Join-Path $GameLuncher 'RiotClient\RiotClientServices.exe'      # the .bat has no icon

# ---------- apply overrides, write ----------
$final = foreach ($g in $games) {
  $o = $overrides[$g.id]
  if ($o) {
    if ($o.hide) { continue }
    foreach ($prop in 'title', 'cat', 'img', 'cmd', 'cwd') { if ($o.$prop) { $g.$prop = $o.$prop } }
  }
  $g
}
$order = @{ 'Steam' = 1; 'Riot' = 2; 'Epic' = 2.5; 'EA' = 3; 'Rockstar' = 4; 'Ubisoft' = 5; 'Garena' = 6; 'Online' = 7; 'Mobile' = 8; 'Apps' = 98; 'Launchers' = 99 }
$final = @($final | Sort-Object @{ e = { if ($order.ContainsKey($_.cat)) { $order[$_.cat] } else { 50 } } }, title)

# ---------- no artwork: poster made from the program icon (data\posters\_auto\<id>.jpg) ----------
# renderer: the packaged client (app\0JAYSHOP.exe --imagetool) or, before the first build, Electron from source\node_modules
$appExe = Join-Path $gcafe 'app\0JAYSHOP.exe'
$electron = Join-Path $gcafe 'source\node_modules\electron\dist\electron.exe'
$jobs = @(); $made = @{}
foreach ($g in $final | Where-Object { -not $_.img }) {
  $jpg = Join-Path $dataDir "posters\_auto\$($g.id).jpg"
  $made[$g.id] = $jpg
  if (Test-Path -LiteralPath $jpg) { continue }
  if ($artOf[$g.id]) { $jobs += [ordered]@{ mode = 'cover'; src = $artOf[$g.id]; out = $jpg; w = 920; h = 586 }; continue }
  $src = $iconOf[$g.id]
  if (-not $src -or -not (Test-Path -LiteralPath $src)) { continue }
  $png = Join-Path $dataDir "posters\_auto\icons\$($g.id).png"
  if (Export-Icon $src $png) { $jobs += [ordered]@{ mode = 'icon'; src = $png; out = $jpg; w = 920; h = 586 } }
}
if ($jobs) {
  $jobFile = Join-Path $env:TEMP 'gcafe-poster-jobs.json'
  [IO.File]::WriteAllText($jobFile, (ConvertTo-Json -InputObject @($jobs) -Depth 3), (New-Object Text.UTF8Encoding $false))
  $env:ELECTRON_RUN_AS_NODE = $null
  if (Test-Path -LiteralPath $appExe) {
    Start-Process -FilePath $appExe -ArgumentList '--imagetool', ('"' + $jobFile + '"') -Wait -WindowStyle Hidden
  } elseif (Test-Path -LiteralPath $electron) {
    Start-Process -FilePath $electron -ArgumentList ('"' + (Join-Path $PSScriptRoot 'imagetool') + '"'), ('"' + $jobFile + '"') -Wait -WindowStyle Hidden
  } else { $warn.Add('posters skipped: build the app first (tools\Build-App.bat)') }
}
foreach ($g in $final) { if (-not $g.img -and $made[$g.id] -and (Test-Path -LiteralPath $made[$g.id])) { $g.img = '/poster/' + [uri]::EscapeDataString($made[$g.id]) } }
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$json = ConvertTo-Json -InputObject $final -Depth 4
[IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding $false))
$final | Group-Object cat | ForEach-Object { Write-Output ("{0,-10} {1,3}  {2}" -f $_.Name, $_.Count, (($_.Group | ForEach-Object title) -join ', ')) }
Write-Output "total: $($final.Count) -> $out"
$warn | ForEach-Object { Write-Output "WARNING $_" }
