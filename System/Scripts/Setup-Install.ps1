# Setup-Install.ps1 - the Easy Install: what OSYNC-Setup.exe runs on a master PC (made by Tool-Pack.ps1, next to payload.zip),
# and what EASY-INSTALL.bat runs from a download of the project (-Source <that folder>, e.g. GitHub > Code > Download ZIP).
# First it looks at the PC (Setup-Plan.ps1, read only) and suggests where OSYNC goes; Enter takes the suggestion.
# New master: puts OSYNC on the game drive the client PCs see, writes Settings for THIS shop (drives, master PC
#             name + IP), names the game menu after the shop, then starts the first-time setup (Master-Setup.ps1).
# Master that already has OSYNC: updates it in place - System\Scripts, System\Client, System\Docs, OSYNC.bat,
#             README.md, the menu program and every tool folder the pack has (Tools\<name>, Sunshine0J\config kept) are
#             replaced (old ones -> System\Backup\upgrade-<date>); Settings, the menu's config / games / posters,
#             Launchers, GAME, tools the pack does not have and client data stay as they are.
# Tools\ in the pack (Tool-Pack without -NoTools): checked file by file against Tools\TOOLS-MANIFEST.txt (SHA256) after.
#   Setup-Install.ps1                              asks where / shop name (Enter = suggested answer)
#   -Target X:\OSYNC -ShopName "MY SHOP" -Yes      no questions          -NoWizard   do not start the setup afterwards
#   -Upgrade X:\OSYNC                              update that OSYNC folder       -Payload <zip>   default: next to this file
#   -Source <folder>                               files from that folder instead of payload.zip (EASY-INSTALL.bat; no built menu)
#   -PlanOnly                                      only the check of this PC (Setup-Plan.ps1) - installs nothing (an AI runs it first)
param([string]$Target = '', [string]$ShopName = '', [string]$Upgrade = '', [string]$Payload = '', [string]$Source = '', [switch]$Yes, [switch]$NoWizard, [string]$BranchCommand = '', [switch]$PlanOnly)
$ErrorActionPreference = 'Stop'
# an INSTALLED OSYNC has Launchers\ or System\Data\ (made by this setup); a download of the project has neither
function Test-Installed([string]$dir) { (Test-Path -LiteralPath (Join-Path $dir 'OSYNC.bat')) -and (Test-Path -LiteralPath (Join-Path $dir 'System\Scripts\Common.ps1')) -and ((Test-Path -LiteralPath (Join-Path $dir 'Launchers')) -or (Test-Path -LiteralPath (Join-Path $dir 'System\Data'))) }
if ($Source) {
  $Source = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
  if (-not (Test-Path -LiteralPath (Join-Path $Source 'System\Scripts\Common.ps1'))) { Write-Host "Not an OSYNC download: $Source" -ForegroundColor Red; exit 1 }
  if (Test-Installed $Source) { Write-Host "$Source is an OSYNC that is already installed - use its OSYNC.bat. To update it: EASY-INSTALL.bat of a NEW download, or OSYNC-Setup.exe." -ForegroundColor Red; if (-not $Yes) { [void](Read-Host 'Press Enter to close') }; exit 1 }
  $Payload = ''
} else {
  if (-not $Payload) { $Payload = Join-Path $PSScriptRoot 'payload.zip' }
  $Payload = (Resolve-Path -LiteralPath $Payload).Path
}
# copying and naming need no admin rights; the first-time setup at the end asks for them itself (OSYNC.bat setup)
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Ask([string]$q, [string]$def) { if ($Yes) { return $def }; $r = Read-Host "$q [$def]"; if ($r.Trim()) { $r.Trim() } else { $def } }
function YesNo([string]$q) { if ($Yes) { return $true }; (Read-Host "$q [Y/N]") -match '^[Yy]' }
function Head([string]$t) { Write-Host "`n== $t" -ForegroundColor Yellow }
function Set-Line([string]$file, [string]$key, [string]$value, [switch]$OnlyIfEmpty) {
  $lines = @(Get-Content -LiteralPath $file -Encoding UTF8)
  $i = -1; for ($n = 0; $n -lt $lines.Count; $n++) { if ($lines[$n] -match "^\s*$key\s*=") { $i = $n; break } }
  if ($i -ge 0) { if ($OnlyIfEmpty -and (($lines[$i] -split '=', 2)[1].Trim())) { return }; $lines[$i] = "$key=$value" } else { $lines += "$key=$value" }
  [IO.File]::WriteAllLines($file, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}
# set "brandName" in config.json without reformatting the file
function Set-BrandName([string]$file, [string]$name) {
  $t = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  $t = ([regex]'("brandName"\s*:\s*")[^"]*(")').Replace($t, [Text.RegularExpressions.MatchEvaluator] { param($m) $m.Groups[1].Value + $name + $m.Groups[2].Value }, 1)
  [IO.File]::WriteAllText($file, $t, (New-Object Text.UTF8Encoding $false))
}
# the OSYNC watcher of a folder (it keeps launchers open); stopped while its scripts are replaced
function Get-Watchers([string]$root) { @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*$root\System\Scripts\Master-Watch.ps1*" }) }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ver = if ($Source) { $vf = Join-Path $Source 'System\VERSION.txt'; if (Test-Path -LiteralPath $vf) { "$(Get-Content -LiteralPath $vf -Raw)".Trim() } else { "from the folder $Source" } } else { try { $z = [IO.Compression.ZipFile]::OpenRead($Payload); $e = $z.Entries | Where-Object { $_.FullName -replace '\\', '/' -eq 'System/VERSION.txt' } | Select-Object -First 1; $r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); $z.Dispose(); $t.Trim() } catch { '?' } }
# the files to put in place: payload.zip unpacked, or a copy of the -Source folder (no .git, nothing a master made)
function Expand-Files([string]$to) {
  if (-not $Source) { [IO.Compression.ZipFile]::ExtractToDirectory($Payload, $to); return }
  & robocopy.exe $Source $to /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /XD (Join-Path $Source '.git') (Join-Path $Source 'System\Data') (Join-Path $Source 'System\Backup') (Join-Path $Source 'System\Dist') (Join-Path $Source 'Menu\source\node_modules') | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE): $Source" }
}
# a NEW shop starts without the values of the shop the files came from (a project download carries them; OSYNC-Setup.exe
# has them blank already). Same list as Tool-Pack.ps1. SharedDrives / MasterPC / MasterIP are written for this PC below.
$ShopKeys = 'SharedDrives', 'MasterIP', 'MasterPC', 'GameFolders', 'ClientBlockCpuz', 'ClientApexClean', 'ClientApexMinimal', 'ClientSteamVerify', 'ClientSteamVerifyApps', 'OnlineBranch', 'OnlineBranchName', 'OnlineBind', 'OnlineExternalIP'
function Clear-ShopValues([string]$file) {
  $t = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  foreach ($k in $ShopKeys) { $t = [regex]::Replace($t, "(?m)^(\s*$k\s*=)[^\r\n]*", '$1') }
  $t = [regex]::Replace($t, '(?m)^(\s*Role\s*=)[^\r\n]*', '${1}auto')
  [IO.File]::WriteAllText($file, $t, (New-Object Text.UTF8Encoding $false))
}
# the game menu's config without the other shop's badge, logo, banner, server address and featured games
function Clear-MenuShop([string]$file) {
  if (-not (Test-Path -LiteralPath $file)) { return }
  $t = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  foreach ($k in 'brandBadge', 'brandLogo', 'brandMark', 'apiUrl', 'machineId', 'hudBanner', 'hudBannerTag', 'hudBannerText') { $t = [regex]::Replace($t, '("' + $k + '"\s*:\s*")[^"]*(")', '${1}${2}') }
  $t = [regex]::Replace($t, '("featured"\s*:\s*)\[[^\]]*\]', '${1}[]')
  [void]($t | ConvertFrom-Json)
  [IO.File]::WriteAllText($file, $t, (New-Object Text.UTF8Encoding $false))
}
# Tools\ from the pack (OSYNC-Setup.exe made without -NoTools): every tool folder there replaces the one this OSYNC has
# (the old one -> backup), so a branch has the SAME tool programs as the shop that made the pack. Folders only this
# OSYNC has stay. Kept from the old copy: the shop's own settings inside a tool (Sunshine0J\config).
$KeepInTools = @('Sunshine0J\config')
function Sync-Tools([string]$from, [string]$root, [string]$bk) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  $to = Join-Path $root 'Tools'; New-Item -ItemType Directory -Force -Path $to | Out-Null
  $names = @(Get-ChildItem -LiteralPath $from -Directory | ForEach-Object Name); $done = @()
  foreach ($n in $names) {
    $new = Join-Path $from $n; $old = Join-Path $to $n
    if (Test-Path -LiteralPath $old) {
      $dst = Join-Path $bk "Tools\$n"; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
      try { Move-Item -LiteralPath $old -Destination $dst -ErrorAction Stop } catch { Write-Host "  Tools\$n is in use - not updated (close it, then run this update again)" -ForegroundColor Yellow; continue }
      foreach ($k in $KeepInTools | Where-Object { $_ -like "$n\*" }) {
        $sub = $k.Substring($n.Length + 1); $ko = Join-Path $dst $sub; $kn = Join-Path $new $sub
        if (Test-Path -LiteralPath $ko) { if (Test-Path -LiteralPath $kn) { Remove-Item -LiteralPath $kn -Recurse -Force }; Copy-Item -LiteralPath $ko -Destination $kn -Recurse; Write-Host "  Tools\$k kept (this shop's own)" }
      }
    }
    Move-Item -LiteralPath $new -Destination $old; $done += $n
  }
  foreach ($f in @(Get-ChildItem -LiteralPath $from -File)) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $to $f.Name) -Force }   # TOOLS-MANIFEST.txt
  Write-Host "  tools: $($done.Count) of $($names.Count) folders put in place ($($done -join ', '))"
}
# proof that Tools\ is the same as the pack: every file in TOOLS-MANIFEST.txt there, same size and SHA256
function Test-ToolsSame([string]$root) {
  $tm = Join-Path $root 'Tools\TOOLS-MANIFEST.txt'
  if (-not (Test-Path -LiteralPath $tm)) { return }
  $n = 0; $bad = New-Object System.Collections.Generic.List[string]
  foreach ($l in [IO.File]::ReadAllLines($tm)) {
    if ($l.StartsWith('#') -or -not $l.Trim()) { continue }
    $p = $l -split "`t", 3; if ($p.Count -lt 3) { continue }; $n++
    $f = Join-Path $root "Tools\$($p[2])"
    if (-not (Test-Path -LiteralPath $f) -or (Get-Item -LiteralPath $f -Force).Length -ne [long]$p[1] -or (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash -ne $p[0]) { $bad.Add($p[2]) }
  }
  if ($bad.Count) { Write-Host "  tools: $($bad.Count) of $n files are NOT the same as the pack: $(($bad | Select-Object -First 5) -join ', ')" -ForegroundColor Red }
  else { Write-Host "  tools: all $n files are the same as the pack (SHA256)" -ForegroundColor Green }
}
Write-Host "OSYNC setup  ($ver)" -ForegroundColor Cyan

# ---------- where: an OSYNC that is already on this PC, or a new folder on the game drive ----------
$sys = $env:SystemDrive.Substring(0, 1).ToUpper()
$drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID.Substring(0, 1).ToUpper() -ne $sys } | Sort-Object FreeSpace -Descending)
$existing = @(foreach ($d in $drives) {
    foreach ($c in @("$($d.DeviceID)\") + @(Get-ChildItem "$($d.DeviceID)\" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })) {
      if ((Test-Installed $c) -and ($c.TrimEnd('\') -ine $Source)) { $c.TrimEnd('\') }
    } })
if (-not $Upgrade -and -not $Target -and -not $PlanOnly -and $existing) {
  Write-Host "OSYNC found on this PC: $($existing -join ', ')"
  # never updated without a person saying so (with -Yes an update needs -Upgrade <folder>)
  if ($Yes) { Write-Host 'Use -Upgrade <folder> to update it, or -Target <folder> for a new one.' -ForegroundColor Red; exit 1 }
  if (YesNo "Update $($existing[0]) (keeps Settings, games, launchers, menu config)?") { $Upgrade = $existing[0] }
}

# the drives the clients see: the LW / Kritidet / CCU server's own list when Node.js can read it, else fixed drives except C:
$shared = ''
$db = 'C:\lwserver\config\lwservice.db'
if ((Test-Path -LiteralPath $db) -and (Get-Command node -ErrorAction SilentlyContinue)) {
  $js = "try{const{DatabaseSync}=require('node:sqlite');const d=new DatabaseSync(process.argv[1],{readOnly:true});console.log(d.prepare('select drive,type,vdiskletter from tServerDiskMng').all().filter(r=>+r.type===1&&+r.vdiskletter).map(r=>String.fromCharCode(+r.vdiskletter)).join(''))}catch(e){}"
  $shared = ((& node --no-warnings -e $js $db 2>$null | Select-Object -First 1) -replace '[^A-Za-z]', '').ToUpper()
}
if (-not $shared) { $shared = ($drives | ForEach-Object { $_.DeviceID.Substring(0, 1).ToUpper() }) -join '' }
$shared = (($shared.ToCharArray() | Sort-Object -Unique) -join '')

$tmp = Join-Path $env:TEMP "osync-setup-$stamp"
# leave nothing in TEMP when the person stops at a question
function Quit([int]$rc) { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }; exit $rc }
# -PlanOnly: the read-only check of this PC and nothing else (only System\Scripts is taken out of payload.zip)
if ($PlanOnly) {
  if ($Source) { $ps = Join-Path $Source 'System\Scripts\Setup-Plan.ps1' }
  else {
    $z = [IO.Compression.ZipFile]::OpenRead($Payload)
    try { foreach ($e in @($z.Entries | Where-Object { $_.FullName -like 'System/Scripts/*' -and $_.Name })) { $d = Join-Path $tmp ($e.FullName -replace '/', '\'); New-Item -ItemType Directory -Force -Path (Split-Path -Parent $d) | Out-Null; [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $d, $true) } } finally { $z.Dispose() }
    $ps = Join-Path $tmp 'System\Scripts\Setup-Plan.ps1'
  }
  & $ps -SharedDrives $shared
  if ($existing) { Write-Host "`nOSYNC already installed here: $($existing -join ', ') - an update: -Upgrade <that folder>" -ForegroundColor Cyan }
  Quit 0
}
if ($Upgrade) {
  # ---------- update in place ----------
  $root = $Upgrade.TrimEnd('\')
  Head "Update $root"
  Expand-Files $tmp
  $bk = Join-Path $root "System\Backup\upgrade-$stamp"; New-Item -ItemType Directory -Force -Path $bk | Out-Null
  $watch = Get-Watchers $root
  if ($watch) { $watch | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Write-Host '  watcher stopped while its scripts are replaced' }
  foreach ($rel in 'OSYNC.bat', 'README.md', 'System\Scripts', 'System\Client', 'System\Docs', 'System\VERSION.txt') {
    $old = Join-Path $root $rel; $new = Join-Path $tmp $rel
    if (-not (Test-Path -LiteralPath $new)) { continue }
    if (Test-Path -LiteralPath $old) { $dst = Join-Path $bk $rel; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null; Move-Item -LiteralPath $old -Destination $dst }
    Move-Item -LiteralPath $new -Destination $old
    Write-Host "  updated: $rel"
  }
  Sync-Tools (Join-Path $tmp 'Tools') $root $bk
  Test-ToolsSame $root
  # settings keys new in this version are added; values the shop set stay
  $newSet = Join-Path $tmp 'Settings\settings.txt'; $curSet = Join-Path $root 'Settings\settings.txt'
  if (Test-Path -LiteralPath $curSet) {
    $have = @(Get-Content -LiteralPath $curSet -Encoding UTF8 | Where-Object { $_ -match '^\s*[A-Za-z]+\s*=' } | ForEach-Object { ($_ -split '=', 2)[0].Trim() })
    # each new key comes with the comment lines written above it in the new settings.txt
    $add = @(); $names = @(); $note = @()
    foreach ($l in Get-Content -LiteralPath $newSet -Encoding UTF8) {
      if ($l -match '^\s*#') { $note += $l; continue }
      if ($l -match '^\s*([A-Za-z]+)\s*=' -and $have -notcontains $Matches[1]) { $add += @('') + $note + $l; $names += $Matches[1] }
      $note = @()
    }
    if ($add) {
      $all = @(Get-Content -LiteralPath $curSet -Encoding UTF8) + $add
      [IO.File]::WriteAllLines($curSet, [string[]]$all, (New-Object Text.UTF8Encoding $false))
      Write-Host "  settings added: $($names -join ', ')"
    }
  }
  Set-Line $curSet 'MasterPC' $env:COMPUTERNAME -OnlyIfEmpty
  # the menu program: replaced only when it is closed (the shop's exe name is kept)
  $appOld = Join-Path $root 'Menu\app'; $appNew = Join-Path $tmp 'Menu\app'
  $cfg = try { Get-Content -LiteralPath (Join-Path $root 'Menu\config.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
  $name = if ($cfg -and $cfg.brandName) { ($cfg.brandName -replace '[\\/:*?"<>|]', '').Trim() } else { '' }
  $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($appOld + '\', [StringComparison]::OrdinalIgnoreCase) })
  if ((Test-Path -LiteralPath $appNew) -and $running -and -not (YesNo "The game menu is open on this PC ($(($running | ForEach-Object Name | Sort-Object -Unique) -join ', ')). Close it to update the menu program?")) { Write-Host '  menu program: not updated (it was open)' -ForegroundColor Yellow }
  elseif (Test-Path -LiteralPath $appNew) {
    $running | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $appOld) { Move-Item -LiteralPath $appOld -Destination (Join-Path $bk 'Menu-app') }
    Move-Item -LiteralPath $appNew -Destination $appOld
    $exe = Get-ChildItem -LiteralPath $appOld -Filter *.exe -File | Where-Object { $_.Length -gt 50MB } | Select-Object -First 1
    if ($name -and $exe -and $exe.BaseName -ne $name) { Rename-Item -LiteralPath $exe.FullName -NewName "$name.exe" }
    Write-Host "  updated: Menu\app$(if ($name) { " ($name.exe)" })"
    if ($running) { Start-Process explorer.exe -ArgumentList ('"' + (Join-Path $root 'System\Client\Menu.vbs') + '"') }
  }
  if ($watch) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'System\Scripts\Master-Watch.ps1') -Register | Out-Null; Write-Host '  watcher started again (new scripts)' }
  Write-Host "  old files: $bk"
} else {
  # ---------- new install ----------
  Expand-Files $tmp
  # look at this PC first (read only) and take its suggestion as the default answer
  Head 'This master (read only - nothing changes yet)'
  $plan = $null
  try { $plan = @(& (Join-Path $tmp 'System\Scripts\Setup-Plan.ps1') -SharedDrives $shared -PassThru) | Where-Object { $_ -and $_.PSObject.Properties['OsyncRoot'] } | Select-Object -Last 1 } catch { Write-Host "  (the check failed: $($_.Exception.Message))" -ForegroundColor Yellow }
  $def = if ($Target) { $Target } elseif ($plan -and $plan.OsyncRoot) { $plan.OsyncRoot } else { "$($shared.Substring(0, 1)):\OSYNC" }
  Head 'Where to put OSYNC'
  Write-Host "  drives the client PCs see: $shared   (OSYNC must be on one of them)"
  $root = (Ask '  Folder' $def).TrimEnd('\')
  if (-not ($shared.ToUpper().Contains($root.Substring(0, 1).ToUpper()))) { Write-Host "  WARNING $($root.Substring(0, 2)) is not in the drives the clients see ($shared)" -ForegroundColor Yellow; if (-not (YesNo '  Use it anyway?')) { Quit 1 } }
  if ((Test-Path -LiteralPath $root) -and (Get-ChildItem -LiteralPath $root -Force | Select-Object -First 1)) {
    if (Test-Path -LiteralPath (Join-Path $root 'OSYNC.bat')) { Write-Host "  $root already has OSYNC - run this again and choose update" -ForegroundColor Red; Quit 1 }
    if (-not (YesNo "  $root is not empty. Put OSYNC in it anyway (nothing there is deleted)?")) { Quit 1 }
  }
  Head "Copy OSYNC to $root"
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  foreach ($i in Get-ChildItem -LiteralPath $tmp -Force) { $d = Join-Path $root $i.Name; if (-not (Test-Path -LiteralPath $d)) { Move-Item -LiteralPath $i.FullName -Destination $d } }
  foreach ($d in 'Launchers', 'GAME', 'Tools', 'System\Data', 'System\Backup', 'Menu\data') { New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null }
  # the folder had a Tools\ already: the pack's tool folders go in one by one (old ones -> System\Backup)
  Sync-Tools (Join-Path $tmp 'Tools') $root (Join-Path $root "System\Backup\setup-$stamp")
  Write-Host '  done'
  Test-ToolsSame $root

  Head 'This shop'
  $set = Join-Path $root 'Settings\settings.txt'
  Clear-ShopValues $set
  Clear-MenuShop (Join-Path $root 'Menu\config.json')
  if ($plan) { [IO.File]::WriteAllText((Join-Path $root 'System\Data\setup-plan.txt'), $plan.Text, (New-Object Text.UTF8Encoding $true)); Write-Host "  the check of this PC is saved in $root\System\Data\setup-plan.txt" }
  $ip = (@(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' | Where-Object { $_.DefaultIPGateway } | ForEach-Object { $_.IPAddress } | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -notmatch '^169\.254\.' }) + @('')) | Select-Object -First 1
  Set-Line $set 'SharedDrives' $shared; Set-Line $set 'MasterPC' $env:COMPUTERNAME; Set-Line $set 'MasterIP' $ip
  Write-Host "  SharedDrives=$shared  MasterPC=$env:COMPUTERNAME  MasterIP=$ip   ($set)"
  $name = ((Ask '  Shop name (shown on the game menu)' $(if ($ShopName) { $ShopName } else { 'GAME CENTER' })) -replace '[\\/:*?"<>|]', '').Trim()
  Set-BrandName (Join-Path $root 'Menu\config.json') $name
  $exe = Get-ChildItem -LiteralPath (Join-Path $root 'Menu\app') -Filter *.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 50MB } | Select-Object -First 1
  if ($exe -and $exe.BaseName -ne $name) { Rename-Item -LiteralPath $exe.FullName -NewName "$name.exe" }
  Write-Host "  game menu: $name  (logo: Menu\tools\_system\Make-Brand.ps1 -Image <picture>)"
  if (-not $exe) { Write-Host '  the menu program is not built yet (a project download has only its source): the first-time setup step 4 builds it (needs Node.js LTS), or use OSYNC-Setup.exe which has it built' -ForegroundColor Yellow }
}
foreach ($d in 'System', 'Menu\app', 'Menu\tools') { Get-ChildItem -LiteralPath (Join-Path $root $d) -Recurse -File -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

# ---------- branch runner (folder 2, C:\AT9-Branch): only for a branch of a shop that has the shop web ----------
$bLine = $BranchCommand
if (-not $bLine -and -not $Yes -and -not (Test-Path -LiteralPath (Join-Path $env:SystemDrive 'AT9-Branch\state.json'))) {
  Head 'Branch of a shop with the shop web? (Enter = skip)'
  Write-Host '  The branch runner links this master to the shop web, so the web can wake this branch''s PCs.'
  Write-Host '  Admin page > Branches > the branch > install command: copy the whole line and paste it here.'
  $bLine = (Read-Host '  Install line').Trim()
}
if ($bLine) {
  $bm = [regex]::Match($bLine, '(?i)https?://[^\s/''"`;|]+/api/branch/setup/[A-Za-z0-9_-]{20,64}')
  if (-not $bm.Success) { Write-Host '  That is not the install line from admin page > Branches - skipped (later: OSYNC.bat > 7 Tools > 20)' -ForegroundColor Yellow }
  else {
    Write-Host '  installing the branch runner (press Yes on the Windows prompt) ...'
    $br = Join-Path $root 'System\Scripts\Branch-Runner.ps1'
    $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$br`"", '-Install', '-Yes', '-Command', $bm.Value, '-OsyncRoot', "`"$root`"")
    if ($p.ExitCode -eq 0) { Write-Host '  branch runner installed (state: C:\AT9-Branch\status.cmd)' -ForegroundColor Green }
    else { Write-Host '  branch runner NOT installed - later: OSYNC.bat > 7 Tools > 20 with a new install line' -ForegroundColor Yellow }
  }
}

# ---------- next: the first-time setup (new) or the check (update) ----------
$s = Join-Path $root 'System\Scripts'
if ($NoWizard) { Write-Host "`nOSYNC is in $root. Next: $root\OSYNC.bat > $(if ($Upgrade) { '6 (check)' } else { '4 (first-time setup)' })" -ForegroundColor Cyan; exit 0 }
if ($Upgrade) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $s 'Tool-Check.ps1') -Mode master }
else { $env:OSYNC_NOPAUSE = '1'; & cmd.exe /c "`"$(Join-Path $root 'OSYNC.bat')`" setup" }   # asks for admin rights (UAC), opens its own window
Write-Host "`nOSYNC: $root\OSYNC.bat   Clients: on ONE client PC per image, super workstation mode: OSYNC.bat client, then save the image." -ForegroundColor Cyan
if (-not $Yes) { [void](Read-Host 'Press Enter to close') }
