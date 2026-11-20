# Online-Library.ps1 - MASTER: the online library ("Klang Online" page of the console) - games other branches have and this one not.
#   Publish : this branch's shareable menu games -> the hub (Hub-Server.ps1). Found wherever the shop keeps them:
#             Steam games (any Steam library on a shared drive, size from the appmanifest - no folder walk),
#             folder games in the game folders (GAME\Online\..), in X:\Online X:\Mobile ... / X:\Games\<kind> on every shared
#             drive, HoYoPlay games (Launchers\HoYoPlay\games\..), and games added by hand in extra-games.json ("root" or the
#             exe's folder, e.g. J:\Star Rail Games). Never shared: Apps / Launchers (browser profiles, remote tools, logins),
#             X:\Web, launcher games (Riot, Epic, EA ...), anything in Launchers \ Menu \ Tools \ System.
#   Pull    : ask the hub for a game -> the branch that has it makes a .torrent (private, the hub is the tracker) and seeds it
#             -> this branch downloads it into the place with the most free space in the shop's own layout (a game folder,
#             or X:\<kind>\<game> on a shared drive that uses X:\Online ...; Steam games into the emptiest Steam library),
#             after a disk-space check -> the game list adds it (watcher / console). Launcher games (Riot, Epic, EA ...) are not shared.
#   Engine  : aria2 (Tools\aria2\aria2c.exe, JSON-RPC on 127.0.0.1) or mock (tests: copies from the seeder's folder on this
#             PC and checks every piece against the .torrent). Settings OnlineEngine=aria2|mock.
#   Network : BitTorrent needs ONE of the two branches to accept inbound connections (aria2 connects out both as downloader
#             and as seeder; the tracker tells each side the other's address). Settings OnlineUpnp=on: the router maps
#             OnlineBtPort to this PC while aria2 runs (Online-Upnp.ps1, renewed every sync, removed when aria2 stops) and aria2
#             tells the tracker the router's public IP (--bt-external-ip). OnlineExternalIP=<IP or DDNS name> sets it by hand.
#             A downloaded .torrent gets THIS branch's hub address as tracker (OnlineHub can be 127.0.0.1 on the hub's own PC).
# Settings: OnlineHub=http://<host>:4667  OnlineBranch=<short id>  OnlineBranchName=<shown name>  OnlineEngine  OnlineBind=<ip>
#           OnlineBtPort=6881 OnlineRpcPort=6800 OnlineMaxDownKB=0 OnlineMaxUpKB=0 (0 = no limit) OnlineUpnp=off|on OnlineExternalIP=
# Key: System\Data\Online\online.key (same on the hub and every branch). Working files (aria2 session / log, jobs, sizes): Settings
#   OnlineData=<folder on the master's own disk, e.g. C:\OSYNC-Online> - keep them off the drives the clients share - else System\Data\Online
#   ($env:OSYNC_ONLINEDATA = tests).
#   Online-Library.ps1 -Sync         publish (every 30 min) + serve requests (make torrent, seed) + move pull jobs on
#                                    + keep aria2 running while it has work, renew / remove the UPnP mapping
#   Online-Library.ps1 -Publish | -Pull <game key> | -MockWorker <job id>
#   Online-Library.ps1 -List         which menu games would be shared, from where (no sizes, no folder walk)
#   Online-Library.ps1 -Stop         stop aria2 and remove its UPnP mapping
# Dot-sourced by Console-Server.ps1 (functions only).
param([switch]$Sync, [switch]$Publish, [string]$Pull = '', [string]$MockWorker = '', [switch]$List, [switch]$Stop)
if (-not (Get-Command Get-Setting -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Common.ps1') }
. (Join-Path $PSScriptRoot 'Online-Torrent.ps1')
. (Join-Path $PSScriptRoot 'Online-Upnp.ps1')

$OnlineCats = 'Online', 'PvP', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'Garena', 'HoYoPlay', 'Gacha'
$OnlineNoShareKinds = 'Web'                                   # X:\Web = browsers, chat, remote tools (logins inside)
$OnlineNoShareCats = 'Apps', 'Launchers'
$OnlineNoShareName = '(?i)OSLink|RustDesk|AnyDesk|TeamViewer|Parsec|Sunshine|Discord|Telegram|WeChat|LDPlayer|CooperAgent|Overwolf'
$OnlineCatKind = @{ 'Anime RPG' = 'Gacha' }                   # a shop's own category -> the folder kind at the other branch

function Get-OnlineConfig {
  $data = Get-OnlineDataDir
  $aria = Join-Path $ToolsDir 'aria2\aria2c.exe'
  $engine = Get-Setting 'OnlineEngine' ''
  if (-not $engine) { $engine = if (Test-Path -LiteralPath $aria) { 'aria2' } else { 'none' } }
  $branch = (Get-Setting 'OnlineBranch' $env:COMPUTERNAME) -replace '[^A-Za-z0-9._\-]', '-'
  $hub = (Get-Setting 'OnlineHub' '').TrimEnd('/')
  $key = Get-OnlineSecret
  [pscustomobject]@{ hub = $hub; branch = $branch; name = (Get-Setting 'OnlineBranchName' $branch); engine = $engine; key = $key; data = $data; aria2 = $aria
    btPort = [int](Get-Setting 'OnlineBtPort' '6881'); rpcPort = [int](Get-Setting 'OnlineRpcPort' '6800')
    maxDownKB = [int](Get-Setting 'OnlineMaxDownKB' '0'); maxUpKB = [int](Get-Setting 'OnlineMaxUpKB' '0')
    bind = (Get-Setting 'OnlineBind' ''); upnp = ((Get-Setting 'OnlineUpnp' 'off') -match '^(on|1|true|yes)$'); externalIP = (Get-Setting 'OnlineExternalIP' '')
    enabled = [bool]($hub -and $key.Length -ge 12) }
}
function Initialize-OnlineData($cfg) { foreach ($d in $cfg.data, (Join-Path $cfg.data 'torrents'), (Join-Path $cfg.data 'jobs')) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }
function Write-OnlineLog($cfg, [string]$m) { try { Add-Content -LiteralPath (Join-Path $cfg.data 'online.log') -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $m) -Encoding UTF8 } catch { } }

function Invoke-Hub($cfg, [string]$Method, [string]$Path, $Body = $null, [int]$TimeoutSec = 30) {
  $p = @{ Uri = "$($cfg.hub)$Path"; Method = $Method; Headers = @{ 'X-Hub-Key' = $cfg.key }; TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
  if ($null -ne $Body) { $p.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 8 -Compress)); $p.ContentType = 'application/json; charset=utf-8' }
  try { Invoke-RestMethod @p } catch {
    $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch { }
    if ($code -eq 404) { return $null }
    $detail = "$($_.ErrorDetails.Message)"; try { $detail = ($detail | ConvertFrom-Json).error } catch { }
    throw "hub $Method $Path : $($_.Exception.Message) $detail"
  }
}

# ---------- this branch's games ----------
function Get-MenuGames { $f = Join-Path $Menu 'data\games.json'; if (-not (Test-Path -LiteralPath $f)) { return @() }; $x = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8).Trim([char]0xFEFF) | ConvertFrom-Json; @($x) }
function Get-SteamManifest([string]$appid) {
  foreach ($l in @(Get-SteamLibraries)) {
    $m = Join-Path $l "steamapps\appmanifest_$appid.acf"
    if (Test-Path -LiteralPath $m) {
      $t = [IO.File]::ReadAllText($m); $d = [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value
      if ($d) { return @{ Manifest = $m; Folder = (Join-Path $l "steamapps\common\$d"); InstallDir = $d; SizeOnDisk = [int64]"0$([regex]::Match($t, '"SizeOnDisk"\s+"(\d+)"').Groups[1].Value)" } }
    }
  }
  $null
}
# roots that hold <kind>\<game> folders on the shared drives: X:\Games (X:\Games\Online ...) and X:\ (X:\Online ...), only
# when at least one kind folder exists there. $env:OSYNC_DRIVEROOTS (tests, ; separated) replaces the drive scan.
function Get-DriveGameRoots {
  $cand = if ($env:OSYNC_DRIVEROOTS) { @($env:OSYNC_DRIVEROOTS -split ';' | Where-Object { $_ }) } else { @((Get-SharedDrives).ToCharArray() | ForEach-Object { "${_}:\Games"; "${_}:\" }) }
  foreach ($r in $cand) {
    $r = $r.TrimEnd('\'); if ($r.Length -eq 2) { $r += '\' }
    if (@($OnlineCats | Where-Object { Test-Path -LiteralPath (Join-Path $r $_) -PathType Container }).Count) { $r }
  }
}
function Get-RootedParts([string]$root, [string]$path) {   # parts of $path below $root, or $null when it is not below
  $r = $root.TrimEnd('\') + '\'
  if (-not $path.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { return $null }
  , @($path.Substring($r.Length).Split('\') | Where-Object { $_ })
}
function Get-ExtraGameIndex { $i = @{}; try { $x = Read-ExtraGames; foreach ($g in @(if ($x -and $x.games) { $x.games })) { if ($g.id -and $g.exe) { $i[[string]$g.id] = $g } } } catch { }; $i }
function Expand-OnlinePath([string]$p) { $p.Replace('{GAMES}', $GamesRoot).Replace('{LAUNCHERS}', $Launchers).Replace('{GAMELUNCHER}', $Launchers).Replace('{OSYNC}', $Root) }
# a menu game -> @{ key; title; cat; kind (folder|hoyoplay|steam); rel; folder; [manifest; size] } or $null (not shareable)
function Resolve-ShareableGame($g, $ExtraIndex = $null, $DriveRoots = $null) {
  $id = [string]$g.id
  if ($OnlineNoShareCats -contains "$($g.cat)" -or $id -match '^(app|launcher|tool)-') { return $null }
  if ($id -match '^steam-(\d+)$') {
    $m = Get-SteamManifest $Matches[1]
    if ($m -and (Test-Path -LiteralPath $m.Folder)) { return @{ key = $id; title = $g.title; cat = $g.cat; kind = 'steam'; rel = "steamapps\common\$($m.InstallDir)"; folder = $m.Folder; manifest = $m.Manifest; size = $m.SizeOnDisk } }
    return $null
  }
  $exe = [regex]::Match("$($g.cmd)", '^\s*"([^"]+\.exe)"').Groups[1].Value
  if (-not $exe) { $exe = [regex]::Match("$($g.cmd)", '^\s*(\S+\.exe)').Groups[1].Value }
  if (-not $exe -or $exe -notmatch '^[A-Za-z]:\\') { return $null }
  $hy = Join-Path (Get-LauncherDir 'HoYoPlay') 'games'
  if ($exe.StartsWith($hy + '\', [StringComparison]::OrdinalIgnoreCase)) {
    $top = $exe.Substring($hy.Length + 1).Split('\')[0]
    return @{ key = $id; title = $g.title; cat = $g.cat; kind = 'hoyoplay'; rel = $top; folder = (Join-Path $hy $top) }
  }
  foreach ($r in @(Get-GameFolders)) {                          # GAME\<kind>\<game> or GAME\<game>
    $parts = Get-RootedParts $r $exe
    if ($null -eq $parts) { continue }
    if ($parts.Count -lt 2) { return $null }
    $rel = if ($OnlineCats -contains $parts[0] -and $parts.Count -ge 3) { "$($parts[0])\$($parts[1])" } else { $parts[0] }
    if ($OnlineCats -contains $rel -or $OnlineNoShareKinds -contains $parts[0] -or $rel -match $OnlineNoShareName) { return $null }
    return @{ key = $id; title = $g.title; cat = $g.cat; kind = 'folder'; rel = $rel; folder = (Join-Path $r $rel) }
  }
  if ($null -eq $DriveRoots) { $DriveRoots = @(Get-DriveGameRoots) }
  foreach ($r in $DriveRoots) {                                 # X:\<kind>\<game> / X:\Games\<kind>\<game> (this shop's layout)
    $parts = Get-RootedParts $r $exe
    if ($null -eq $parts -or $parts.Count -lt 3 -or $OnlineCats -notcontains $parts[0]) { continue }
    if ($OnlineNoShareKinds -contains $parts[0] -or $parts[1] -match $OnlineNoShareName) { return $null }
    $rel = "$($parts[0])\$($parts[1])"
    return @{ key = $id; title = $g.title; cat = $g.cat; kind = 'folder'; rel = $rel; folder = (Join-Path $r $rel) }
  }
  # added by hand somewhere else (J:\Star Rail Games, D:\FIFA\32836, G:\Minecraft): its "root", else the exe's folder
  if ($null -eq $ExtraIndex) { $ExtraIndex = Get-ExtraGameIndex }
  $e = $ExtraIndex[$id]
  if (-not $e) { return $null }
  $folder = if ($e.root) { (Expand-OnlinePath "$($e.root)").TrimEnd('\') } else { Split-Path -Parent $exe }
  if (-not $folder -or $folder.Length -lt 4) { return $null }
  if (-not $env:OSYNC_DRIVEROOTS -and (Get-SharedDrives).IndexOf($folder.Substring(0, 1).ToUpper()) -lt 0) { return $null }   # clients' drives only
  foreach ($no in @($Launchers, $OldLauncherRoot, $Menu, $OldMenuDir, $ToolsDir, $SystemDir)) { if ($no -and ($folder -ieq $no -or $folder.StartsWith($no.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase))) { return $null } }
  $leaf = Split-Path -Leaf $folder
  if ($leaf -match $OnlineNoShareName -or $OnlineCats -contains $leaf -or -not (Test-Path -LiteralPath $folder -PathType Container)) { return $null }
  $kind = if ($OnlineCats -contains "$($g.cat)" -and $OnlineNoShareKinds -notcontains "$($g.cat)") { "$($g.cat)" } elseif ($OnlineCatKind.ContainsKey("$($g.cat)")) { $OnlineCatKind["$($g.cat)"] } else { 'Online' }
  @{ key = $id; title = $g.title; cat = $g.cat; kind = 'folder'; rel = "$kind\$leaf"; folder = $folder }
}
function Get-FolderSize([string]$f) { $s = [int64]0; $n = 0; foreach ($x in [IO.Directory]::EnumerateFiles($f, '*', 'AllDirectories')) { $s += (New-Object IO.FileInfo($x)).Length; $n++ }; @{ size = $s; files = $n } }
function Get-ShareableGames($cfg, [switch]$NoSize) {
  $cacheFile = Join-Path $cfg.data 'sizes.json'
  $cache = @{}; if (-not $NoSize -and (Test-Path -LiteralPath $cacheFile)) { try { (Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value } } catch { } }
  $out = @(); $newCache = @{}
  $xi = Get-ExtraGameIndex; $dr = @(Get-DriveGameRoots)
  foreach ($g in Get-MenuGames) {
    $s = Resolve-ShareableGame $g $xi $dr
    if (-not $s) { continue }
    if ($NoSize) { $out += $s; continue }
    $c = $cache[$s.folder]
    if ($s.kind -eq 'steam' -and $s.size -gt 0) { $sz = @{ size = [int64]$s.size; files = 0 } }      # Steam knows the size: no folder walk
    elseif ($c -and ([DateTime]::UtcNow - [DateTime]::Parse($c.at).ToUniversalTime()).TotalHours -lt 24) { $sz = @{ size = [int64]$c.size; files = [int]$c.files } }
    else { $sz = Get-FolderSize $s.folder; $c = $null }
    if ($s.kind -ne 'steam') { $newCache[$s.folder] = @{ size = $sz.size; files = $sz.files; at = $(if ($c) { $c.at } else { [DateTime]::UtcNow.ToString('o') }) } }
    $s.size = $sz.size; $s.files = $sz.files
    $out += $s
  }
  if (-not $NoSize) { try { [IO.File]::WriteAllText($cacheFile, (ConvertTo-Json -InputObject $newCache -Depth 4)) } catch { } }
  $out          # one game per pipeline item (callers wrap in @())
}

function Publish-Branch {
  $cfg = Get-OnlineConfig
  if (-not $cfg.enabled) { return @{ ok = $false; error = 'online library not set up (Settings OnlineHub + System\Data\Online\online.key)' } }
  Initialize-OnlineData $cfg
  $games = @(Get-ShareableGames $cfg | ForEach-Object { [ordered]@{ key = $_.key; title = $_.title; cat = $_.cat; kind = $_.kind; rel = $_.rel; size = $_.size; files = $_.files } })
  $r = Invoke-Hub $cfg 'POST' '/api/report' ([ordered]@{ branch = $cfg.branch; name = $cfg.name; games = $games })
  Set-Content -LiteralPath (Join-Path $cfg.data 'published.txt') -Value ([DateTime]::UtcNow.ToString('o')) -Encoding ASCII
  @{ ok = [bool]$r.ok; games = $games.Count }
}

# ---------- what other branches have ----------
function Get-OnlineView {
  $cfg = Get-OnlineConfig
  $view = [ordered]@{ ok = $true; enabled = $cfg.enabled; hub = $cfg.hub; branch = $cfg.branch; name = $cfg.name; engine = $cfg.engine; missing = @(); branches = @(); jobs = @()
    net = [ordered]@{ upnp = $cfg.upnp; btPort = $cfg.btPort; externalIP = (Get-Aria2ExternalIP $cfg); mappings = (Get-UpnpState) } }
  if (-not $cfg.enabled) { $view.error = 'not set up: Settings OnlineHub + System\Data\Online\online.key'; return $view }
  Initialize-OnlineData $cfg
  try { Update-PullJobs $cfg | Out-Null } catch { }
  $view.jobs = @(Get-PullJobs)
  try { $cat = Invoke-Hub $cfg 'GET' '/api/catalog' $null 8 } catch { $view.ok = $false; $view.error = "$($_.Exception.Message)"; return $view }
  # games this branch has: same key, or (folder games) a folder of the same name - another shop may give a game another id
  $mine = @{}; $mineLeaf = @{}
  foreach ($g in Get-MenuGames) { $mine[[string]$g.id] = 1 }
  foreach ($s in @(Get-ShareableGames $cfg -NoSize)) { if ($s.kind -ne 'steam') { $mineLeaf[(Split-Path -Leaf $s.folder).ToLower()] = 1 } }
  $pulling = @{}; foreach ($j in $view.jobs) { if ($j.state -ne 'failed') { $pulling[$j.key] = $j.state } }
  $miss = [ordered]@{}
  foreach ($b in @($cat.branches)) {
    $view.branches += [ordered]@{ branch = $b.branch; name = $b.name; lastSeen = $b.lastSeen; games = @($b.games).Count; me = ($b.branch -eq $cfg.branch) }
    if ($b.branch -eq $cfg.branch) { continue }
    foreach ($g in @($b.games)) {
      if ($mine[$g.key]) { continue }
      if ($g.kind -ne 'steam' -and $mineLeaf[(@("$($g.rel)" -split '\\')[-1]).ToLower()]) { continue }
      if (-not $miss.Contains($g.key)) { $miss[$g.key] = [ordered]@{ key = $g.key; title = $g.title; cat = $g.cat; kind = $g.kind; size = [int64]$g.size; sizeGB = [math]::Round($g.size / 1GB, 2); branches = @(); pulling = $pulling[$g.key] } }
      $miss[$g.key].branches += $b.name
    }
  }
  $view.missing = @($miss.Values)
  $view
}

# ---------- pull jobs ----------
function Get-JobFile($cfg) { Join-Path $cfg.data 'jobs.json' }
function Get-PullJobs { $cfg = Get-OnlineConfig; $f = Get-JobFile $cfg; if (-not (Test-Path -LiteralPath $f)) { return @() }; $x = [IO.File]::ReadAllText($f) | ConvertFrom-Json; @($x) }
function Save-PullJobs($cfg, $jobs) { [IO.File]::WriteAllText((Get-JobFile $cfg), (ConvertTo-Json -InputObject @($jobs) -Depth 6)) }
function Get-FreeBytes([string]$path) { try { [IO.DriveInfo]::new((Split-Path -Qualifier $path)).AvailableFreeSpace } catch { [int64]0 } }
function Get-PullDestination($cfg, $g) {
  if ($g.kind -eq 'hoyoplay') { return (Join-Path (Join-Path (Get-LauncherDir 'HoYoPlay') 'games') $g.rel) }
  if ($g.kind -eq 'steam') {
    # the Steam library (on a shared drive) with the most free space
    $lib = @(Get-SteamLibraries) | Sort-Object { -(Get-FreeBytes $_) } | Select-Object -First 1
    if (-not $lib) { throw 'no Steam library on this master' }
    return (Join-Path $lib $g.rel)
  }
  # folder game: the game folders (GAME\<kind>\..) and the shared drives laid out as X:\<kind>\.. - the one with the most free space
  $c = @(@(Get-GameFolders | ForEach-Object { @{ root = $_; drive = $false } }) + @(Get-DriveGameRoots | ForEach-Object { @{ root = $_; drive = $true } }))
  if (-not $c.Count) { throw 'no game folder on this master' }
  $best = $c | Sort-Object { -(Get-FreeBytes $_.root) } | Select-Object -First 1
  $rel = "$($g.rel)"
  if ($best.drive) {
    # top of a game drive: never a loose game folder there, and no new top-level kind folder when a similar one exists
    $parts = @($rel -split '\\')
    if ($OnlineCats -notcontains $parts[0]) { $parts = @('Online') + $parts }
    if (-not (Test-Path -LiteralPath (Join-Path $best.root $parts[0]))) {
      $alt = @{ 'Gacha' = 'Mobile', 'Online'; 'HoYoPlay' = 'Mobile', 'Online'; 'PvP' = 'Online'; 'Offline' = 'Single Player', 'Online'; 'Garena' = 'Online'; 'Mobile' = 'Online'; 'Emulator' = 'Online' }[$parts[0]]
      $use = @($alt | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $best.root $_)) })[0]
      if ($use) { $parts[0] = $use }
    }
    $rel = $parts -join '\'
  }
  Join-Path $best.root $rel
}
function Start-Pull([string]$Key) {
  $cfg = Get-OnlineConfig
  if (-not $cfg.enabled) { return @{ ok = $false; error = 'online library not set up' } }
  if ($cfg.engine -eq 'none') { return @{ ok = $false; error = 'no BitTorrent engine (Tools\aria2\aria2c.exe)' } }
  Initialize-OnlineData $cfg
  if (@(Get-PullJobs | Where-Object { $_.key -eq $Key -and $_.state -notin 'failed', 'done' }).Count) { return @{ ok = $false; error = 'already being installed' } }
  $cat = Invoke-Hub $cfg 'GET' '/api/catalog'
  $src = @($cat.branches | Where-Object { $_.branch -ne $cfg.branch -and @($_.games | Where-Object { $_.key -eq $Key }).Count } | Sort-Object { $_.lastSeen } -Descending) | Select-Object -First 1
  if (-not $src) { return @{ ok = $false; error = "no other branch has $Key" } }
  $g = @($src.games | Where-Object { $_.key -eq $Key })[0]
  $dest = Get-PullDestination $cfg $g
  if ((Test-Path -LiteralPath $dest) -and @(Get-ChildItem -LiteralPath $dest -Force -ErrorAction SilentlyContinue).Count) { return @{ ok = $false; error = "$dest is not empty" } }
  $free = Get-FreeBytes $dest
  $need = [int64]$g.size + [Math]::Max([int64]5GB, [int64]($g.size * 0.05))
  if ($free -lt $need) { return @{ ok = $false; error = ("not enough space on {0}: {1:N1} GB free, {2:N1} GB needed" -f (Split-Path -Qualifier $dest), ($free / 1GB), ($need / 1GB)) } }
  $r = Invoke-Hub $cfg 'POST' '/api/request' ([ordered]@{ branch = $cfg.branch; from = $src.branch; key = $Key })
  $job = [ordered]@{ id = ((Get-Date).ToString('yyyyMMddHHmmss') + '-' + ($Key -replace '[^A-Za-z0-9\-]', '')); key = $Key; title = $g.title; from = $src.branch; fromName = $src.name
    kind = $g.kind; rel = $g.rel; dest = $dest; size = [int64]$g.size; state = 'requested'; progress = 0; message = 'waiting for the other branch to share it'; gid = ''; infohash = ''; at = (Get-Date).ToString('o') }
  $jobs = @(Get-PullJobs) + [pscustomobject]$job
  Save-PullJobs $cfg $jobs
  Update-PullJobs $cfg | Out-Null
  @{ ok = $true; job = $job.id; dest = $dest; torrentReady = [bool]$r.torrentReady }
}
function Update-PullJobs($cfg) {
  if (-not $cfg) { $cfg = Get-OnlineConfig }
  $jobs = @(Get-PullJobs); $changed = $false; $finished = 0
  foreach ($j in $jobs) {
    if ($j.state -in 'done', 'failed') { continue }
    try {
      if ($j.state -eq 'requested') {
        $t = Invoke-Hub $cfg 'GET' ("/api/torrent?from=$([uri]::EscapeDataString($j.from))&key=$([uri]::EscapeDataString($j.key))")
        if ($t -and $t.ready) {
          # the seeder wrote ITS hub address into the torrent (127.0.0.1 on the hub's own PC): announce to OUR hub address
          $bytes = Set-TorrentAnnounce ([Convert]::FromBase64String($t.torrent)) "$($cfg.hub)/announce/$([uri]::EscapeDataString($cfg.key))" "$($t.infohash)"
          [IO.File]::WriteAllBytes((Join-Path $cfg.data "torrents\$($t.infohash).torrent"), $bytes)
          $j.infohash = $t.infohash
          if ($t.manifest) { [IO.File]::WriteAllText((Join-Path $cfg.data "torrents\$($t.infohash).acf"), [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t.manifest))) }
          $j.gid = Start-EngineDownload $cfg $j $bytes "$($t.source)"
          $j.state = 'downloading'; $j.message = "downloading from $($j.fromName)"; $changed = $true
        }
      } elseif ($j.state -eq 'downloading') {
        $p = Get-EngineProgress $cfg $j
        if ($p.progress -ne $j.progress) { $j.progress = $p.progress; $changed = $true }
        if ($p.error) { $j.state = 'failed'; $j.message = $p.error; $changed = $true }
        elseif ($p.done) {
          if ($j.kind -eq 'steam') { Complete-SteamPull $cfg $j }
          $j.state = 'done'; $j.progress = 100; $j.message = 'installed - in the menu after the game list update'; $changed = $true; $finished++
        }
      }
    } catch { $j.message = "$($_.Exception.Message)"; $changed = $true }
  }
  if ($changed) { Save-PullJobs $cfg $jobs }
  @{ finished = $finished }
}
function Complete-SteamPull($cfg, $j) {
  $acf = Join-Path $cfg.data "torrents\$($j.infohash).acf"
  if (-not (Test-Path -LiteralPath $acf)) { return }
  $steamapps = Split-Path -Parent (Split-Path -Parent $j.dest)          # <lib>\steamapps
  $appid = ($j.key -replace '^steam-', '')
  Copy-Item -LiteralPath $acf -Destination (Join-Path $steamapps "appmanifest_$appid.acf") -Force
}

# ---------- serving other branches ----------
function Invoke-ServeRequests($cfg) {
  $r = Invoke-Hub $cfg 'GET' ("/api/requests?branch=$([uri]::EscapeDataString($cfg.branch))")
  $served = 0
  $mine = $null
  foreach ($q in @($r.requests)) {
    if (-not $mine) { $mine = @(Get-ShareableGames $cfg) }
    $g = $mine | Where-Object { $_.key -eq $q.key } | Select-Object -First 1
    if (-not $g) { continue }
    $t = New-GameTorrent -Folder $g.folder -Announce "$($cfg.hub)/announce/$([uri]::EscapeDataString($cfg.key))"
    [IO.File]::WriteAllBytes((Join-Path $cfg.data "torrents\$($t.InfoHash).torrent"), $t.Bytes)
    $body = [ordered]@{ from = $cfg.branch; key = $g.key; infohash = $t.InfoHash; torrent = [Convert]::ToBase64String($t.Bytes); size = $t.Size
      source = $(if ($cfg.engine -eq 'mock') { $g.folder } else { '' }) }
    if ($g.kind -eq 'steam' -and $g.manifest) { $body.manifest = [Convert]::ToBase64String([IO.File]::ReadAllBytes($g.manifest)) }
    Start-EngineSeed $cfg $g.folder $t.Bytes
    Invoke-Hub $cfg 'POST' '/api/torrent' $body | Out-Null
    $served++
  }
  $served
}
function Invoke-OnlineSync {
  $cfg = Get-OnlineConfig
  if (-not $cfg.enabled) { return @{ ok = $false; error = 'online library not set up' } }
  Initialize-OnlineData $cfg
  $pubFile = Join-Path $cfg.data 'published.txt'
  $pub = $null
  if (-not (Test-Path -LiteralPath $pubFile) -or (Get-Item -LiteralPath $pubFile).LastWriteTime -lt (Get-Date).AddMinutes(-30)) { $pub = Publish-Branch }
  $served = Invoke-ServeRequests $cfg
  $u = Update-PullJobs $cfg
  $net = Update-Aria2Network $cfg
  @{ ok = $true; published = $pub; served = $served; finished = $u.finished; net = $net }
}

# ---------- engines ----------
function Start-EngineDownload($cfg, $job, [byte[]]$torrent, [string]$source) {
  $parent = Split-Path -Parent $job.dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if ($cfg.engine -eq 'mock') {
    $jf = Join-Path $cfg.data "jobs\$($job.id).json"
    [IO.File]::WriteAllText($jf, (ConvertTo-Json -InputObject ([ordered]@{ torrent = (Join-Path $cfg.data "torrents\$($job.infohash).torrent"); source = $source; dest = $job.dest; progress = 0; state = 'running'; error = '' }) -Depth 4))
    $env:OSYNC_ONLINEDATA = $cfg.data
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $PSScriptRoot 'Online-Library.ps1') + '"'), '-MockWorker', $job.id) | Out-Null
    return "mock-$($job.id)"
  }
  if ($cfg.engine -eq 'aria2') {
    Initialize-Aria2 $cfg
    return (Invoke-Aria2 $cfg 'aria2.addTorrent' @([Convert]::ToBase64String($torrent), @(), @{ dir = $parent; 'seed-ratio' = '0.0' }))
  }
  throw "engine $($cfg.engine) cannot download"
}
function Get-EngineProgress($cfg, $job) {
  if ($cfg.engine -eq 'mock') {
    $jf = Join-Path $cfg.data "jobs\$($job.id).json"
    $s = [IO.File]::ReadAllText($jf) | ConvertFrom-Json
    return @{ progress = [int]$s.progress; done = ($s.state -eq 'done'); error = $(if ($s.state -eq 'failed') { $s.error } else { '' }) }
  }
  $st = Invoke-Aria2 $cfg 'aria2.tellStatus' @($job.gid, @('status', 'totalLength', 'completedLength', 'errorMessage'))
  $tot = [int64]$st.totalLength; $got = [int64]$st.completedLength
  $pct = if ($tot -gt 0) { [int](100 * $got / $tot) } else { 0 }
  @{ progress = $pct; done = ($tot -gt 0 -and $got -eq $tot); error = $(if ($st.status -eq 'error') { "aria2: $($st.errorMessage)" } else { '' }) }
}
function Start-EngineSeed($cfg, [string]$folder, [byte[]]$torrent) {
  if ($cfg.engine -eq 'mock') { return }
  if ($cfg.engine -eq 'aria2') {
    Initialize-Aria2 $cfg
    Invoke-Aria2 $cfg 'aria2.addTorrent' @([Convert]::ToBase64String($torrent), @(), @{ dir = (Split-Path -Parent $folder); 'check-integrity' = 'true'; 'seed-ratio' = '0.0' }) | Out-Null
  }
}
# aria2: one per branch, JSON-RPC on 127.0.0.1:<OnlineRpcPort> with a secret, BitTorrent on <OnlineBtPort>, no DHT / LPD /
# peer exchange (private torrents, the hub is the only tracker); its session file keeps downloads + seeds over restarts
function Get-Aria2Secret($cfg) {
  $f = Join-Path $cfg.data 'aria2.secret'
  if (-not (Test-Path -LiteralPath $f)) { $b = New-Object byte[] 18; ([Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($b); Set-Content -LiteralPath $f -Value ([Convert]::ToBase64String($b) -replace '[^A-Za-z0-9]', 'x') -Encoding ASCII }
  "$(Get-Content -LiteralPath $f -Raw)".Trim()
}
function Invoke-Aria2($cfg, [string]$method, [object[]]$params, [int]$TimeoutSec = 20) {
  $body = ConvertTo-Json -InputObject ([ordered]@{ jsonrpc = '2.0'; id = 'osync'; method = $method; params = @("token:$(Get-Aria2Secret $cfg)") + $params }) -Depth 6 -Compress
  $r = Invoke-RestMethod -Uri "http://127.0.0.1:$($cfg.rpcPort)/jsonrpc" -Method POST -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json' -TimeoutSec $TimeoutSec -UseBasicParsing
  if ($r.error) { throw "aria2 $method : $($r.error.message)" }
  $r.result
}
function Test-Aria2($cfg) { try { Invoke-Aria2 $cfg 'aria2.getVersion' @() 3 | Out-Null; $true } catch { $false } }
# the local IP aria2 uses: Settings OnlineBind, or (UPnP on) the IP the router maps to = the NIC with the internet route
function Get-Aria2BindIP($cfg) { if ($cfg.bind) { return $cfg.bind }; if ($cfg.upnp) { return (Get-UpnpLocalIP) }; '' }
# the public IP the tracker should give other branches for this PC: OnlineExternalIP (an IP or a DDNS name), else the
# router's public IP over UPnP (only a real public address - not private / CGNAT)
function Get-OnlineExternalIP($cfg) {
  $x = "$($cfg.externalIP)".Trim()
  if ($x -match '^\d{1,3}(\.\d{1,3}){3}$') { return $x }
  if ($x) { try { $a = @([Net.Dns]::GetHostAddresses($x) | Where-Object { $_.AddressFamily -eq 'InterNetwork' })[0]; if ($a) { return $a.ToString() } } catch { }; return '' }
  if ($cfg.upnp) { try { $e = Get-UpnpExternalIP (Find-UpnpIgd (Get-Aria2BindIP $cfg)); if ($e -and (-not (Test-PrivateIPv4 $e) -or $env:OSYNC_UPNP_LOCATION)) { return $e } } catch { } }
  ''
}
function Get-Aria2ExternalIP($cfg) { $f = Join-Path $cfg.data 'aria2.extip'; if (Test-Path -LiteralPath $f) { "$(Get-Content -LiteralPath $f -Raw)".Trim() } else { '' } }
function Initialize-Aria2($cfg) {
  if (Test-Aria2 $cfg) { return }
  if (-not (Test-Path -LiteralPath $cfg.aria2)) { throw "aria2 not found: $($cfg.aria2)" }
  $session = Join-Path $cfg.data 'aria2.session'
  if (-not (Test-Path -LiteralPath $session)) { New-Item -ItemType File -Path $session | Out-Null }
  $a2 = @('--enable-rpc=true', '--rpc-listen-all=false', "--rpc-listen-port=$($cfg.rpcPort)", "--rpc-secret=$(Get-Aria2Secret $cfg)",
    "--listen-port=$($cfg.btPort)", '--enable-dht=false', '--enable-dht6=false', '--bt-enable-lpd=false', '--enable-peer-exchange=false',
    '--seed-ratio=0.0', '--file-allocation=none', '--bt-detach-seed-only=true', '--max-concurrent-downloads=3', '--auto-file-renaming=false',
    "--input-file=$session", "--save-session=$session", '--save-session-interval=60', "--log=$(Join-Path $cfg.data 'aria2.log')", '--log-level=notice',
    "--max-overall-download-limit=$($cfg.maxDownKB)K", "--max-overall-upload-limit=$($cfg.maxUpKB)K")
  $bind = Get-Aria2BindIP $cfg
  if ($bind) { $a2 += "--interface=$bind" }   # Settings OnlineBind / the UPnP NIC (the simulation uses 127.0.0.1: no firewall prompt)
  $ext = Get-OnlineExternalIP $cfg
  if ($ext) { $a2 += "--bt-external-ip=$ext" }   # sent to the tracker as ip=: the address other branches connect to
  Set-Content -LiteralPath (Join-Path $cfg.data 'aria2.extip') -Value $ext -Encoding ASCII
  Start-Process -FilePath $cfg.aria2 -ArgumentList $a2 -WindowStyle Hidden | Out-Null
  $up = $false
  for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 300; if (Test-Aria2 $cfg) { $up = $true; break } }
  if (-not $up) { throw 'aria2 did not start' }
  Write-OnlineLog $cfg "aria2 started (bind $(if ($bind) { $bind } else { 'any' }), port $($cfg.btPort), external IP $(if ($ext) { $ext } else { 'not known' }))"
  if ($cfg.upnp) { try { $m = Add-UpnpMapping $cfg.btPort "OSYNC aria2 $($cfg.branch)" 3600 'TCP' (Find-UpnpIgd $bind); Write-OnlineLog $cfg "UPnP: $($m.ExternalIP):$($cfg.btPort) -> $($m.LocalIP):$($cfg.btPort)" } catch { Write-OnlineLog $cfg "UPnP mapping failed: $($_.Exception.Message)" } }
}
# every sync: aria2 runs while it has work (restarted after a reboot when its session has downloads / seeds), the UPnP
# mapping is renewed while it runs and removed when it does not, a changed public IP goes to aria2 (and so to the tracker)
function Update-Aria2Network($cfg) {
  if ($cfg.engine -ne 'aria2') { return "engine $($cfg.engine)" }
  $session = Join-Path $cfg.data 'aria2.session'
  $running = Test-Aria2 $cfg
  if (-not $running -and (Test-Path -LiteralPath $session) -and "$(Get-Content -LiteralPath $session -Raw)".Trim()) {
    try { Initialize-Aria2 $cfg; $running = $true } catch { return "aria2 restart failed: $($_.Exception.Message)" }
  }
  $mapKey = "$($cfg.btPort)/TCP"
  if (-not $running) {
    if ((Get-UpnpState).PSObject.Properties.Name -contains $mapKey) { try { return "aria2 not running, UPnP: $(Remove-UpnpMapping $cfg.btPort 'TCP' (Find-UpnpIgd (Get-Aria2BindIP $cfg)))" } catch { return "UPnP remove failed: $($_.Exception.Message)" } }
    return 'aria2 not running (no work)'
  }
  $msg = @('aria2 running')
  if ($cfg.upnp) { try { $m = Add-UpnpMapping $cfg.btPort "OSYNC aria2 $($cfg.branch)" 3600 'TCP' (Find-UpnpIgd (Get-Aria2BindIP $cfg)); $msg += "UPnP $($m.ExternalIP):$($cfg.btPort)" } catch { $msg += "UPnP failed: $($_.Exception.Message)" } }
  $ext = Get-OnlineExternalIP $cfg; $was = Get-Aria2ExternalIP $cfg
  if ($ext -and $ext -ne $was) {
    try { Invoke-Aria2 $cfg 'aria2.changeGlobalOption' @(@{ 'bt-external-ip' = $ext }) | Out-Null; Set-Content -LiteralPath (Join-Path $cfg.data 'aria2.extip') -Value $ext -Encoding ASCII; $msg += "external IP $was -> $ext"; Write-OnlineLog $cfg "external IP $was -> $ext" }
    catch { $msg += "external IP change failed: $($_.Exception.Message)" }
  }
  $msg -join ', '
}
function Stop-OnlineEngine {
  $cfg = Get-OnlineConfig
  $out = @()
  if ($cfg.engine -eq 'aria2' -and (Test-Aria2 $cfg)) { try { Invoke-Aria2 $cfg 'aria2.shutdown' @() | Out-Null; $out += 'aria2 stopped' } catch { $out += "aria2: $($_.Exception.Message)" } } else { $out += 'aria2 not running' }
  if ((Get-UpnpState).PSObject.Properties.Name -contains "$($cfg.btPort)/TCP") { try { $out += "UPnP: $(Remove-UpnpMapping $cfg.btPort 'TCP' (Find-UpnpIgd (Get-Aria2BindIP $cfg)))" } catch { $out += "UPnP: $($_.Exception.Message)" } }
  Write-OnlineLog $cfg ($out -join ', ')
  @{ ok = $true; result = ($out -join ', ') }
}

# mock engine worker: copy from the seeder's folder (same PC) and check every piece against the .torrent
function Invoke-MockWorker([string]$id) {
  $cfg = Get-OnlineConfig
  $jf = Join-Path $cfg.data "jobs\$id.json"
  $s = [IO.File]::ReadAllText($jf) | ConvertFrom-Json
  $save = { param($state, $pct, $err) $s.state = $state; $s.progress = $pct; $s.error = $err; [IO.File]::WriteAllText($jf, (ConvertTo-Json -InputObject $s -Depth 4)) }
  try {
    $tb = [IO.File]::ReadAllBytes($s.torrent)
    $t = ConvertFrom-Bencode $tb
    if (-not $s.source -or -not (Test-Path -LiteralPath $s.source)) { throw "mock: seeder folder not reachable ($($s.source))" }
    $files = @($t['info']['files']); $total = [int64]0; foreach ($f in $files) { $total += [int64]$f['length'] }
    $done = [int64]0
    foreach ($f in $files) {
      $rel = (@($f['path'] | ForEach-Object { Get-BStr $_ })) -join '\'
      $to = Join-Path $s.dest $rel
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
      Copy-Item -LiteralPath (Join-Path $s.source $rel) -Destination $to -Force
      $done += [int64]$f['length']
      & $save 'running' ([int](95 * $done / [Math]::Max(1, $total))) ''
    }
    $chk = Test-TorrentData $tb $s.dest
    if (-not $chk.ok) { throw "mock: data check failed ($($chk.bad) bad pieces, $($chk.missing.Count) missing files)" }
    & $save 'done' 100 ''
  } catch { & $save 'failed' 0 "$($_.Exception.Message)" }
}

if ($MyInvocation.InvocationName -ne '.') {
  if ($MockWorker) { Invoke-MockWorker $MockWorker; exit 0 }
  if ($Publish) { $r = Publish-Branch; ConvertTo-Json $r -Depth 4; exit $(if ($r.ok) { 0 } else { 1 }) }
  if ($Pull) { $r = Start-Pull $Pull; ConvertTo-Json $r -Depth 4; exit $(if ($r.ok) { 0 } else { 1 }) }
  if ($Sync) { $r = Invoke-OnlineSync; ConvertTo-Json $r -Depth 5; exit $(if ($r.ok) { 0 } else { 1 }) }
  if ($Stop) { $r = Stop-OnlineEngine; ConvertTo-Json $r -Depth 4; exit 0 }
  if ($List) {
    $cfg = Get-OnlineConfig; $all = @(Get-MenuGames); $sh = @(Get-ShareableGames $cfg -NoSize)
    $keys = @{}; foreach ($s in $sh) { $keys[$s.key] = 1 }
    $sh | Sort-Object { $_.kind }, { $_.rel } | ForEach-Object { '{0,-9} {1,-24} {2,-44} {3}' -f $_.kind, $_.key, $_.rel, $_.folder }
    "shareable: $($sh.Count) of $($all.Count) menu games"
    "not shared: $(@($all | Where-Object { -not $keys[[string]$_.id] } | ForEach-Object { $_.id }) -join ', ')"
    exit 0
  }
}
