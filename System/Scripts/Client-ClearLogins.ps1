# Client-ClearLogins.ps1 - CLIENT PC: sign every user of this PC out of the game launchers (Clear-Logins.bat, and
# Client-Install step 1i at every boot). Deleted = only saved logins / sign-in cookies; games, game settings (GTA graphics),
# saves and the launchers themselves stay:
#   FiveM / RedM : <FiveM|RedM>.app\data\nui-storage, cache\browser (Cfx.re sign-in) and in game-storage ONLY the Rockstar
#                  sign-in (ros_profiles, *\Profiles, settings_user.dat, logs, game_profiles, signintransfer.dat; 18 Nov 2026: the GTA files FiveM downloaded there and
#                  server-cache / server-cache-priv = the servers' files, fetched once on the master, stay for every client) -
#                  next to FiveM on the game disk and in a per-user install (AppData\Local\FiveM)
#   Rockstar     : Documents\Rockstar Games\Social Club + Launcher, AppData\Local\Rockstar Games\Launcher + Social Club,
#                  AppData\Local\DigitalEntitlements
#                  (Documents\Rockstar Games\GTA V / Red Dead Redemption 2 = settings and saves: kept)
#   Steam        : AppData\Local\Steam\local.vdf (saved sign-in) + htmlcache
#   Epic         : EpicGamesLauncher\Saved\Config\Windows*\GameUserSettings.ini (RememberMe) + Saved\webcache*
#   EA app       : Electronic Arts\EA Desktop\cookie.ini, user_*.ini, CEF
#   Riot         : Riot Games\Riot Client\Data\*PrivateSettings.yaml
#   Ubisoft      : Ubisoft Game Launcher\user.dat, ConnectSecureStorage.dat
#   Battle.net   : AppData\Local\Battle.net\BrowserCaches, SavedAccountNames in Battle.net.config, registry WEB_TOKEN*
#   Garena       : ProgramData\Garena\gxx\cache\login, cache\cef, user (gxx.dat = settings / game folders: kept)
#   HoYoPlay     : AppData\Roaming\<Cognosphere|miHoYo>\HYP\*\fedata + games' registry MIHOYOSDK_ADL* (account cache)
#   Discord      : AppData\Roaming\discord*\Local Storage, Session Storage, Network, WebStorage
# Every user profile of the PC + the Default profile. A user who is not logged on: the registry part loads the user's
# NTUSER.DAT for a moment. Never on the master (the shop's own logins live there).
# Clear-Logins.bat (no -Boot): closes those launchers / games first. -Boot: closes nothing (Riot already starting at logon
# stays), a file in use is left and reported.
# -CheckOnly: only list what would be deleted. -TestDir <folder>: <folder>\profile = the only user, <folder>\FiveM.app =
# the only FiveM, registry = HKCU\Software\OSYNC-ClearLogins-Test (tests on the master).
param([switch]$CheckOnly, [switch]$Boot, [string]$TestDir)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir -and -not $CheckOnly) { Write-Host 'Clear logins: this is the master - nothing deleted here (the shop''s own logins)'; exit 0 }
if (-not $TestDir -and -not $CheckOnly -and -not (Test-Admin)) { Write-Host 'Clear logins: run as administrator (Clear-Logins.bat asks for it).' -ForegroundColor Red; exit 1 }

$script:found = 0; $script:deleted = 0; $script:failed = 0; $script:inUse = 0
function Say([string]$s, [string]$c = 'Gray') { Write-Host "  $s" -ForegroundColor $c }

# ---------- what goes ----------
# per profile: base = Local | Roaming | Docs | Profile, path relative to it (wildcards allowed in the last part)
$ProfileTargets = @(
  @('Rockstar', 'Docs', 'Rockstar Games\Social Club'), @('Rockstar', 'Docs', 'Rockstar Games\Launcher'),
  @('Rockstar', 'Local', 'Rockstar Games\Launcher'), @('Rockstar', 'Local', 'Rockstar Games\Social Club'),
  @('Rockstar', 'Local', 'DigitalEntitlements'),
  @('Steam', 'Local', 'Steam\local.vdf'), @('Steam', 'Local', 'Steam\htmlcache'),
  @('Epic', 'Local', 'EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini'),
  @('Epic', 'Local', 'EpicGamesLauncher\Saved\Config\WindowsEditor\GameUserSettings.ini'),
  @('Epic', 'Local', 'EpicGamesLauncher\Saved\webcache*'),
  @('EA', 'Local', 'Electronic Arts\EA Desktop\cookie.ini'), @('EA', 'Local', 'Electronic Arts\EA Desktop\user_*.ini'),
  @('EA', 'Local', 'Electronic Arts\EA Desktop\CEF'),
  @('Riot', 'Local', 'Riot Games\Riot Client\Data\*PrivateSettings.yaml'),
  @('Ubisoft', 'Local', 'Ubisoft Game Launcher\user.dat'), @('Ubisoft', 'Local', 'Ubisoft Game Launcher\ConnectSecureStorage.dat'),
  @('Battle.net', 'Local', 'Battle.net\BrowserCaches'),
  @('HoYoPlay', 'Roaming', 'Cognosphere\HYP\*\fedata'), @('HoYoPlay', 'Roaming', 'miHoYo\HYP\*\fedata'),
  @('FiveM', 'Local', 'FiveM\FiveM.app\data\nui-storage'), @('FiveM', 'Local', 'FiveM\FiveM.app\data\game-storage\ros_profiles'),
  @('FiveM', 'Local', 'FiveM\FiveM.app\data\game-storage\game_profiles'), @('FiveM', 'Local', 'FiveM\FiveM.app\data\game-storage\signintransfer.dat'),
  @('FiveM', 'Local', 'FiveM\FiveM.app\data\cache\browser'),
  @('RedM', 'Local', 'RedM\RedM.app\data\nui-storage'), @('RedM', 'Local', 'RedM\RedM.app\data\game-storage\ros_profiles'),
  @('RedM', 'Local', 'RedM\RedM.app\data\game-storage\game_profiles'), @('RedM', 'Local', 'RedM\RedM.app\data\game-storage\signintransfer.dat'),
  @('RedM', 'Local', 'RedM\RedM.app\data\cache\browser')
)
foreach ($d in 'discord', 'discordptb', 'discordcanary') {
  foreach ($s in 'Local Storage', 'Session Storage', 'Network', 'WebStorage') { $ProfileTargets += , @('Discord', 'Roaming', "$d\$s") }
}
# FiveM / RedM folders on the game disk: login data a customer leaves in <name>.app\data (this PC's copy)
# game-storage: only the Rockstar sign-in (profiles, sign-in transfer, user settings, logs) - its GTA update files (GBs,
# downloaded once on the master), Social Club itself (ros_<n>\socialclub.dll) and the launcher's machine data (ros_launcher_data_*:
# which titles are installed) stay: without them FiveM says "Rockstar Games Launcher could not be found" (18 Nov 2026)
$CfxDataTargets = 'data\nui-storage', 'data\cache\browser', 'data\game-storage\ros_profiles', 'data\game-storage\game_profiles', 'data\game-storage\signintransfer.dat', 'data\game-storage\ros_documents_*\Profiles', 'data\game-storage\ros_launcher_documents_*\Profiles', 'data\game-storage\ros_launcher_appdata_*\settings_user.dat', 'data\game-storage\ros_documents_*\*.log', 'data\game-storage\ros_launcher_documents_*\*.log'
# the whole PC (not per user)
$MachineTargets = @(
  @('Garena', (Join-Path $env:ProgramData 'Garena\gxx'), 'cache\login'), @('Garena', (Join-Path $env:ProgramData 'Garena\gxx'), 'cache\cef'),
  @('Garena', (Join-Path $env:ProgramData 'Garena\gxx'), 'user')
)
# running programs closed before deleting (not with -Boot); services (session 0) are never touched
$ProcNames = '^(FiveM|RedM)|^(GTA5|GTA5_Enhanced|PlayGTAV|RDR2|PlayRDR2|SocialClubHelper|LauncherPatcher|RockstarErrorHandler|steam|steamwebhelper|EpicGamesLauncher|EpicWebHelper|EADesktop|EACefSubProcess|RiotClientServices|RiotClientUx|RiotClientUxRender|Riot Client|LeagueClient|LeagueClientUx|LeagueClientUxRender|upc|UplayWebCore|UbisoftConnect|Battle\.net|Garena|gxxcef|HYP|Discord|DiscordPTB|DiscordCanary)$'
$ProcByPath = @{ 'Launcher' = '(?i)Rockstar'; 'Agent' = '(?i)Battle\.net'; 'Update' = '(?i)\\discord' }

# ---------- helpers ----------
function Test-Under([string]$path, [string]$base) {
  $p = [IO.Path]::GetFullPath($path).TrimEnd('\'); $b = [IO.Path]::GetFullPath($base).TrimEnd('\')
  $p.Length -gt ($b.Length + 1) -and $p.StartsWith($b + '\', [StringComparison]::OrdinalIgnoreCase)
}
# delete one file / folder (folder: links inside are removed, never followed)
function Remove-One([string]$path, [string]$what) {
  $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  if (-not $item) { return }
  $script:found++
  if ($CheckOnly) { Say "would delete  [$what] $path"; return }
  try {
    if ($item.PSIsContainer) {
      try { [IO.Directory]::Delete($item.FullName, $true) }
      catch {
        Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }
        [IO.Directory]::Delete($item.FullName, $true)
      }
    } else {
      if ($item.IsReadOnly) { $item.IsReadOnly = $false }
      [IO.File]::Delete($item.FullName)
    }
    $script:deleted++; Say "deleted  [$what] $path" 'Green'
  } catch {
    $msg = $_.Exception.InnerException.Message; if (-not $msg) { $msg = $_.Exception.Message }
    if ($msg -match '(?i)being used|in use|access') { $script:inUse++ } else { $script:failed++ }
    Say "NOT deleted  [$what] $path ($msg)" 'Yellow'
  }
}
# base folder + relative path with a wildcard in any part (e.g. HYP\*\fedata) -> every match under base
function Remove-Rel([string]$base, [string]$rel, [string]$what) {
  if (-not $base -or -not (Test-Path -LiteralPath $base)) { return }
  $parts = $rel -split '\\'
  $cur = @($base)
  for ($i = 0; $i -lt $parts.Count; $i++) {
    $next = New-Object System.Collections.Generic.List[string]
    foreach ($c in $cur) {
      if ($parts[$i] -match '[\*\?]') { Get-ChildItem -LiteralPath $c -Filter $parts[$i] -Force -ErrorAction SilentlyContinue | ForEach-Object { $next.Add($_.FullName) } }
      else { $p = Join-Path $c $parts[$i]; if (Test-Path -LiteralPath $p) { $next.Add($p) } }
    }
    $cur = $next
  }
  foreach ($p in $cur) { if (Test-Under $p $base) { Remove-One $p $what } }
}
# user profiles (ProfileList S-1-5-21-*) + Default
function Get-Profiles {
  $list = New-Object System.Collections.Generic.List[object]
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
  foreach ($k in @(Get-ChildItem -LiteralPath $pl -ErrorAction SilentlyContinue)) {
    $sid = $k.PSChildName
    if ($sid -notmatch '^S-1-5-21-[\d-]+$') { continue }
    $p = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath)")
    if ($p -and (Test-Path -LiteralPath $p)) { $list.Add([pscustomobject]@{ Name = (Split-Path -Leaf $p); Path = $p; Sid = $sid }) }
  }
  $def = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $pl -ErrorAction SilentlyContinue).Default)")
  if (-not $def) { $def = Join-Path $env:SystemDrive 'Users\Default' }
  if (Test-Path -LiteralPath $def) { $list.Add([pscustomobject]@{ Name = 'Default'; Path = $def; Sid = '' }) }
  $list
}
# Documents / Local / Roaming of a profile: the user's own folder setting when the user is logged on, else the usual place
function Get-UserFolder($prof, [string]$name, [string]$fallback) {
  if ($prof.Sid) {
    # read the value NOT expanded: expanded here (SYSTEM at boot) %USERPROFILE% would be the system profile
    $v = $null
    $rk = [Microsoft.Win32.Registry]::Users.OpenSubKey("$($prof.Sid)\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", $false)
    if ($rk) { try { $v = $rk.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } finally { $rk.Close() } }
    if ($v) {
      $v = [Environment]::ExpandEnvironmentVariables(("$v" -replace '(?i)%USERPROFILE%', $prof.Path.Replace('$', '$$')))
      if ($v -match '^[A-Za-z]:\\' -and $v -notlike "$env:SystemRoot\*" -and (Test-Path -LiteralPath (Split-Path -Qualifier $v))) { return $v }
    }
  }
  Join-Path $prof.Path $fallback
}
# registry of one user (an open RegistryKey = the user's HKCU): saved sign-in values
function Clear-UserRegistry($hk, [string]$who) {
  # HoYoverse games keep the signed-in account in MIHOYOSDK_ADL_* values; Battle.net keeps WEB_TOKEN under Launch Options
  $rules = @(@('HoYoPlay', 'Software\Cognosphere', '^MIHOYOSDK_ADL'), @('HoYoPlay', 'Software\miHoYo', '^MIHOYOSDK_ADL'),
             @('Battle.net', 'Software\Blizzard Entertainment\Battle.net\Launch Options', '^WEB_TOKEN'))
  foreach ($r in $rules) {
    $parent = $hk.OpenSubKey($r[1], $false)
    if (-not $parent) { continue }
    $subs = @($parent.GetSubKeyNames()); $parent.Close()
    foreach ($s in $subs) {
      $path = "$($r[1])\$s"
      $k = $hk.OpenSubKey($path, (-not $CheckOnly))
      if (-not $k) { continue }
      try {
        foreach ($v in @($k.GetValueNames() | Where-Object { $_ -match $r[2] })) {
          $script:found++
          if ($CheckOnly) { Say "would delete  [$($r[0])] $who registry $path : $v" }
          else { try { $k.DeleteValue($v); $script:deleted++; Say "deleted  [$($r[0])] $who registry $path : $v" 'Green' } catch { $script:failed++; Say "NOT deleted  [$($r[0])] $who registry $path : $v ($($_.Exception.Message))" 'Yellow' } }
        }
      } finally { $k.Close() }
    }
  }
}
# Battle.net.config: empty SavedAccountNames (the e-mails offered at sign-in), the rest of the settings stay
function Clear-BnetConfig([string]$file, [string]$who) {
  if (-not (Test-Path -LiteralPath $file)) { return }
  $t = [IO.File]::ReadAllText($file)
  $re = '("SavedAccountNames"\s*:\s*)"[^"]+"'
  if ($t -notmatch $re) { return }
  $script:found++
  if ($CheckOnly) { Say "would empty  [Battle.net] $who SavedAccountNames in $file"; return }
  try { [IO.File]::WriteAllText($file, ([regex]::Replace($t, $re, '$1""')), (New-Object Text.UTF8Encoding($false))); $script:deleted++; Say "emptied  [Battle.net] $who SavedAccountNames in $file" 'Green' }
  catch { $script:failed++; Say "NOT emptied  [Battle.net] $file ($($_.Exception.Message))" 'Yellow' }
}

# ---------- 1. close the launchers / games ----------
Write-Host "Clear logins on $env:COMPUTERNAME$(if ($CheckOnly) { ' (check only - nothing deleted)' })" -ForegroundColor Cyan
if (-not $Boot -and -not $TestDir) {
  $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
      $_.SessionId -ne 0 -and ($_.ProcessName -match $ProcNames -or ($ProcByPath.ContainsKey($_.ProcessName) -and "$($_.Path)" -match $ProcByPath[$_.ProcessName])) })
  if ($procs.Count) {
    $names = ($procs | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
    if ($CheckOnly) { Say "would close: $names" }
    else { Say "closing: $names"; $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
  }
}

# ---------- 2. every user ----------
$profiles = if ($TestDir) { @([pscustomobject]@{ Name = 'test'; Path = (Join-Path $TestDir 'profile'); Sid = '' }) } else { @(Get-Profiles) }
$n = 0
foreach ($p in $profiles) {
  $base = @{
    Profile = $p.Path
    Docs    = (Get-UserFolder $p 'Personal' 'Documents')
    Local   = (Get-UserFolder $p 'Local AppData' 'AppData\Local')
    Roaming = (Get-UserFolder $p 'AppData' 'AppData\Roaming')
  }
  foreach ($t in $ProfileTargets) { Remove-Rel $base[$t[1]] $t[2] "$($t[0]) $($p.Name)" }
  Clear-BnetConfig (Join-Path $base.Roaming 'Battle.net\Battle.net.config') $p.Name
  # registry: the logged-on user's hive, else load NTUSER.DAT for a moment (not in check-only)
  if ($TestDir) {
    $hk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\OSYNC-ClearLogins-Test', $false)
    if ($hk) { try { Clear-UserRegistry $hk $p.Name } finally { $hk.Close() } }
  } elseif ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)")) {
    $hk = [Microsoft.Win32.Registry]::Users.OpenSubKey($p.Sid, $false)
    if ($hk) { try { Clear-UserRegistry $hk $p.Name } finally { $hk.Close() } }
  } elseif (-not $CheckOnly) {
    $dat = Join-Path $p.Path 'NTUSER.DAT'
    if (Test-Path -LiteralPath $dat) {
      $mount = "OSYNC_CL_$n"; $n++
      & reg.exe load "HKU\$mount" "$dat" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        try { $hk = [Microsoft.Win32.Registry]::Users.OpenSubKey($mount, $false); if ($hk) { try { Clear-UserRegistry $hk $p.Name } finally { $hk.Close() } } }
        finally { [GC]::Collect(); [GC]::WaitForPendingFinalizers(); & reg.exe unload "HKU\$mount" 2>$null | Out-Null }
      } else { Say "registry of $($p.Name): could not load NTUSER.DAT - skipped" 'DarkYellow' }
    }
  } else { Say "registry of $($p.Name): not checked (user not logged on)" 'DarkGray' }
}

# ---------- 3. FiveM / RedM on the game disk (this PC's copy) + the whole PC ----------
$cfx = if ($TestDir) { @([pscustomobject]@{ Name = 'FiveM'; App = (Join-Path $TestDir 'FiveM.app') }) } else { @(Get-CfxApps) }
foreach ($c in $cfx) { foreach ($t in $CfxDataTargets) { Remove-Rel $c.App $t "$($c.Name) game disk" } }
if (-not $TestDir) { foreach ($t in $MachineTargets) { Remove-Rel $t[1] $t[2] $t[0] } }

$sum = if ($CheckOnly) { "Clear logins: $($script:found) item(s) would be deleted" } else { "Clear logins: $($script:deleted) deleted$(if ($script:inUse) { ", $($script:inUse) in use (left)" })$(if ($script:failed) { ", $($script:failed) FAILED" })$(if (-not $script:found) { ' - nothing saved, already clean' })" }
Write-Host $sum -ForegroundColor $(if ($script:failed) { 'Red' } elseif ($script:inUse) { 'Yellow' } else { 'Green' })
if ($script:failed) { exit 1 }
exit 0
