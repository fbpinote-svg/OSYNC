# Move-Launcher.ps1 - move an installed game launcher into GAMELUNCHER (real move, nothing left behind).
# Works on any master: the current install folder is read from the launcher's own registry/config.
# Run from an ELEVATED Windows PowerShell (Master-Move\Move-*.bat does that):
#   Move-Launcher.ps1 -Launcher <name> -DryRun     show what would change
#   Move-Launcher.ps1 -Launcher <name>             do it
#   <name> = Riot | EA | Epic | Rockstar | Garena | Ubisoft | HoYoPlay | Modrinth
#   -OldPath <folder>   override the detected install folder
# Steps: stop launcher -> copy+verify (other drive) or rename (same drive) -> repoint registry/services/
#        scheduled tasks/shortcuts/config -> remove old folder -> restart services that were running
# HoYoPlay: games inside HoYoPlay\games go to <drive>:\Mobile\<game>\ (GAMELUNCHER holds launchers only).
param([Parameter(Mandatory = $true)][ValidateSet('Riot', 'EA', 'Epic', 'Rockstar', 'Garena', 'Ubisoft', 'HoYoPlay', 'Modrinth')][string]$Launcher,
      [string]$OldPath, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Settings.ps1')
$gl = $KitRoot
function Say($m) { Write-Host $m }
function RegVal($k, $n) { try { (Get-ItemProperty -Path $k -ErrorAction Stop).$n } catch { $null } }
function Clean($p) { if ($p) { ($p -replace '/', '\').TrimEnd('\') } }
$run = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')

switch ($Launcher) {
  'Riot' {
    $old = $null
    $json = Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json'
    if (Test-Path $json) { try { $o = Get-Content $json -Raw | ConvertFrom-Json; if ($o.rc_default) { $old = Split-Path -Parent (Clean $o.rc_default) } } catch { } }
    if (-not $old) { $old = 'C:\Riot Games\Riot Client' }
    $new = Join-Path $gl 'RiotClient'
    $services = @(); $exes = @('RiotClientServices', 'Riot Client', 'RiotClientCrashHandler', 'RiotClientUx', 'RiotClientUxRender')
    $regRoots = @('HKLM:\SOFTWARE\Classes\riotclient', 'HKCU:\Software\Classes\riotclient') + $run
    $textFiles = @($json)
  }
  'EA' {
    $old = Clean (RegVal 'HKLM:\SOFTWARE\Electronic Arts\EA Desktop' 'InstallLocation')
    if (-not $old) { $old = 'C:\Program Files\Electronic Arts\EA Desktop' }
    $new = Join-Path $gl 'EA Desktop'
    $services = @('EABackgroundService'); $exes = @('EADesktop', 'EALauncher', 'EABackgroundService', 'EALocalHostSvc', 'EACefSubProcess', 'EAConnect_microsoft', 'ErrorReporter', 'Link2EA', 'OriginLegacyCLI', 'EAUpdater')
    $regRoots = @('HKLM:\SOFTWARE\Electronic Arts', 'HKLM:\SOFTWARE\WOW6432Node\Electronic Arts', 'HKLM:\SOFTWARE\Classes\origin', 'HKLM:\SOFTWARE\Classes\origin2',
                  'HKLM:\SOFTWARE\Classes\link2ea', 'HKLM:\SOFTWARE\Classes\ealink', 'HKLM:\SOFTWARE\Classes\eadm') + $run
    $textFiles = @()
  }
  'Epic' {
    $old = Clean (RegVal 'HKLM:\SOFTWARE\EpicGames\Unreal Engine' 'INSTALLDIR')
    if (-not $old) { $old = 'C:\Program Files\Epic Games' }
    $new = Join-Path $gl 'Epic Games'
    if ($old -match '\(x86\)') { $old = Join-Path $old 'Launcher'; $new = Join-Path $new 'Launcher' }   # keep Epic Online Services where it is
    $services = @('EpicGamesUpdater'); $exes = @('EpicGamesLauncher', 'EpicWebHelper', 'EpicGamesUpdater', 'UnrealCEFSubProcess')
    $regRoots = @('HKLM:\SOFTWARE\Classes\com.epicgames.launcher', 'HKLM:\SOFTWARE\WOW6432Node\EpicGames', 'HKLM:\SOFTWARE\EpicGames', 'HKCU:\Software\Epic Games') + $run
    $textFiles = @()
  }
  'Rockstar' {
    $old = Clean (RegVal 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Launcher' 'InstallFolder')
    if (-not $old) { $old = 'C:\Program Files\Rockstar Games\Launcher' }
    $new = Join-Path $gl 'Rockstar Games Launcher'
    $services = @('Rockstar Service'); $exes = @('LauncherPatcher', 'RockstarService', 'RockstarErrorHandler', 'PlayRDR2', 'PlayGTAV', 'RDR2', 'GTA5')
    $regRoots = @('HKLM:\SOFTWARE\Classes\rockstar', 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games') + $run
    $textFiles = @()
  }
  'Garena' {
    $exe = RegVal 'HKLM:\SOFTWARE\WOW6432Node\Garena\gxx' 'path'
    $old = if ($exe) { Split-Path -Parent (Clean $exe) } else { 'C:\Program Files (x86)\Garena\Garena' }
    $new = Join-Path $gl 'Garena'
    $services = @('GarenaPlatform'); $exes = @('Garena', 'gxxcef', 'gxxsvc')
    $regRoots = @('HKLM:\SOFTWARE\WOW6432Node\Garena', 'HKLM:\SOFTWARE\Garena', 'HKCU:\Software\Garena') + $run
    $textFiles = @()
  }
  'Ubisoft' {
    $dir = Clean (RegVal 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher' 'InstallDir')
    if (-not $dir) { $dir = 'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher' }
    $old = Split-Path -Parent $dir                                     # ...\Ubisoft = Game Launcher + Game Launcher Core
    if ((Split-Path -Leaf $old) -ne 'Ubisoft') { $old = $dir }
    $new = Join-Path $gl 'Ubisoft'
    $services = @('UpcElevationService'); $exes = @('UbisoftConnect', 'upc', 'UplayWebCore', 'UbisoftGameLauncher', 'UbisoftGameLauncher64', 'UplayService', 'UpcElevationService', 'UplayCrashReporter')
    $regRoots = @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft', 'HKLM:\SOFTWARE\Ubisoft', 'HKLM:\SOFTWARE\Classes\uplay', 'HKCU:\Software\Classes\uplay') + $run
    $textFiles = @()
  }
  'HoYoPlay' {
    $old = Clean (RegVal 'HKCU:\Software\Cognosphere\HYP\1_0' 'InstallPath')
    if (-not $old) { $old = 'C:\Program Files\HoYoPlay' }
    $new = Join-Path $gl 'HoYoPlay'
    $services = @(); $exes = @('HYP', 'HYPHelper')                    # launcher.exe is stopped by its path
    $regRoots = @('HKCU:\Software\Cognosphere', 'HKCU:\Software\Classes\HYP-global', 'HKCU:\Software\Classes\HYP-global-1-0') + $run
    $textFiles = @()
    $moveOut = @(Get-ChildItem -LiteralPath (Join-Path $old 'games') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      [pscustomobject]@{ From = $_.FullName; To = '{0}\Mobile\{1}\{2}' -f $old.Substring(0, 2), ($_.Name -replace '\s+game$', ''), $_.Name } })
  }
  'Modrinth' {
    $old = Clean ((RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Modrinth App' 'InstallLocation') -replace '"', '')
    if (-not $old) { $old = Join-Path $env:LOCALAPPDATA 'Modrinth App' }
    $new = Join-Path $gl 'Modrinth App'
    $services = @(); $exes = @('Modrinth App')
    $regRoots = @('HKCU:\Software\Classes\modrinth', 'HKCU:\Software\ModrinthApp') + $run
    $textFiles = @()
  }
}
if (-not $moveOut) { $moveOut = @() }
if ($OldPath) { $old = Clean $OldPath }
$oldF = $old -replace '\\', '/'; $newF = $new -replace '\\', '/'
$uninstRoots = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
function Repoint([string]$v) {
  foreach ($m in $moveOut) { $v = $v -ireplace [regex]::Escape($m.From), $m.To -ireplace [regex]::Escape(($m.From -replace '\\', '/')), ($m.To -replace '\\', '/') }
  $v -ireplace [regex]::Escape($old), $new -ireplace [regex]::Escape($oldF), $newF
}
function Has([string]$v) { $v -and ($v.IndexOf($old, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $v.IndexOf($oldF, [StringComparison]::OrdinalIgnoreCase) -ge 0) }

if ($old -ieq $new -or $old.StartsWith($gl + '\', [StringComparison]::OrdinalIgnoreCase)) { Say "$Launcher is already in GAMELUNCHER: $old"; return }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run from an elevated (Run as administrator) PowerShell.' }
$oldItem = Get-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
if (-not $oldItem) { throw "$Launcher not found at $old (install it first, or pass -OldPath)" }
if ($oldItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "$old is a link - already moved?" }
$rename = [IO.Path]::GetPathRoot($old) -ieq [IO.Path]::GetPathRoot($new)      # same drive: rename, no copy
if ($rename -and (Test-Path -LiteralPath $new)) { throw "$new already exists" }
foreach ($m in $moveOut) { if (Test-Path -LiteralPath $m.To) { throw "$($m.To) already exists" } }

# what refers to the old folder
$vals = @(); $keys = @()
foreach ($r in $regRoots) { if (Test-Path $r) { $keys += Get-Item $r; $keys += Get-ChildItem $r -Recurse -ErrorAction SilentlyContinue } }
foreach ($u in $uninstRoots) { Get-ChildItem $u -ErrorAction SilentlyContinue | ForEach-Object { $keys += $_ } }
foreach ($k in $keys) {
  foreach ($n in $k.GetValueNames()) {
    $kind = $k.GetValueKind($n)
    if ($kind -ne 'String' -and $kind -ne 'ExpandString') { continue }
    $v = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
    if (Has $v) { $vals += [pscustomobject]@{ Key = $k.Name; Name = $n; Kind = $kind; New = (Repoint $v) } } } }
$vals = @($vals | Sort-Object Key, Name -Unique)
$svcs = @(foreach ($s in $services) { Get-CimInstance Win32_Service -Filter "Name='$s'" -ErrorAction SilentlyContinue | Where-Object { Has $_.PathName } })
$sh = New-Object -ComObject WScript.Shell
$lnks = @(foreach ($d in 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\Public\Desktop', "$env:USERPROFILE\Desktop", "$env:APPDATA\Microsoft\Windows\Start Menu") {
  Get-ChildItem $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | Where-Object { Has $sh.CreateShortcut($_.FullName).TargetPath } | ForEach-Object FullName })
$texts = @($textFiles | Where-Object { (Test-Path -LiteralPath $_) -and (Has (Get-Content -LiteralPath $_ -Raw)) })
$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $t = $_; @($t.Actions | Where-Object { (Has $_.Execute) -or (Has $_.Arguments) -or (Has $_.WorkingDirectory) }).Count -gt 0 })
$wasRunning = @($svcs | Where-Object State -eq 'Running' | ForEach-Object Name)
$links = @(Get-ChildItem -LiteralPath $old -Recurse -Directory -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } |
  ForEach-Object { [pscustomobject]@{ Rel = $_.FullName.Substring($old.Length + 1); Type = $_.LinkType; Target = ($_.Target -join '') } })
foreach ($l in $links) { if ($l.Type -ne 'SymbolicLink' -or [IO.Path]::IsPathRooted($l.Target)) { throw "Unexpected link inside ${old}: $($l.Rel) [$($l.Type)] -> $($l.Target)" } }
$files = Get-ChildItem -LiteralPath $old -Recurse -File -Force
$bytes = ($files | Measure-Object Length -Sum).Sum

Say ("{0}: {1} files, {2:N2} GB{3}" -f $Launcher, $files.Count, ($bytes / 1GB), $(if ($rename) { '  (same drive: rename, no copy)' } else { '' }))
Say "  from $old"; Say "  to   $new"
foreach ($m in $moveOut) { Say "  game $($m.From)"; Say "    -> $($m.To)" }
Say "Registry values to repoint: $($vals.Count)"; $vals | ForEach-Object { Say ("  {0} [{1}]" -f ($_.Key -replace '^HKEY_LOCAL_MACHINE', 'HKLM' -replace '^HKEY_CURRENT_USER', 'HKCU'), $_.Name) }
Say "Services to repoint: $(($svcs | ForEach-Object Name) -join ', ')"
Say "Shortcuts to repoint: $($lnks.Count)"; $lnks | ForEach-Object { Say "  $_" }
if ($texts) { Say "Config files to repoint: $($texts -join ', ')" }
if ($tasks) { Say "Scheduled tasks to repoint: $(($tasks | ForEach-Object { $_.TaskPath + $_.TaskName }) -join ', ')" }
if ($wasRunning) { Say "Services restarted after the move: $($wasRunning -join ', ')" }
if ($links) { Say "Internal links to recreate: $(($links | ForEach-Object { $_.Rel + ' -> ' + $_.Target }) -join ', ')" }
if (-not $rename) {
  $drive = $new.Substring(0, 1); $free = (Get-PSDrive $drive).Free
  Say ("{0}: free {1:N1} GB" -f $drive, ($free / 1GB))
  if ($free -lt $bytes * 1.2) { throw "Not enough free space on ${drive}:" }
}
if ($DryRun) { Say 'DryRun: nothing changed.'; return }

# 1) backup
$bk = Join-Path $gl ("_archive\_backup_{0}_{1}" -f $Launcher.ToLower(), (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path "$bk\shortcuts", "$bk\files" | Out-Null
$i = 0; foreach ($r in ($regRoots + $uninstRoots)) { if (Test-Path $r) { $i++; & reg.exe export ((Get-Item $r).Name) "$bk\reg_$i.reg" /y | Out-Null } }
foreach ($s in $svcs) { $i++; & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Services\$($s.Name)" "$bk\reg_$i.reg" /y | Out-Null }
foreach ($l in $lnks) { Copy-Item -LiteralPath $l -Destination ("$bk\shortcuts\" + ($l -replace '[:\\ ]', '_')) -Force }
foreach ($t in $texts) { Copy-Item -LiteralPath $t -Destination ("$bk\files\" + ($t -replace '[:\\ ]', '_')) -Force }
foreach ($t in $tasks) { Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath | Set-Content -LiteralPath ("$bk\task_" + ($t.TaskName -replace '[^\w]', '_') + '.xml') -Encoding Unicode }
Say "backup -> $bk"

# 2) stop
foreach ($s in $svcs) { if ($s.State -ne 'Stopped') { Stop-Service -Name $s.Name -Force } }
Get-CimInstance Win32_Process | Where-Object { ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($old + '\', [StringComparison]::OrdinalIgnoreCase)) -or ($exes -contains [IO.Path]::GetFileNameWithoutExtension($_.Name)) } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3
$left = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($old + '\', [StringComparison]::OrdinalIgnoreCase) }
if ($left) { throw ("still running: " + (($left | ForEach-Object Name) -join ', ') + " - nothing changed") }
Say "$Launcher stopped"

# 3) same drive: rename (games first, launcher last; undo on failure)
#    other drive: copy + verify (/XJ: internal links are recreated below instead of being followed)
if ($rename) {
  $done = @()
  try {
    foreach ($m in $moveOut) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $m.To) | Out-Null; [IO.Directory]::Move($m.From, $m.To); $done += $m; Say "game moved: $($m.To)" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $new) | Out-Null
    [IO.Directory]::Move($old, $new)
  } catch {
    foreach ($m in $done) { [IO.Directory]::Move($m.To, $m.From) }
    throw "rename failed (a file is in use?): $($_.Exception.Message) - moved back, nothing else changed"
  }
  Say "renamed: $new"
} else {
  & robocopy.exe $old $new /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) - nothing else changed" }
  foreach ($l in $links) { $lp = Join-Path $new $l.Rel; if (-not (Test-Path -LiteralPath $lp)) { cmd.exe /c "mklink /D `"$lp`" `"$($l.Target)`"" | Out-Null }; Say "link: $($l.Rel) -> $($l.Target)" }
  $nf = Get-ChildItem -LiteralPath $new -Recurse -File -Force
  if ($nf.Count -ne $files.Count -or ($nf | Measure-Object Length -Sum).Sum -ne $bytes) { throw "copy mismatch - nothing else changed" }
  Say "copied and verified: $($nf.Count) files"
}

# 4) repoint registry (same value type), services (through the SCM), shortcuts, config files
foreach ($v in $vals) {
  $hive = if ($v.Key -like 'HKEY_LOCAL_MACHINE*') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
  $w = $hive.OpenSubKey($v.Key.Substring($v.Key.IndexOf('\') + 1), $true)
  if ($w) { $w.SetValue($v.Name, $v.New, [Microsoft.Win32.RegistryValueKind]$v.Kind); $w.Close() }
}
Say "registry repointed: $($vals.Count) values"
foreach ($s in $svcs) {
  $r = Invoke-CimMethod -InputObject $s -MethodName Change -Arguments @{ PathName = (Repoint $s.PathName) }
  if ($r.ReturnValue -ne 0) { throw "could not change service $($s.Name) (code $($r.ReturnValue))" }
  Say "service $($s.Name) -> $(Repoint $s.PathName)"
}
foreach ($l in $lnks) {
  $s = $sh.CreateShortcut($l)
  $s.TargetPath = Repoint $s.TargetPath
  if ($s.WorkingDirectory) { $s.WorkingDirectory = Repoint $s.WorkingDirectory }
  if ($s.IconLocation) { $s.IconLocation = Repoint $s.IconLocation }
  $s.Save()
}
Say "shortcuts repointed: $($lnks.Count)"
foreach ($t in $texts) { [IO.File]::WriteAllText($t, (Repoint ([IO.File]::ReadAllText($t))), (New-Object Text.UTF8Encoding $false)); Say "config repointed: $t" }
foreach ($t in $tasks) {
  $acts = foreach ($a in $t.Actions) {
    $p = @{ Execute = (Repoint $a.Execute) }
    if ($a.Arguments) { $p.Argument = Repoint $a.Arguments }
    if ($a.WorkingDirectory) { $p.WorkingDirectory = Repoint $a.WorkingDirectory }
    New-ScheduledTaskAction @p
  }
  Set-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Action $acts | Out-Null
  Say "scheduled task repointed: $($t.TaskPath)$($t.TaskName)"
}

# 5) remove the old folder completely (internal links first so recursion never walks through them),
#    then parent folders left empty (never system/profile folders)
if (-not $rename) {
  foreach ($l in $links) { $lp = Join-Path $old $l.Rel; if (Test-Path -LiteralPath $lp) { [IO.Directory]::Delete($lp) } }
  Remove-Item -LiteralPath $old -Recurse -Force
}
$keep = @($env:USERPROFILE, [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'), $env:LOCALAPPDATA, $env:APPDATA,
          $env:ProgramData, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $gl, (Split-Path -Parent $gl), 'C:\Users')
$parent = Split-Path -Parent $old
for ($i = 0; $i -lt 4 -and $parent.Length -gt 3 -and $keep -notcontains $parent -and (Test-Path -LiteralPath $parent) -and -not (Get-ChildItem -LiteralPath $parent -Force); $i++) {
  Remove-Item -LiteralPath $parent -Force; Say "empty folder removed: $parent"; $parent = Split-Path -Parent $parent
}
Say ("old folder removed: " + (-not (Test-Path -LiteralPath $old)))
foreach ($s in $wasRunning) { try { Start-Service -Name $s -ErrorAction Stop; Say "service $s started" } catch { Say "WARNING could not start service ${s}: $($_.Exception.Message)" } }
Say "Done. Open $Launcher from its desktop/start-menu shortcut to confirm."
