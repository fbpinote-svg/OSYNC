# Setup-Plan.ps1 - look at THIS master and say where each part of OSYNC should go (READ ONLY: changes nothing).
# Used by the Easy Install (Setup-Install.ps1 shows it before it asks where to put OSYNC, and takes its answer as the
# suggested folder), by the first-time setup (Master-Setup.ps1 step 0) and by OSYNC.bat > 7 Tools > 23.
# Looks at: the diskless server program, the drives the client PCs see, each drive (size, free, SSD / HDD), the
# launchers and where they are installed, Steam's libraries (games, size), the network (IP, fixed or DHCP),
# Windows / PowerShell / .NET / Node.js.
#   Setup-Plan.ps1                     show the plan
#   -SharedDrives DEF                  the drives the clients see (default: the diskless server's list, else Settings, else fixed drives)
#   -OutFile <file>                    also save the plan as text        -PassThru   return the plan as an object (Setup-Install)
#   -Quiet                             print nothing (with -PassThru)
param([string]$SharedDrives = '', [string]$OutFile = '', [switch]$PassThru, [switch]$Quiet)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Continue'
$lines = New-Object System.Collections.Generic.List[string]
function Out([string]$t = '', [string]$c = '') { $lines.Add($t); if (-not $Quiet) { if ($c) { Write-Host $t -ForegroundColor $c } else { Write-Host $t } } }
function GB([double]$b) { [math]::Round($b / 1GB) }
$sys = $env:SystemDrive.Substring(0, 1).ToUpper()

# ---------- the diskless server program and the drives the client PCs see ----------
$server = ''
$names = [ordered]@{ 'C:\lwserver' = 'LW (Kritidet / CCU)'; 'C:\Program Files\CCBoot' = 'CCBoot'; 'C:\Program Files (x86)\CCBoot' = 'CCBoot'; 'C:\iCafeCloud\Server' = 'iCafeCloud'; 'C:\Program Files\iCafeCloud Server' = 'iCafeCloud'; 'C:\NxD\Server' = 'NxD'; 'C:\ggRock' = 'ggRock' }
foreach ($k in $names.Keys) { if (Test-Path -LiteralPath $k) { $server = "$($names[$k]) ($k)"; break } }
if (-not $server) { $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $DisklessServerServices } | Select-Object -First 1; if ($svc) { $server = "service $($svc.Name)" } }
$how = ''
$shared = ($SharedDrives -replace '[^A-Za-z]', '').ToUpper()
if ($shared) { $how = 'given' }
if (-not $shared) {
  # LW: its own list of game disks (read only, needs Node.js 22.5+ for node:sqlite)
  $db = 'C:\lwserver\config\lwservice.db'
  if ((Test-Path -LiteralPath $db) -and (Get-Command node -ErrorAction SilentlyContinue)) {
    $js = "try{const{DatabaseSync}=require('node:sqlite');const d=new DatabaseSync(process.argv[1],{readOnly:true});console.log(d.prepare('select drive,type,vdiskletter from tServerDiskMng').all().filter(r=>+r.type===1&&+r.vdiskletter).map(r=>String.fromCharCode(+r.vdiskletter)).join(''))}catch(e){}"
    $shared = ((& node --no-warnings -e $js $db 2>$null | Select-Object -First 1) -replace '[^A-Za-z]', '').ToUpper()
    if ($shared) { $how = 'from the LW server settings' }
  }
}
# Settings only of an INSTALLED OSYNC: a download of the project carries the SharedDrives of the shop it came from
if (-not $shared -and ((Test-Path -LiteralPath $Launchers) -or (Test-Path -LiteralPath $DataDir))) { $s = ((Get-Setting 'SharedDrives') -replace '[^A-Za-z]', '').ToUpper(); if ($s) { $shared = $s; $how = 'from Settings\settings.txt' } }

# ---------- drives ----------
$media = @{}
try {
  $pd = @{}; foreach ($p in @(Get-PhysicalDisk -ErrorAction Stop)) { $pd["$($p.DeviceId)"] = $p }
  foreach ($part in @(Get-Partition -ErrorAction Stop | Where-Object { $_.DriveLetter })) {
    $p = $pd["$($part.DiskNumber)"]
    if ($p) { $t = "$($p.MediaType)"; if ($t -eq 'Unspecified' -or -not $t) { $t = '?' }; if ("$($p.BusType)" -eq 'NVMe') { $t = 'NVMe SSD' } else { $t = "$t $($p.BusType)".Trim() }; $media["$($part.DriveLetter)".ToUpper()] = $t }
  }
} catch { }
$drives = @(foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Sort-Object DeviceID)) {
    $l = $d.DeviceID.Substring(0, 1).ToUpper()
    [pscustomobject]@{ Letter = $l; Label = "$($d.VolumeName)"; SizeGB = GB $d.Size; FreeGB = GB $d.FreeSpace; Media = $(if ($media[$l]) { $media[$l] } else { '?' }); System = ($l -eq $sys) }
  })
if (-not $shared) { $shared = (($drives | Where-Object { -not $_.System }) | ForEach-Object Letter) -join ''; $how = 'all fixed drives except the system drive (no diskless list found)' }
$shared = (($shared.ToCharArray() | Sort-Object -Unique) -join '')
foreach ($d in $drives) { $d | Add-Member -NotePropertyName Shared -NotePropertyValue ($shared.Contains($d.Letter)) }

# ---------- OSYNC already here? (installed = has Launchers\ or System\Data\; a download of the project has neither) ----------
function Test-OsyncInstalled([string]$dir) { (Test-Path -LiteralPath (Join-Path $dir 'OSYNC.bat')) -and (Test-Path -LiteralPath (Join-Path $dir 'System\Scripts\Common.ps1')) -and ((Test-Path -LiteralPath (Join-Path $dir 'Launchers')) -or (Test-Path -LiteralPath (Join-Path $dir 'System\Data'))) }
$existing = @(foreach ($d in $drives) {
    foreach ($c in @("$($d.Letter):\") + @(Get-ChildItem "$($d.Letter):\" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })) {
      if (Test-OsyncInstalled $c) { $c.TrimEnd('\') }
    } })
$installedHere = Test-OsyncInstalled $Root

# ---------- launchers ----------
$launch = @(foreach ($l in $LauncherTable) {
    $inOsync = $installedHere -and (Test-Path -LiteralPath (Get-LauncherExe $l.Key))
    $at = if ($inOsync) { Get-LauncherDir $l.Key } else { Get-LauncherInstallPath $l.Key }
    if (-not $at) { continue }
    $dl = $at.Substring(0, 1).ToUpper()
    [pscustomobject]@{ Key = $l.Key; Title = $l.Title; Path = $at; InOsync = $inOsync; OnShared = $shared.Contains($dl); OnSystem = ($dl -eq $sys) }
  })

# ---------- Steam libraries: every library Steam knows (also on drives the clients do not see) ----------
$steamDir = if ($installedHere) { Get-SteamDir } else { $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath; if ($p) { $p -replace '/', '\' } else { '' } }
$libs = New-Object System.Collections.Generic.List[string]
if ($steamDir) {
  $libs.Add($steamDir.TrimEnd('\'))
  $vdf = Join-Path $steamDir 'steamapps\libraryfolders.vdf'
  if (Test-Path -LiteralPath $vdf) { foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) { $v = ($m.Groups[1].Value -replace '\\\\', '\').TrimEnd('\'); if (-not ($libs | Where-Object { $_ -ieq $v })) { $libs.Add($v) } } }
}
$steamLibs = @(foreach ($lib in $libs) {
    $sa = Join-Path $lib 'steamapps'
    if (-not (Test-Path -LiteralPath $sa)) { continue }
    $acf = @(Get-ChildItem -LiteralPath $sa -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_228980\.acf$' })
    $bytes = 0.0; foreach ($a in $acf) { $m = [regex]::Match([IO.File]::ReadAllText($a.FullName), '"SizeOnDisk"\s+"(\d+)"'); if ($m.Success) { $bytes += [double]$m.Groups[1].Value } }
    $dl = $lib.Substring(0, 1).ToUpper()
    [pscustomobject]@{ Path = $lib; Games = $acf.Count; SizeGB = GB $bytes; OnShared = $shared.Contains($dl); IsSteamFolder = ($lib -ieq $steamDir.TrimEnd('\')) }
  })

# ---------- network and software ----------
$nic = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue | Where-Object { $_.DefaultIPGateway } | Select-Object -First 1)
$ip = Get-LanIP
$dhcp = if ($nic) { [bool]$nic[0].DHCPEnabled } else { $false }
$gw = if ($nic) { "$(@($nic[0].DefaultIPGateway)[0])" } else { '' }
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$node = ''; if (Get-Command node -ErrorAction SilentlyContinue) { $node = "$(& node --version 2>$null)".Trim() }
$csc = Test-Path -LiteralPath "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

# ---------- the suggestion ----------
# OSYNC (launchers, menu, the main GAME folder) on a drive the clients see, never the system drive:
#   1 the drive of an OSYNC that is already there   2 the drive that already holds the most Steam games (no moving)
#   3 an SSD with at least 200 GB free (the fastest)  4 the shared drive with the most free space
$cand = @($drives | Where-Object { $_.Shared -and -not $_.System })
$pick = $null; $why = ''
if ($existing) { $pick = $cand | Where-Object { $_.Letter -eq $existing[0].Substring(0, 1).ToUpper() } | Select-Object -First 1; if ($pick) { $why = "OSYNC is already on this drive ($($existing[0]))" } }
if (-not $pick) {
  $byGames = @($steamLibs | Where-Object { $_.OnShared -and $_.SizeGB -ge 50 } | Group-Object { $_.Path.Substring(0, 1).ToUpper() } | ForEach-Object { [pscustomobject]@{ L = $_.Name; GB = ($_.Group | Measure-Object SizeGB -Sum).Sum } } | Sort-Object GB -Descending)
  if ($byGames) { $pick = $cand | Where-Object { $_.Letter -eq $byGames[0].L -and $_.FreeGB -ge 50 } | Select-Object -First 1; if ($pick) { $why = "it already holds the most Steam games ($($byGames[0].GB) GB) - they stay where they are" } }
}
if (-not $pick) { $pick = $cand | Where-Object { $_.Media -match 'SSD' -and $_.FreeGB -ge 200 } | Sort-Object FreeGB -Descending | Select-Object -First 1; if ($pick) { $why = "an SSD the clients see, with the most free space ($($pick.FreeGB) GB)" } }
if (-not $pick) { $pick = $cand | Sort-Object FreeGB -Descending | Select-Object -First 1; if ($pick) { $why = "the drive the clients see with the most free space ($($pick.FreeGB) GB)" } }
$osyncRoot = if ($existing) { $existing[0] } elseif ($pick) { "$($pick.Letter):\OSYNC" } else { '' }
# more game folders: other shared drives with room (each gets X:\GAME, the admin console scans them too)
$more = @($cand | Where-Object { $pick -and $_.Letter -ne $pick.Letter -and $_.FreeGB -ge 100 } | ForEach-Object { "$($_.Letter):\GAME" })

# ---------- print ----------
Out "OSYNC plan for $env:COMPUTERNAME   $(Get-Date -Format 'yyyy-MM-dd HH:mm')   (read only - nothing was changed)" 'Cyan'
Out ''
Out '1. This PC' 'Yellow'
Out ("   Windows: {0} build {1}   PowerShell {2}   admin: {3}" -f "$($os.Caption)".Trim(), $os.BuildNumber, $PSVersionTable.PSVersion.ToString(), (Test-Admin))
Out ("   diskless server: {0}" -f $(if ($server) { $server } else { 'NOT FOUND - is this the master? (LW, CCBoot, iCafeCloud, NxD, ggRock are known)' }))
Out ("   network: IP {0}   gateway {1}   {2}" -f $(if ($ip) { $ip } else { '?' }), $(if ($gw) { $gw } else { '?' }), $(if ($dhcp) { 'DHCP - give the master a FIXED IP (clients and the firewall rule use it)' } else { 'fixed IP' }))
Out ("   Node.js: {0}   .NET 4 compiler: {1}" -f $(if ($node) { $node } else { 'not installed (only needed to build the menu from source / read LW''s disk list)' }), $(if ($csc) { 'yes' } else { 'no' }))
Out ''
Out "2. Drives (clients see: $(if ($shared) { $shared } else { '?' }) - $how)" 'Yellow'
Out '   drive  size GB  free GB  type            clients  name'
foreach ($d in $drives) {
  $tag = if ($d.System) { 'system - nothing for clients goes here' } elseif ($d.Shared) { 'yes' } else { 'NO' }
  Out ("   {0}:     {1,7}  {2,7}  {3,-15} {4,-7}  {5}" -f $d.Letter, $d.SizeGB, $d.FreeGB, $d.Media, $tag, $d.Label)
}
foreach ($d in $drives | Where-Object { $_.Shared -and $_.SizeGB -gt 0 -and ($_.FreeGB / $_.SizeGB) -lt 0.1 }) { Out "   ! $($d.Letter): has less than 10% free - games cannot update well" 'Yellow' }
Out ''
Out '3. Launchers' 'Yellow'
if (-not $launch) { Out '   none installed yet - install the ones the shop needs (Steam, Riot, Epic, EA ...) after OSYNC; setup step 2 puts them in Launchers\' }
foreach ($l in $launch) {
  $st = if ($l.InOsync) { 'OK (in OSYNC\Launchers)' } elseif ($l.OnSystem) { 'MOVE: on the system drive, clients cannot use it - first-time setup step 2 moves it into OSYNC\Launchers' } elseif (-not $l.OnShared) { 'MOVE: on a drive the clients do not see - step 2 moves it' } else { 'clients can use it here; step 2 offers to move it into OSYNC\Launchers (optional)' }
  Out ("   {0,-22} {1}" -f $l.Title, $l.Path)
  Out ("   {0,-22} -> {1}" -f '', $st)
}
Out ''
Out '4. Steam games' 'Yellow'
if (-not $steamLibs) { Out '   no Steam library found' }
foreach ($s in $steamLibs) {
  $st = if (-not $s.Games) { 'empty' } elseif (-not $s.OnShared) { 'NOT SEEN BY CLIENTS - move these games to a library on a shared drive (Steam > Settings > Storage > Move)' } elseif ($s.IsSteamFolder -and $s.Games) { 'inside the Steam folder: fine; tidier in OSYNC\GAME\Steam (Tools > 2)' } else { 'OK, stays where it is' }
  Out ("   {0,-40} {1,4} games {2,6} GB   {3}" -f $s.Path, $s.Games, $s.SizeGB, $st)
}
Out ''
Out '5. Suggested placement' 'Green'
if ($osyncRoot) {
  Out "   OSYNC folder:   $osyncRoot      ($why)"
  Out "   launchers:      $osyncRoot\Launchers\<name>   (Steam, Riot Client, EA, Epic ...)"
  Out "   new games:      $osyncRoot\GAME\<launcher>    (Steam: add $osyncRoot\GAME\Steam as a library and make it the default)"
  if ($more) { Out "   more game room: $($more -join ', ')   (only if games go there: admin console > game folders, or Settings GameFolders)" }
  Out "   game menu:      $osyncRoot\Menu   shop tools: $osyncRoot\Tools   settings: $osyncRoot\Settings\settings.txt"
  Out "   never on ${sys}:     anything a client PC must open (clients do not see the master's system drive)"
} else { Out '   no drive the client PCs see was found: add a game disk in the diskless server first, then run this again' 'Red' }
if ($existing) { Out "   OSYNC is already installed at $($existing -join ', ') - the setup updates it (Settings and games stay)" 'Cyan' }
if (-not $server) { Out '   ! no diskless server program on this PC: run the setup on the MASTER (the PC with the diskless server)' 'Yellow' }
if ($dhcp) { Out '   ! fixed IP for the master first (router or Windows network settings)' 'Yellow' }

if ($OutFile) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null; [IO.File]::WriteAllLines($OutFile, [string[]]$lines, (New-Object Text.UTF8Encoding $true)) }
if ($PassThru) {
  [pscustomobject]@{ OsyncRoot = $osyncRoot; Why = $why; SharedDrives = $shared; SharedHow = $how; MoreGameFolders = $more; Existing = $existing; Server = $server; IP = $ip; Dhcp = $dhcp; Drives = $drives; Launchers = $launch; SteamLibraries = $steamLibs; Text = ($lines -join "`r`n") }
}
