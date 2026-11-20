# Console-Server.ps1 - MASTER: the OSYNC admin console, a local web page at http://localhost:4666 (this PC only).
#   Games  : every game of the menu (Menu\data\games.json) - rename, category, hide / show (Settings\extra-games.json),
#            change the card picture / logo (Menu\data\posters\<id>.png|jpg|webp, which the game list uses first)
#   Drives : every drive with what the game list really scans there: Steam libraries, X:\Online X:\Mobile ... (top-level or
#            X:\Games\<kind>), the game folders (Settings GamesFolder + GameFolders) and how many menu games start from it.
#            "Use for games" only on a shared, empty drive (never the Windows drive or a disk of the diskless program, never a
#            drive that already holds games) and only after "the client PCs are off" is confirmed: it creates the category
#            folders in the shop's own layout (top-level X:\Online ... when the other drives use that, else X:\GAME + GameFolders).
#            SharedDrives is never written here: share the drive in the diskless program and add it to SharedDrives first.
#   Online : the online library (Online-Library.ps1) - games other branches have and this one not, install one (BitTorrent)
#   Status : watcher, game list, update the menu list now
#   (18 Nov 2026) Overview: services, drives, FiveM shared server files, client PCs at a glance; Clients: each client PC's latest
#   status report (boot steps that failed, Sunshine, FiveM hand-over); Settings: settings.txt values with their Thai help, on/off
#   switches; Shop systems: Menu\config.json apiUrl / machineId / brandName / menuOnly / sidePanel + API test + docs (SHOP-API.md)
# Bound to 127.0.0.1 only; POST needs the header X-OSYNC (a web page elsewhere cannot send it); Host must be this PC.
# Clients see menu changes after their next reboot (diskless).
#   -Port 4666   -Register: start at logon (task OSYNC-Console, this user, hidden) + now   -Unregister: remove it
#   -AllowStop: POST /api/_stop ends the server (tests). Tests point it at copies with $env:OSYNC_SETTINGS / $env:OSYNC_MENU.
#   -TestRoot <folder>: game folders added under that folder skip the drive checks (tests on the Windows drive)
param([int]$Port = 0, [switch]$Register, [switch]$Unregister, [switch]$AllowStop, [string]$TestRoot = '')
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Http-Lib.ps1')
. (Join-Path $PSScriptRoot 'Online-Library.ps1')
if (-not $Port) { $Port = [int](Get-Setting 'ConsolePort' '4666') }
$TaskName = 'OSYNC-Console'
$WebDir = Join-Path $SystemDir 'Console'

if ($Register -or $Unregister) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  if ($Unregister) { Write-Host "task $TaskName removed"; exit 0 }
  $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '"')
  $t = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $TaskName -Action $a -Trigger $t -Settings $s -Description "OSYNC admin console http://localhost:$Port" -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Write-Host "task ${TaskName}: at logon -> http://localhost:$Port"
  exit 0
}

$PostersDir = Join-Path $Menu 'data\posters'
$GamesJson = Join-Path $Menu 'data\games.json'
$BaseCats = 'Online', 'Steam', 'Riot', 'Epic', 'EA', 'Rockstar', 'Ubisoft', 'Garena', 'HoYoPlay', 'Gacha', 'Mobile', 'Single Player', 'Emulator', 'Apps', 'Launchers'
$DriveCats = 'Online', 'Mobile', 'Single Player', 'Emulator', 'Garena', 'HoYoPlay', 'Gacha'
# folder names the game list scans on EVERY drive (X:\<kind>\<game> and X:\Games\<kind>\<game>) - Master-GameList $autoCats
$ScanKinds = 'Online', 'PvP', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'Garena', 'HoYoPlay', 'Gacha'

# ---------- files ----------
function Read-JsonFile([string]$f) { if (-not (Test-Path -LiteralPath $f)) { return $null }; $x = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8).Trim([char]0xFEFF) | ConvertFrom-Json; $x }
function Write-TextFile([string]$f, [string]$text) {
  $bom = $false
  if (Test-Path -LiteralPath $f) { $b = [IO.File]::ReadAllBytes($f); $bom = $b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF }
  $tmp = "$f.tmp"
  [IO.File]::WriteAllText($tmp, (($text -replace "`r`n", "`n") -replace "`n", "`r`n"), (New-Object Text.UTF8Encoding($bom)))
  Move-Item -LiteralPath $tmp -Destination $f -Force
}
# settings.txt: change one Key=Value line (comments and the rest stay), add it at the end when missing
function Set-SettingLine([string]$Name, [string]$Value) {
  $lines = New-Object System.Collections.Generic.List[string]
  if (Test-Path -LiteralPath $SettingsFile) { foreach ($l in [IO.File]::ReadAllLines($SettingsFile, [Text.Encoding]::UTF8)) { $lines.Add($l) } }
  $done = $false
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$([regex]::Escape($Name))\s*=") { $lines[$i] = "$Name=$Value"; $done = $true; break } }
  if (-not $done) { $lines.Add("# $Name - set by the admin console (System\Scripts\Console-Server.ps1)"); $lines.Add("$Name=$Value") }
  Write-TextFile $SettingsFile (($lines -join "`r`n") + "`r`n")
}
function Invoke-GameList {
  $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir 'Master-GameList.ps1') 2>&1 | ForEach-Object { "$_" }
  @{ ok = ($LASTEXITCODE -eq 0); log = @($out | Select-Object -Last 12) }
}

# ---------- games ----------
# categories: the standard ones + every category the shop already uses (menu + extra-games.json, e.g. "Anime RPG")
function Get-Cats {
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($c in $BaseCats) { $list.Add($c) }
  $extra = Read-JsonFile $ExtraGamesFile
  $used = @(@(Read-JsonFile $GamesJson) | ForEach-Object { "$($_.cat)" }) + @(if ($extra -and $extra.games) { @($extra.games) | ForEach-Object { "$($_.cat)" } })
  foreach ($c in $used) { $c = $c.Trim(); if ($c -match '^[\p{L}\p{N}][\p{L}\p{N} &+''.\-]{0,39}$' -and -not $list.Contains($c)) { $list.Add($c) } }
  , $list.ToArray()
}
# extra-games.json per id: a game added by hand has an entry with "exe" (its own title / cat); a scanner game's changes - and
# hiding a hand-added game - are an entry without "exe" (Master-GameList applies those on top: title, cat, hide)
function Get-ExtraIndex {
  $idx = @{}
  $extra = Read-JsonFile $ExtraGamesFile
  foreach ($g in @(if ($extra -and $extra.games) { $extra.games })) {
    if (-not $g -or -not $g.id) { continue }
    $k = [string]$g.id
    if (-not $idx.ContainsKey($k)) { $idx[$k] = @{ added = $false; exeTitle = ''; exeCat = ''; ovTitle = ''; ovCat = ''; hide = $false; platform = '' } }
    $e = $idx[$k]
    if ($g.exe) { $e.added = $true; if ($g.title) { $e.exeTitle = "$($g.title)" }; if ($g.cat) { $e.exeCat = "$($g.cat)" } }
    else { if ($g.title) { $e.ovTitle = "$($g.title)" }; if ($g.cat) { $e.ovCat = "$($g.cat)" }; if ($g.hide) { $e.hide = $true } }
    if ($g.platform) { $e.platform = "$($g.platform)" }
  }
  $idx
}
function Get-ConsoleGames {
  $list = @(); $seen = @{}
  $idx = Get-ExtraIndex
  $custom = @{}; foreach ($f in @(Get-ChildItem -LiteralPath $PostersDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' })) { $custom[$f.BaseName] = $f.Name }
  foreach ($g in @(Read-JsonFile $GamesJson)) {
    if (-not $g -or -not $g.id) { continue }
    $o = $idx[[string]$g.id]; $seen[[string]$g.id] = 1
    $list += [ordered]@{ id = $g.id; title = $g.title; cat = $g.cat; platform = $g.platform; img = $g.img; hidden = $false
      renamed = [bool]($o -and $o.ovTitle); recat = [bool]($o -and $o.ovCat); added = [bool]($o -and $o.added); customIcon = [bool]$custom[[string]$g.id] }
  }
  foreach ($id in $idx.Keys) {
    $o = $idx[$id]
    if ($seen[$id] -or -not $o.hide) { continue }
    $t = if ($o.ovTitle) { $o.ovTitle } elseif ($o.exeTitle) { $o.exeTitle } else { $id }
    $c = if ($o.ovCat) { $o.ovCat } else { $o.exeCat }
    $list += [ordered]@{ id = $id; title = $t; cat = $c; platform = $o.platform; img = ''; hidden = $true; renamed = [bool]$o.ovTitle; recat = [bool]$o.ovCat; added = $o.added; customIcon = [bool]$custom[$id] }
  }
  , $list
}
# set a property in place (keeps the order of a hand-written entry), add it when missing
function Set-Prop($o, [string]$k, $v) { if ($o.PSObject.Properties.Name -contains $k) { $o.$k = $v } else { $o | Add-Member -NotePropertyName $k -NotePropertyValue $v } }
function Set-GameOverride([string]$id, $body) {
  if ($id -notmatch '^[A-Za-z0-9._\-]{1,80}$') { throw "bad game id" }
  $cats = Get-Cats
  $extra = Read-JsonFile $ExtraGamesFile
  if (-not $extra) { $extra = [pscustomobject]@{ games = @() } }
  $games = New-Object System.Collections.Generic.List[object]
  if ($extra.games) { foreach ($g in @($extra.games)) { $games.Add($g) } }
  $has = $body.PSObject.Properties.Name
  $exeE = $games | Where-Object { [string]$_.id -eq $id -and $_.exe } | Select-Object -First 1
  $ovE = $games | Where-Object { [string]$_.id -eq $id -and -not $_.exe } | Select-Object -First 1
  foreach ($k in 'title', 'cat') {
    if ($has -notcontains $k) { continue }
    $v = "$($body.$k)".Trim()
    if ($k -eq 'cat' -and $v -and $cats -notcontains $v) { throw "bad category $v" }
    if ($exeE) {
      # added by hand: its name and category are part of its own entry - changed, never emptied (empty = keep)
      if ($v) { Set-Prop $exeE $k $v }
      if ($ovE -and $ovE.PSObject.Properties.Name -contains $k) { $ovE.PSObject.Properties.Remove($k) }   # the entry's value wins again
    } else {
      if (-not $ovE) { $ovE = [pscustomobject]@{ id = $id }; $games.Add($ovE) }
      if ($v) { Set-Prop $ovE $k $v } else { $ovE.PSObject.Properties.Remove($k) }
    }
  }
  if ($has -contains 'hide') {
    # the game list skips a hidden id only through an entry WITHOUT "exe" - for a hand-added game that is a second entry
    if ($body.hide) { if (-not $ovE) { $ovE = [pscustomobject]@{ id = $id }; $games.Add($ovE) }; Set-Prop $ovE 'hide' $true }
    elseif ($ovE) { $ovE.PSObject.Properties.Remove('hide') }
  }
  # an entry left with only its id does nothing: drop it
  $keep = @($games | Where-Object { @($_.PSObject.Properties.Name | Where-Object { $_ -ne 'id' }).Count -gt 0 })
  if ($extra.PSObject.Properties.Name -contains 'games') { $extra.games = $keep } else { $extra | Add-Member -NotePropertyName games -NotePropertyValue $keep }
  Write-TextFile $ExtraGamesFile (ConvertTo-Json -InputObject $extra -Depth 10)
}
function Set-GameIcon([string]$id, [string]$b64) {
  if ($id -notmatch '^[A-Za-z0-9._\-]{1,80}$') { throw "bad game id" }
  $bytes = [Convert]::FromBase64String(($b64 -replace '^data:[^,]*,', ''))
  if ($bytes.Length -lt 32 -or $bytes.Length -gt 8MB) { throw 'picture must be 32 bytes - 8 MB' }
  $ext = if ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) { '.png' }
         elseif ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8 -and $bytes[2] -eq 0xFF) { '.jpg' }
         elseif ([Text.Encoding]::ASCII.GetString($bytes, 0, 4) -eq 'RIFF' -and [Text.Encoding]::ASCII.GetString($bytes, 8, 4) -eq 'WEBP') { '.webp' }
         else { throw 'only PNG, JPG or WEBP pictures' }
  New-Item -ItemType Directory -Force -Path $PostersDir | Out-Null
  Remove-GameIcon $id
  [IO.File]::WriteAllBytes((Join-Path $PostersDir "$id$ext"), $bytes)
  "$id$ext"
}
function Remove-GameIcon([string]$id) {
  foreach ($e in '.png', '.jpg', '.jpeg', '.webp') { $f = Join-Path $PostersDir "$id$e"; if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
}
# a picture the menu itself shows (games.json "img" = /poster/<path>, e.g. zPoster.jpg in a game folder on any game drive)
$script:MenuImgs = $null; $script:MenuImgsAt = [int64]0
function Test-MenuImage([string]$f) {
  $gj = Get-Item -LiteralPath $GamesJson -ErrorAction SilentlyContinue
  if (-not $gj) { return $false }
  if ($script:MenuImgsAt -ne $gj.LastWriteTimeUtc.Ticks) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($g in @(Read-JsonFile $GamesJson)) { $i = "$($g.img)"; if ($i.StartsWith('/poster/')) { [void]$set.Add([uri]::UnescapeDataString(($i.Substring(8) -split '\?')[0])) } }
    $script:MenuImgs = $set; $script:MenuImgsAt = $gj.LastWriteTimeUtc.Ticks
  }
  $script:MenuImgs.Contains($f)
}

# ---------- drives ----------
# a disk of the diskless program (LW: kimage\ = images, kwrite\ = client write-back; other brands: images / cache) - never a
# game drive, the console does not touch it
function Test-DisklessDisk([string]$letter) {
  $r = "${letter}:\"
  if (@('kimage', 'kwrite', 'kcache', 'lwimage', 'lwwrite', 'WriteBack', 'Writeback') | Where-Object { Test-Path -LiteralPath (Join-Path $r $_) }) { return $true }
  if (@(Get-ChildItem -LiteralPath $r -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(vhdx?|vmdk|img)$' }).Count) { return $true }
  $false
}
function Get-ConsoleDrives {
  $folders = @(Get-GameFolders)
  $shared = Get-SharedDrives
  $libs = @(Get-SteamLibraries)
  $steamAt = @{}; $libGames = @{}
  foreach ($l in $libs) {
    $n = 0
    foreach ($m in Get-ChildItem -LiteralPath (Join-Path $l 'steamapps') -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) { $steamAt[($m.BaseName -replace '^appmanifest_', '')] = $l; $n++ }
    $libGames[$l] = $n
  }
  # menu games per drive: where each one starts (its exe, or the Steam library that holds it)
  $perDrive = @{}
  foreach ($g in @(Read-JsonFile $GamesJson)) {
    $d = ''
    if ("$($g.id)" -match '^steam-(\d+)$' -and $steamAt[$Matches[1]]) { $d = $steamAt[$Matches[1]].Substring(0, 1) }
    else { $m = [regex]::Match("$($g.cmd)", '^\s*"?([A-Za-z]):\\'); if ($m.Success) { $d = $m.Groups[1].Value } }
    if ($d) { $d = $d.ToUpper(); $perDrive[$d] = 1 + [int]$perDrive[$d] }
  }
  $sys = $env:SystemDrive.Substring(0, 1).ToUpper()
  $drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | ForEach-Object {
      $l = $_.DeviceID.Substring(0, 1).ToUpper()
      $kindDirs = @(foreach ($k in $ScanKinds) { foreach ($p in "${l}:\$k", "${l}:\Games\$k") { if (Test-Path -LiteralPath $p -PathType Container) { $p } } })
      $steam = @($libs | Where-Object { $_.Substring(0, 1) -ieq $l } | ForEach-Object { [ordered]@{ path = $_; games = [int]$libGames[$_] } })
      $gf = @($folders | Where-Object { $_.Substring(0, 1) -ieq $l })
      $isSys = ($l -eq $sys); $dl = Test-DisklessDisk $l; $sh = ($shared.IndexOf($l) -ge 0)
      $has = [bool]($kindDirs.Count -or $steam.Count -or $gf.Count -or $perDrive[$l])
      $why = if ($isSys) { 'system' } elseif ($dl) { 'diskless' } elseif ($has) { 'hasGames' } elseif (-not $sh) { 'notShared' } else { '' }
      [ordered]@{ letter = $l; label = "$($_.VolumeName)"; sizeGB = [math]::Round($_.Size / 1GB); freeGB = [math]::Round($_.FreeSpace / 1GB)
        system = $isSys; diskless = $dl; shared = $sh; gameFolders = $gf; kindDirs = $kindDirs; steam = $steam; menuGames = [int]$perDrive[$l]
        hasGames = $has; canAdd = (-not $why); why = $why } })
  # the shop's layout: games in top-level X:\Online, X:\Mobile ... (scanned on every drive, nothing to list) or in X:\GAME
  $top = @($drives | Where-Object { $_.shared -and @($_.kindDirs | Where-Object { $_ -notmatch '^[A-Za-z]:\\Games\\' }).Count }).Count
  $style = if ($top -and -not (Get-Setting 'GameFolders' '')) { 'top' } else { 'game' }
  [ordered]@{ main = $GamesRoot; mainExists = (Test-Path -LiteralPath $GamesRoot); folders = $folders; sharedDrives = $shared; drives = $drives
    setting = (Get-Setting 'GameFolders' ''); style = $style; kinds = $ScanKinds; newKinds = $DriveCats }
}
function Add-GameDrive($body) {
  $path = if ($body.path) { "$($body.path)".TrimEnd('\') } elseif ($body.letter -match '^[A-Za-z]$') { '' } else { throw 'letter or path needed' }
  $q = if ($path) { if (-not [IO.Path]::IsPathRooted($path)) { throw 'full path needed' }; (Split-Path -Qualifier $path).Substring(0, 1).ToUpper() } else { "$($body.letter)".ToUpper() }
  if (-not (Test-Path -LiteralPath "${q}:\")) { throw "no drive ${q}: on this PC" }
  $test = $TestRoot -and $path -and $path.StartsWith($TestRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
  $info = Get-ConsoleDrives
  if (-not $test) {
    $d = @($info.drives | Where-Object { $_.letter -eq $q })[0]
    if (-not $d) { throw "drive ${q}: is not a fixed disk" }
    switch ($d.why) {
      'system'    { throw "drive ${q}: is the Windows drive - the client PCs do not see it" }
      'diskless'  { throw "drive ${q}: belongs to the diskless program (image / write-back) - not used for games" }
      'hasGames'  { throw "drive ${q}: already holds games ($(@(@($d.steam | ForEach-Object { $_.path }) + $d.kindDirs + $d.gameFolders) -join ', ')) - it is scanned already: put new games into its Online / Mobile ... folders" }
      'notShared' { throw "drive ${q}: is not shared to the client PCs (Settings SharedDrives=$($info.sharedDrives)): share it in the diskless program, add $q to SharedDrives, then try again" }
    }
    # writing to a game drive the client PCs have open can leave them reading garbage until they reboot
    if (-not $body.clientsOff) { throw 'confirm first that every client PC is off (shop closed): a drive the clients use must not change under them' }
  }
  if (@(Get-GameFolders) | Where-Object { $_ -ieq $path -or ($path -eq '' -and $_ -ieq "${q}:\GAME") }) { throw "$(if ($path) { $path } else { "${q}:\GAME" }) is a game folder already" }
  $notes = @()
  if (-not $path -and $info.style -eq 'top') {
    # this shop's layout: X:\Online, X:\Mobile ... at the top of the drive - the game list scans those on every drive by itself
    foreach ($c in $DriveCats) { New-Item -ItemType Directory -Force -Path "${q}:\$c" | Out-Null }
    $path = "${q}:\"
    $notes += "made ${q}:\$($DriveCats -join " ${q}:\") - the game list scans them on every drive (no setting needed)"
  } else {
    if (-not $path) { $path = "${q}:\GAME" }
    foreach ($c in $DriveCats) { New-Item -ItemType Directory -Force -Path (Join-Path $path $c) | Out-Null }
    $cur = @((Get-Setting 'GameFolders' '') -split '[;,|]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Set-SettingLine 'GameFolders' ((@($cur) + $path) -join ';')
    $notes += "GameFolders: +$path"
  }
  $notes += "client PCs see games there after their next reboot"
  @{ path = $path; notes = $notes }
}
function Remove-GameDrive([string]$path) {
  $cur = @((Get-Setting 'GameFolders' '') -split '[;,|]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $left = @($cur | Where-Object { $_.TrimEnd('\') -ine $path.TrimEnd('\') })
  if ($left.Count -eq $cur.Count) { throw "$path is not in GameFolders (the main game folder cannot be removed here)" }
  Set-SettingLine 'GameFolders' ($left -join ';')
}

# ---------- status ----------
# fast (no process list - that took 2-5 s): the watcher holds the mutex Local\OSYNC-Master-Watch while it runs; which
# OSYNC folder it runs from is in its log ("watcher started from <folder> by ...")
function Get-ConsoleStatus {
  $gj = Get-Item -LiteralPath $GamesJson -ErrorAction SilentlyContinue
  $wlog = 'C:\Users\Public\OSYNC-Master-Watch.log'
  $m = $null; $watch = [Threading.Mutex]::TryOpenExisting('Local\OSYNC-Master-Watch', [ref]$m); if ($m) { $m.Dispose() }
  $from = ''
  if (Test-Path -LiteralPath $wlog) { $hit = Select-String -LiteralPath $wlog -Pattern 'watcher started from (.+?) by ' -Encoding UTF8 | Select-Object -Last 1; if ($hit) { $from = $hit.Matches[0].Groups[1].Value } }
  $cfg = Get-OnlineConfig
  [ordered]@{ pc = $env:COMPUTERNAME; master = [bool](Test-IsMaster); root = $Root; menu = $Menu; settings = $SettingsDir
    games = @(Read-JsonFile $GamesJson).Count; gamesUpdated = $(if ($gj) { $gj.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } else { '' })
    watcher = [bool]$watch; watcherFrom = $from; watcherHere = [bool]($watch -and $from -and $from -ieq $Root)
    watcherLog = @(if (Test-Path -LiteralPath $wlog) { Get-Content -LiteralPath $wlog -Tail 15 -Encoding UTF8 | ForEach-Object { "$_" } })   # plain strings (Get-Content's carry PSProvider etc. - JSON would take minutes)
    online = [ordered]@{ hub = $cfg.hub; branch = $cfg.branch; engine = $cfg.engine; enabled = $cfg.enabled; upnp = $cfg.upnp } }
}

# ---------- overview / client PCs / settings / shop systems (18 Nov 2026: "easier to manage, in Thai") ----------
# client PCs' status reports (Client-OslinkReport.ps1): the report service's folder, else the first, temporary listener's
function Get-ReportDirs { @((Join-Path $env:ProgramData 'OSYNC\ClientReports'), (Join-Path $env:USERPROFILE 'OSYNC-StepB\oslink-reports')) | Where-Object { Test-Path -LiteralPath $_ } }
function Get-ReportFiles { @(foreach ($d in Get-ReportDirs) { Get-ChildItem -LiteralPath $d -Filter '*.txt' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+-[\d\-]+\.txt$' } }) }
function Read-ReportHead([string]$f) {
  $h = "$(Get-Content -LiteralPath $f -TotalCount 1 -Encoding UTF8)"
  $o = @{ pc = ''; phase = ''; now = ''; boot = '' }
  if ($h -match 'report\s+(\S+)\s+phase=(\S+)\s+now=(\S+ \S+)\s+boot=(\S+)') { $o.pc = $Matches[1]; $o.phase = $Matches[2]; $o.now = $Matches[3]; $o.boot = $Matches[4] }
  $o
}
function Get-ConsoleClients {
  $list = @()
  foreach ($g in (Get-ReportFiles | Group-Object { ($_.Name -split '-')[0] })) {
    $files = @($g.Group | Sort-Object LastWriteTime -Descending)
    $latest = $files[0]; $head = Read-ReportHead $latest.FullName
    $res = $null
    foreach ($f in ($files | Select-Object -First 8)) { if (Select-String -LiteralPath $f.FullName -Pattern '=+ RESULT =+' -Quiet) { $res = $f; break } }
    $fails = @(); $steps = 0; $sun = ''; $share = ''
    if ($res) {
      $lines = @(Get-Content -LiteralPath $res.FullName -Encoding UTF8)
      $i = [array]::FindLastIndex([string[]]$lines, [Predicate[string]]{ param($x) $x -match '=+ RESULT =+' })   # the last one = the full table (the OSLink section has a short one)
      for ($k = $i + 1; $k -lt $lines.Count; $k++) {
        $l = $lines[$k]; if ($l -match '^\*+|Windows PowerShell transcript|^=====') { break }
        if ($l -match '^\s*(\d+[a-z]?\s.+?)\s{2,}\d+ s\s+(.+)$') { $stepName = $Matches[1].Trim(); $stepRes = $Matches[2].Trim(); $steps++; if ($stepRes -like '*FAIL*') { $fails += "${stepName}: $stepRes" } }
      }
      $s0 = $lines | Where-Object { $_ -match 'service: SunshineService|own Sunshine|ClientSunshineAutoStart' } | Select-Object -First 1
      if ($s0) { $sun = $s0.Trim() }
    }
    $sh = Select-String -LiteralPath $latest.FullName -Pattern '(handed over|offer of|stale|FiveM is already running|start: cache)' -Encoding UTF8 | Select-Object -Last 1
    if ($sh) { $share = $sh.Line.Trim() }
    $list += [ordered]@{ ip = $g.Name; pc = $head.pc; lastSeen = $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); minutesAgo = [int]((Get-Date) - $latest.LastWriteTime).TotalMinutes
      boot = $head.boot; phase = $head.phase; reports = $files.Count; steps = $steps; fails = $fails; resultAt = $(if ($res) { $res.LastWriteTime.ToString('HH:mm') } else { '' }); sunshine = $sun; fivemShare = $share }
  }
  , @($list | Sort-Object { $_.pc })
}
function Get-ConsoleClientReport([string]$ip) {
  if ($ip -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'bad ip' }
  $f = Get-ReportFiles | Where-Object { $_.Name -like "$ip-*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { throw 'no report' }
  [ordered]@{ ok = $true; file = $f.Name; at = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'); text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) }
}
function Get-ConsoleOverview {
  $listen = @{}; foreach ($ep in [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) { $listen[[int]$ep.Port] = $true }   # (Get-NetTCPConnection took 8 s)
  $m = $null; $watch = [Threading.Mutex]::TryOpenExisting('Local\OSYNC-Master-Watch', [ref]$m); if ($m) { $m.Dispose() }
  $svc = @(
    [ordered]@{ name = 'ตัวเฝ้าเครื่องแม่ (อัปเดตรายการเกม / ข้อมูลให้เครื่องลูก)'; ok = [bool]$watch; how = 'OSYNC.bat > 2' },
    [ordered]@{ name = 'รับรายงานสถานะเครื่องลูก'; ok = [bool]$listen[[int](Get-Setting 'ClientReportPort' '4670')]; how = 'Master-ClientReports.ps1 -Install (ผู้ดูแล)' },
    [ordered]@{ name = 'รับไฟล์เซิร์ฟ FiveM จากเครื่องลูก'; ok = [bool]$listen[[int](Get-Setting 'FiveMSharePort' '4671')]; how = 'Master-FiveMShare.ps1 -Install (ผู้ดูแล)' },
    [ordered]@{ name = 'ล็อกอิน OSLink ของเครื่องลูก'; ok = [bool]$listen[[int](Get-Setting 'OslinkLoginPort' '4669')]; how = 'Master-OslinkLogins.ps1 -Install (ผู้ดูแล)' },
    [ordered]@{ name = 'ฮับคลังออนไลน์'; ok = [bool]$listen[4667]; how = 'Hub-Server.ps1 -Register' }
  )
  $drives = @(foreach ($d in (Get-SharedDrives).ToCharArray()) { $p = Get-PSDrive -Name $d -PSProvider FileSystem -ErrorAction SilentlyContinue; if ($p -and ($p.Free + $p.Used) -gt 0) { [ordered]@{ letter = "$d"; freeGB = [math]::Round($p.Free / 1GB); sizeGB = [math]::Round(($p.Free + $p.Used) / 1GB) } } })
  $fivem = [ordered]@{ files = 0; gb = 0; last = '' }
  $app = @(Get-CfxApps | Where-Object { $_.Name -eq 'FiveM' }) | Select-Object -First 1
  if ($app) {
    $cd = Join-Path $app.App 'data\server-cache-priv'
    $cf = @(Get-ChildItem -LiteralPath $cd -File -Filter 'cache_*' -ErrorAction SilentlyContinue)
    $fivem.files = $cf.Count; $fivem.gb = [math]::Round((($cf | Measure-Object Length -Sum).Sum) / 1GB, 2)
    $sl = Join-Path (Join-Path ((Split-Path -Qualifier $cd) + '\') '_osync-fivem-incoming') 'server.log'
    $hit = Select-String -LiteralPath $sl -Pattern 'commit .*: taken' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($hit) { $fivem.last = $hit.Line }
  }
  $cl = Get-ConsoleClients
  $gj = Get-Item -LiteralPath $GamesJson -ErrorAction SilentlyContinue
  [ordered]@{ ok = $true; pc = $env:COMPUTERNAME; services = $svc; drives = $drives; fivem = $fivem
    games = @(Read-JsonFile $GamesJson).Count; gamesUpdated = $(if ($gj) { $gj.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } else { '' })
    clientList = $cl; clients = @($cl).Count; clientsToday = @($cl | Where-Object { $_.minutesAgo -le 720 }).Count; clientsWithFails = @($cl | Where-Object { $_.minutesAgo -le 720 -and $_.fails.Count }).Count }
}
# settings.txt for the console: every Key=Value with the comment lines just above it as its help
function Get-SettingsView {
  $out = @(); $cm = New-Object System.Collections.Generic.List[string]
  foreach ($l in [IO.File]::ReadAllLines($SettingsFile, [Text.Encoding]::UTF8)) {
    if ($l -match '^\s*#\s?(.*)$') { $cm.Add($Matches[1]); continue }
    if ($l -match '^\s*([A-Za-z][A-Za-z0-9_]*)\s*=(.*)$') {
      $k = $Matches[1]; $v = $Matches[2].Trim()
      $out += [ordered]@{ key = $k; value = $v; help = ($cm -join "`n"); onoff = [bool]($v -match '^(?i)(on|off)$'); group = $(if ($k -like 'Client*') { 'client' } elseif ($k -like 'Online*') { 'online' } else { 'other' }) }
      $cm.Clear(); continue
    }
    if (-not $l.Trim()) { $cm.Clear() }
  }
  , $out
}
function Set-ConsoleSetting([string]$key, [string]$value) {
  if ($key -notmatch '^[A-Za-z][A-Za-z0-9_]{1,60}$') { throw 'bad key' }
  if (@(Get-SettingsView | Where-Object { $_.key -eq $key }).Count -ne 1) { throw "unknown setting $key" }
  if ($value -match '[\r\n]' -or $value.Length -gt 400) { throw 'bad value' }
  Set-SettingLine $key $value.Trim()
}
# Menu\config.json: the shop systems (time / shop / top-up server) - only these values change, the file's text stays as it is
$MenuConfig = Join-Path $Menu 'config.json'
$ShopDoc = Join-Path $SystemDir 'Docs\SHOP-API.md'
function Get-ShopView {
  $c = Read-JsonFile $MenuConfig
  [ordered]@{ ok = $true; apiUrl = "$($c.apiUrl)"; machineId = "$($c.machineId)"; brandName = "$($c.brandName)"
    menuOnly = [bool]($c.ui -and $c.ui.menuOnly); sidePanel = [bool]($c.ui -and $c.ui.sidePanel -ne $false)
    doc = $(if (Test-Path -LiteralPath $ShopDoc) { [IO.File]::ReadAllText($ShopDoc, [Text.Encoding]::UTF8) } else { '' }) }
}
function Set-JsonScalar([string]$text, [string]$key, [string]$json) {
  $re = '("' + [regex]::Escape($key) + '"\s*:\s*)("(?:[^"\\]|\\.)*"|true|false|null|-?\d+(?:\.\d+)?)'
  if ($text -notmatch $re) { throw "config.json has no $key" }
  ([regex]$re).Replace($text, { param($m) $m.Groups[1].Value + $json }, 1)
}
function Set-ShopConfig($b) {
  $api = "$($b.apiUrl)".Trim(); $mid = "$($b.machineId)".Trim(); $brand = "$($b.brandName)".Trim()
  if ($api -and $api -notmatch '^https?://[A-Za-z0-9.\-]+(:\d{1,5})?(/[A-Za-z0-9._~/\-]*)?$') { throw 'API URL ต้องเป็น http(s)://host[:port]/path' }
  if ($mid -and $mid -notmatch '^[A-Za-z0-9_.\-]{1,40}$') { throw 'รหัสเครื่องใช้ได้แค่ A-Z 0-9 _ . -' }
  if (-not $brand -or $brand -match '["\\\r\n]' -or $brand.Length -gt 40) { throw 'ชื่อร้านต้องไม่ว่าง และไม่มี " หรือ \' }
  $t = [IO.File]::ReadAllText($MenuConfig, [Text.Encoding]::UTF8)
  $t = Set-JsonScalar $t 'apiUrl' ('"' + $api + '"')
  $t = Set-JsonScalar $t 'machineId' ('"' + $mid + '"')
  $t = Set-JsonScalar $t 'brandName' ('"' + $brand + '"')
  $t = Set-JsonScalar $t 'menuOnly' $(if ($b.menuOnly) { 'true' } else { 'false' })
  $t = Set-JsonScalar $t 'sidePanel' $(if ($b.sidePanel) { 'true' } else { 'false' })
  $null = $t.Trim([char]0xFEFF) | ConvertFrom-Json   # still valid JSON, or nothing is written
  Write-TextFile $MenuConfig $t
}
function Test-ShopApi($b) {
  $api = "$($b.apiUrl)".Trim().TrimEnd('/'); $mid = "$($b.machineId)".Trim(); if (-not $mid) { $mid = 'KORI01' }
  if ($api -notmatch '^https?://') { throw 'ใส่ API URL ก่อน' }
  $url = "$api/station/session?machineId=$([uri]::EscapeDataString($mid))"
  try {
    $r = Invoke-WebRequest -Uri $url -Headers @{ 'X-Machine-ID' = $mid } -UseBasicParsing -TimeoutSec 5
    [ordered]@{ ok = $true; url = $url; status = [int]$r.StatusCode; body = "$($r.Content)".Substring(0, [Math]::Min(800, "$($r.Content)".Length)) }
  } catch { [ordered]@{ ok = $true; url = $url; status = 0; error = $_.Exception.Message } }
}

# ---------- requests ----------
$handler = {
  param($req)
  $hostOk = "$($req.Headers['host'])" -match "^(localhost|127\.0\.0\.1)(:$Port)?$"
  if (-not $hostOk) { return (New-ErrorResponse 403 'only from this PC (http://localhost)') }
  if ($req.Method -eq 'POST' -and $req.Headers['x-osync'] -ne '1') { return (New-ErrorResponse 403 'missing X-OSYNC header') }
  $p = $req.Path
  try {
    switch -Regex ($p) {
      '^/$' { return (New-FileResponse (Join-Path $WebDir 'index.html')) }
      '^/static/([A-Za-z0-9._\-]+)$' { return (New-FileResponse (Join-Path $WebDir $Matches[1])) }
      '^/poster/(.+)$' {
        $f = $Matches[1]
        $okRoots = @($Menu, $Launchers) + @(Get-GameFolders)
        if ($f -notmatch '\.(png|jpe?g|webp|gif|ico|bmp)$' -or $f -match '\.\.' -or -not (($okRoots | Where-Object { $f.StartsWith($_.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) }) -or (Test-MenuImage $f))) { return (New-ErrorResponse 404 'not found') }
        return (New-FileResponse $f)
      }
      '^/api/status$' { return (New-JsonResponse (Get-ConsoleStatus)) }
      '^/api/games$' { return (New-JsonResponse @{ ok = $true; games = (Get-ConsoleGames); cats = (Get-Cats) }) }
      '^/api/game$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        $b = Get-JsonBody $req; Set-GameOverride "$($b.id)" $b
        return (New-JsonResponse @{ ok = $true; list = (Invoke-GameList) })
      }
      '^/api/icon$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        $b = Get-JsonBody $req; $name = Set-GameIcon "$($b.id)" "$($b.data)"
        return (New-JsonResponse @{ ok = $true; file = $name; list = (Invoke-GameList) })
      }
      '^/api/icon/reset$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        $b = Get-JsonBody $req; if ("$($b.id)" -notmatch '^[A-Za-z0-9._\-]{1,80}$') { throw 'bad game id' }; Remove-GameIcon "$($b.id)"
        return (New-JsonResponse @{ ok = $true; list = (Invoke-GameList) })
      }
      '^/api/update$' { if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }; return (New-JsonResponse (Invoke-GameList)) }
      '^/api/drives$' { return (New-JsonResponse (Get-ConsoleDrives)) }
      '^/api/drives/add$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        $r = Add-GameDrive (Get-JsonBody $req)
        return (New-JsonResponse @{ ok = $true; path = $r.path; notes = $r.notes; list = (Invoke-GameList) })
      }
      '^/api/drives/remove$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        Remove-GameDrive "$((Get-JsonBody $req).path)"
        return (New-JsonResponse @{ ok = $true; list = (Invoke-GameList) })
      }
      '^/api/online$' { return (New-JsonResponse (Get-OnlineView)) }
      '^/api/online/publish$' { if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }; return (New-JsonResponse (Publish-Branch)) }
      '^/api/online/pull$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        return (New-JsonResponse (Start-Pull "$((Get-JsonBody $req).key)"))
      }
      '^/api/online/jobs$' { return (New-JsonResponse @{ ok = $true; jobs = @(Get-PullJobs) }) }
      '^/api/overview$' { return (New-JsonResponse (Get-ConsoleOverview)) }
      '^/api/clients$' { return (New-JsonResponse @{ ok = $true; clients = (Get-ConsoleClients) }) }
      '^/api/client$' { return (New-JsonResponse (Get-ConsoleClientReport "$($req.Query['ip'])")) }
      '^/api/settings$' { return (New-JsonResponse @{ ok = $true; settings = (Get-SettingsView) }) }
      '^/api/setting$' {
        if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }
        $b = Get-JsonBody $req; Set-ConsoleSetting "$($b.key)" "$($b.value)"
        return (New-JsonResponse @{ ok = $true })
      }
      '^/api/shop$' {
        if ($req.Method -eq 'POST') { Set-ShopConfig (Get-JsonBody $req); return (New-JsonResponse @{ ok = $true }) }
        return (New-JsonResponse (Get-ShopView))
      }
      '^/api/shop/test$' { if ($req.Method -ne 'POST') { return (New-ErrorResponse 405 'POST') }; return (New-JsonResponse (Test-ShopApi (Get-JsonBody $req))) }
      '^/api/_stop$' { if ($AllowStop -and $req.Method -eq 'POST') { $r = New-JsonResponse @{ ok = $true }; $r.Stop = $true; return $r }; return (New-ErrorResponse 404 'not found') }
      default { return (New-ErrorResponse 404 'not found') }
    }
  } catch { return (New-ErrorResponse 400 "$($_.Exception.Message)") }
}

$mutex = New-Object Threading.Mutex($false, "Local\OSYNC-Console-$Port")
if (-not $mutex.WaitOne(0)) { Write-Host "the console already runs on port $Port"; exit 0 }
Start-HttpServer -Port $Port -Bind '127.0.0.1' -Handler $handler -Name 'OSYNC console'
