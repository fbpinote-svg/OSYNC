# Client-DesktopClean.ps1 - CLIENT PC: the desktop shows ONLY the game menu icon (17 Nov 2026, owner's choice).
# Every shortcut (.lnk / .url / .appref-ms) on the Public Desktop and on each user's desktop (+ the Default profile = new users)
# that is not the game menu is MOVED to C:\ProgramData\OSYNC\DesktopRemoved\<user>\ - nothing is deleted (and a diskless boot
# starts from the image again anyway). Other files and folders on the desktop are left alone.
# Client-Install step 8 runs it at every boot and in image mode, AFTER the steps whose installers add icons (WO Mic, Parsec ...).
# Setting ClientDesktopMenuOnly=off skips it.
# 18 Nov 2026 (the owner): the menu games listed in Settings ClientDesktopIcons (menu game ids, comma separated, e.g.
# app-discordptb,fivem,launcher-steam,launcher-rockstar,launcher-roblox) get an icon on the Public Desktop (= every user),
# made fresh from Menu\data\games.json (same program + arguments as the menu card). Our own icons carry the description
# below: they are kept, and removed again when their id leaves the setting.
#   -CheckOnly          list what would be moved, move nothing
#   -TestDir <folder>   only <folder>\Public\Desktop and <folder>\Users\<name>\Desktop; backup in <folder>\Removed (testing, also on the master)
param([switch]$CheckOnly, [string]$TestDir)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir) { Write-Host 'this is the master - its desktop is left alone'; exit 0 }

$mi = Get-MenuInfo
$sh = New-Object -ComObject WScript.Shell
$kinds = '.lnk', '.url', '.appref-ms'
$IconTag = 'OSYNC desktop icon (Settings ClientDesktopIcons)'
$wantIds = @((Get-Setting 'ClientDesktopIcons' '') -split '[,; ]+' | Where-Object { $_ })
function Test-OwnIcon($f) {
  if ($f.Extension -ne '.lnk') { return $false }
  try { ($sh.CreateShortcut($f.FullName)).Description -eq $IconTag } catch { $false }
}
# the game menu's own shortcut (Client-Menu.ps1): its names now and before, or anything that starts the menu
function Test-MenuShortcut($f) {
  if ($mi.Names -contains $f.BaseName) { return $true }
  if ($f.Extension -ne '.lnk') { return $false }
  try { $s = $sh.CreateShortcut($f.FullName) } catch { return $false }
  ($s.TargetPath -match '\\(GCafe|Menu)\\app\\[^\\]+\.exe$') -or ($s.TargetPath -like '*\System\Client\Menu.vbs') -or ($s.Arguments -like '*\System\Client\Menu.vbs*')
}

# desktops: Public + every user profile (its own Desktop folder setting when the hive is loaded) + Default
$desks = New-Object System.Collections.Generic.List[object]
if ($TestDir) {
  $desks.Add([pscustomobject]@{ Name = 'Public'; Path = (Join-Path $TestDir 'Public\Desktop') })
  foreach ($u in @(Get-ChildItem -LiteralPath (Join-Path $TestDir 'Users') -Directory -ErrorAction SilentlyContinue)) { $desks.Add([pscustomobject]@{ Name = $u.Name; Path = (Join-Path $u.FullName 'Desktop') }) }
  $backupRoot = Join-Path $TestDir 'Removed'
} else {
  $desks.Add([pscustomobject]@{ Name = 'Public'; Path = [Environment]::GetFolderPath('CommonDesktopDirectory') })
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
  foreach ($k in @(Get-ChildItem -LiteralPath $pl -ErrorAction SilentlyContinue)) {
    $sid = $k.PSChildName
    if ($sid -notmatch '^S-1-5-21-[\d-]+$') { continue }
    $p = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath)")
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
    $d = Join-Path $p 'Desktop'
    # read the value NOT expanded: expanded here (SYSTEM at boot) %USERPROFILE% would be the system profile
    $rk = [Microsoft.Win32.Registry]::Users.OpenSubKey("$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", $false)
    if ($rk) {
      try { $v = $rk.GetValue('Desktop', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } finally { $rk.Close() }
      if ($v) { $v = [Environment]::ExpandEnvironmentVariables(("$v" -replace '(?i)%USERPROFILE%', $p.Replace('$', '$$'))); if ($v -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $v)) { $d = $v } }
    }
    $desks.Add([pscustomobject]@{ Name = (Split-Path -Leaf $p); Path = $d })
  }
  $def = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $pl -ErrorAction SilentlyContinue).Default)")
  if (-not $def) { $def = Join-Path $env:SystemDrive 'Users\Default' }
  $desks.Add([pscustomobject]@{ Name = 'Default'; Path = (Join-Path $def 'Desktop') })
  $backupRoot = Join-Path $env:ProgramData 'OSYNC\DesktopRemoved'
}

$moved = 0; $kept = 0; $fail = 0; $seen = @{}
foreach ($d in $desks) {
  if (-not $d.Path -or -not (Test-Path -LiteralPath $d.Path) -or $seen[$d.Path.ToLower()]) { continue }
  $seen[$d.Path.ToLower()] = $true
  foreach ($f in @(Get-ChildItem -LiteralPath $d.Path -File -Force -ErrorAction SilentlyContinue | Where-Object { $kinds -contains $_.Extension.ToLower() })) {
    if (Test-MenuShortcut $f) { $kept++; Write-Host "  keep  $($d.Name): $($f.Name) (game menu)"; continue }
    if (Test-OwnIcon $f) { continue }      # one of ours (ClientDesktopIcons): made / removed below
    if ($CheckOnly) { Write-Host "  would move $($d.Name): $($f.Name)"; $moved++; continue }
    try {
      $dest = Join-Path $backupRoot $d.Name
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Move-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $f.Name) -Force
      Write-Host "  moved $($d.Name): $($f.Name)"; $moved++
    } catch { Write-Host "  FAILED $($d.Name): $($f.Name) ($($_.Exception.Message))"; $fail++ }
  }
}
# the owner's desktop icons (ClientDesktopIcons), on the Public Desktop
$pub = if ($TestDir) { Join-Path $TestDir 'Public\Desktop' } else { [Environment]::GetFolderPath('CommonDesktopDirectory') }
$made = @()
if ($wantIds.Count) {
  $parsed = try { Get-Content -LiteralPath (Join-Path $Menu 'data\games.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json } catch { $null }
  $games = @($parsed | ForEach-Object { $_ })     # PS 5.1 hands the JSON array over as ONE object: unroll it
  foreach ($id in $wantIds) {
    $g = $games | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $g) { Write-Host "  icon  ${id}: not in the game menu list - skipped"; continue }
    $m = [regex]::Match("$($g.cmd)", '^\s*(?:"([^"]+)"|(\S+))\s*(.*)$')
    $exe = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
    $arg = $m.Groups[3].Value
    if ($exe -and $exe -notmatch '\\') { $sys = Join-Path $env:SystemRoot "System32\$exe"; if (Test-Path -LiteralPath $sys) { $exe = $sys } }
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { Write-Host "  icon  ${id}: $exe not on this PC - skipped"; continue }
    $icon = $exe
    if ($id -eq 'launcher-roblox') { $r = Get-RobloxExe; if ($r) { $icon = $r } }
    $name = (("$($g.title)" -replace '\s*\([^)]*\)\s*$', '') -replace '[\\/:*?"<>|]', '').Trim()
    if (-not $name) { $name = $id }
    $made += "$name.lnk"
    if ($CheckOnly) { Write-Host "  would make icon: $name -> $exe $arg"; continue }
    try {
      New-Item -ItemType Directory -Force -Path $pub | Out-Null
      $s = $sh.CreateShortcut((Join-Path $pub "$name.lnk"))
      $s.TargetPath = $exe; $s.Arguments = $arg; $s.Description = $IconTag; $s.IconLocation = "$icon,0"
      $s.WorkingDirectory = $(if ($g.cwd) { "$($g.cwd)" } else { Split-Path -Parent $exe })
      $s.Save()
      Write-Host "  icon  $name -> $exe $arg"
    } catch { Write-Host "  FAILED icon $name ($($_.Exception.Message))"; $fail++ }
  }
}
foreach ($d in $desks) {
  if (-not $d.Path -or -not (Test-Path -LiteralPath $d.Path)) { continue }
  foreach ($f in @(Get-ChildItem -LiteralPath $d.Path -Filter '*.lnk' -File -Force -ErrorAction SilentlyContinue)) {
    if (-not (Test-OwnIcon $f) -or ($d.Path -ieq $pub -and $made -contains $f.Name)) { continue }
    if ($CheckOnly) { Write-Host "  would remove old icon $($d.Name): $($f.Name)"; continue }
    try { Remove-Item -LiteralPath $f.FullName -Force; Write-Host "  removed old icon $($d.Name): $($f.Name) (not in ClientDesktopIcons)" } catch { $fail++ }
  }
}
Write-Host ("Desktop: only the game menu - {0} shortcut(s) {1} to {2}, {3} game menu icon(s) kept, {4} desktop icon(s) from ClientDesktopIcons{5}" -f $moved, $(if ($CheckOnly) { 'would be moved' } else { 'moved' }), $backupRoot, $kept, $made.Count, $(if ($fail) { ", $fail FAILED" } else { '' }))
if (-not $kept -and -not $TestDir) { Write-Host '  note: no game menu icon on the desktop yet - OSYNC.bat client (image mode) puts it there' }
if ($fail) { exit 1 }
exit 0
