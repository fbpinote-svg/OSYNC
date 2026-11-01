# Steam-FirstRun.ps1 - do on a CLIENT PC what Steam does the first time each game starts on a PC:
# run the game's install script (anti-cheat such as BattlEye / ACE / Ricochet / EasyAntiCheat, Rockstar
# Social Club, DirectX, VC++ ...) and write its registry keys. A diskless client forgets all of this at reboot,
# so Steam would redo it (or fail) every time; done once in image mode it stays in the image.
# Works for every Steam game on the shared disks, including games installed later.
# Run as administrator in super-workstation (image edit) mode, then save the image.
#   Steam-FirstRun.ps1           run everything not done yet on this PC
#   Steam-FirstRun.ps1 -DryRun   list only
#   Steam-FirstRun.ps1 -SkipFailed  also skip entries that failed / timed out before (Install-All.ps1 -Boot:
#                                   a slow failing installer must not cost minutes at every boot; image mode retries)
param([switch]$DryRun, [switch]$SkipFailed)
. (Join-Path $PSScriptRoot 'Settings.ps1')
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run as administrator.' }
# handled by other steps, or must not run on clients
$skipProcess = '(?i)EAappInstaller|EAAntiCheat|uninst'      # shared EA app / EAAntiCheat-Install.ps1 / uninstallers
$skipGames   = @('wallpaper_engine')
# Windows 10/11 has .NET 4.8 built in, and 3.5 is a Windows feature: Steam's DotNetFx35Client /q then waits
# on Windows Update (hangs until the timeout on a diskless client)
$skipDotNet  = if ([Environment]::OSVersion.Version.Major -ge 10) { '(?i)\\_CommonRedist\\DotNet\\' } else { '^$' }
$timeoutSec  = 300

# --- tiny VDF reader: a node is a list of {K, V}; V is a string or a nested list
function Read-Vdf([string]$text) {
  $script:tok = [regex]::Matches($text, '"((?:[^"\\]|\\.)*)"|\{|\}'); $script:ti = 0
  Read-Node
}
function Read-Node {
  $list = New-Object System.Collections.Generic.List[object]
  while ($script:ti -lt $script:tok.Count) {
    $m = $script:tok[$script:ti]; $script:ti++
    if ($m.Value -eq '}') { break }
    if ($m.Value -eq '{') { continue }
    $key = Unescape $m.Groups[1].Value
    if ($script:ti -ge $script:tok.Count) { break }
    $n = $script:tok[$script:ti]; $script:ti++
    if ($n.Value -eq '{') { $list.Add([pscustomobject]@{ K = $key; V = (Read-Node) }) }
    else { $list.Add([pscustomobject]@{ K = $key; V = (Unescape $n.Groups[1].Value) }) }
  }
  , $list
}
function Unescape([string]$s) { [regex]::Replace($s, '\\(["\\])', '$1') }       # VDF: \\ -> \ , \" -> "
function Get-V($node, [string]$key) { foreach ($e in $node) { if ($e.K -eq $key) { return $e.V } } }

# Steam is 32-bit: plain HKEY_LOCAL_MACHINE means the 32-bit view; scripts may also say ..._WOW64_32 / ..._WOW64_64
function Open-Key([string]$path, [bool]$create) {
  $m = [regex]::Match($path, '^(?i)(HKEY_LOCAL_MACHINE|HKLM|HKEY_CURRENT_USER|HKCU)(_WOW64_(32|64))?\\+(.*?)\\*$')
  if (-not $m.Success) { throw "unknown registry path: $path" }
  $hive = if ($m.Groups[1].Value -match '(?i)USER|HKCU') { 'CurrentUser' } else { 'LocalMachine' }
  $view = if ($m.Groups[3].Value -eq '64') { 'Registry64' } else { 'Registry32' }
  $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
  if ($create) { $base.CreateSubKey($m.Groups[4].Value) } else { $base.OpenSubKey($m.Groups[4].Value) }
}
function Expand([string]$s, [string]$dir) { [Environment]::ExpandEnvironmentVariables(($s -ireplace '%INSTALLDIR%', $dir)) }

# what this PC already ran: entries without a HasRunKey (VC++, .NET, PhysX, EasyAntiCheat ...) would run again
# every time, which would make every boot slow (Install-All.ps1 -Boot); same game + entry + commands = done
$hklm64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
$marks = if ($DryRun) { $hklm64.OpenSubKey('SOFTWARE\OSYNC\SteamFirstRun') } else { $hklm64.CreateSubKey('SOFTWARE\OSYNC\SteamFirstRun') }

# --- Steam game folders on the shared disks
$dirs = New-Object System.Collections.Generic.List[string]
foreach ($d in (Get-SharedDrives).ToCharArray()) {
  foreach ($lib in "${d}:\SteamLibrary\steamapps\common", "${d}:\Steam\steamapps\common") {
    Get-ChildItem -LiteralPath $lib -Directory -ErrorAction SilentlyContinue | Where-Object { $skipGames -notcontains $_.Name } | ForEach-Object { $dirs.Add($_.FullName) }
  }
}

# --- pass 1: write the registry values, list the programs that still have to run (so pass 2 can count n / total)
$jobs = New-Object System.Collections.Generic.List[object]
$done = 0; $regs = 0
foreach ($dir in $dirs) {
  foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*installscript*.vdf' -Recurse -Depth 4 -File -ErrorAction SilentlyContinue) {
    $root = Read-Vdf ([IO.File]::ReadAllText($f.FullName))
    $is = Get-V $root 'InstallScript'
    if (-not $is) { continue }
    $game = Split-Path -Leaf $dir

    # registry values the game expects (e.g. GTA V InstallFolderSteam)
    $reg = Get-V $is 'Registry'
    foreach ($k in @($reg)) {
      if (-not $k -or $k.V -isnot [System.Collections.IList]) { continue }
      $groups = @($k.V | Where-Object { $_.K -in 'string', 'dword' })
      $eng = Get-V $k.V 'english'; if ($eng) { $groups += @($eng | Where-Object { $_.K -in 'string', 'dword' }) }
      foreach ($g in $groups) {
        foreach ($v in $g.V) {
          $val = Expand $v.V $dir
          if ($DryRun) { Write-Output ("  reg  {0}: {1}\{2} = {3}" -f $game, $k.K, $v.K, $val); continue }
          $rk = Open-Key $k.K $true
          if ($g.K -eq 'dword') { $rk.SetValue($v.K, [int]$val, 'DWord') } else { $rk.SetValue($v.K, $val, 'String') }
          $rk.Close(); $regs++
        }
      }
    }

    # processes Steam runs once per PC
    foreach ($entry in @(Get-V $is 'Run Process')) {
      if (-not $entry -or $entry.V -isnot [System.Collections.IList]) { continue }
      # only for another Windows (e.g. a noop for Windows XP) or bitness
      $req = Get-V $entry.V 'Requirement_OS'
      if ($req -is [System.Collections.IList]) {
        $os = Get-V $req 'OSType'; $x64 = Get-V $req 'Is64BitWindows'
        if (($os -and $os -notmatch '1[01]') -or ($x64 -and (($x64 -eq '1') -ne [Environment]::Is64BitOperatingSystem))) { continue }
      }
      $hasRun = Get-V $entry.V 'HasRunKey'
      if ($hasRun) { $hk = Open-Key $hasRun $false; if ($hk -and $hk.GetValue($entry.K)) { $hk.Close(); $done++; continue } ; if ($hk) { $hk.Close() } }
      $sig = "$game|$($entry.K)|" + ((1..9 | ForEach-Object { ("" + (Get-V $entry.V "process $_") + ' ' + (Get-V $entry.V "command $_")).Trim() } | Where-Object { $_ }) -join ';')
      $mark = if ($marks) { $marks.GetValue($sig) }      # 1 = done, 2 = tried and failed
      if ($mark -eq 1 -or ($SkipFailed -and $mark -eq 2)) { $done++; continue }
      $steps = New-Object System.Collections.Generic.List[object]
      $partial = $false; $missing = $false
      for ($i = 1; $i -le 9; $i++) {
        $proc = Get-V $entry.V "process $i"
        if (-not $proc) { continue }
        $cmd = Expand ("" + (Get-V $entry.V "command $i")) $dir
        $exe = Expand $proc $dir
        if (-not [IO.Path]::IsPathRooted($exe) -and (Test-Path -LiteralPath (Join-Path $dir $exe))) { $exe = Join-Path $dir $exe }
        if ($exe -match $skipProcess) { Write-Output ("  skip {0}: {1} (handled by another step)" -f $game, (Split-Path -Leaf $exe)); $partial = $true; continue }
        if ($exe -match $skipDotNet) { Write-Output ("  skip {0}: {1} (.NET is part of Windows 10/11)" -f $game, (Split-Path -Leaf $exe)); $partial = $true; continue }
        if ([IO.Path]::IsPathRooted($exe) -and -not (Test-Path -LiteralPath $exe)) { Write-Output ("  skip {0}: {1} (file not found)" -f $game, $exe); $partial = $true; $missing = $true; continue }
        if ($DryRun) { Write-Output ("  run  {0} [{1}]: {2} {3}" -f $game, $entry.K, $exe, $cmd) }
        $steps.Add([pscustomobject]@{ Exe = $exe; Cmd = $cmd })
      }
      if ($steps.Count) {
        $jobs.Add([pscustomobject]@{ Game = $game; Entry = $entry.K; Sig = $sig; HasRun = $hasRun; Steps = $steps
          Partial = $partial; Missing = $missing; Ignore = (Get-V $entry.V 'IgnoreExitCode') -eq '1' })
      }
    }
  }
}
$total = @($jobs | ForEach-Object { $_.Steps }).Count
if ($DryRun) { Write-Output ("Steam first-run: {0} programs to run, {1} already done" -f $total, $done); return }

# --- pass 2: run them
$t = [Diagnostics.Stopwatch]::StartNew()
$n = 0; $ran = 0; $fail = 0
foreach ($j in $jobs) {
  # games sharing an installer (GTA V / GTA V Enhanced / RDR2 -> Rockstar Launcher) share its HasRunKey: run once
  if ($j.HasRun) {
    $hk = Open-Key $j.HasRun $false; $now = $hk -and $hk.GetValue($j.Entry); if ($hk) { $hk.Close() }
    if ($now) { $n += $j.Steps.Count; $done++; Write-Output ("  done {0} [{1}] (installed for another game)" -f $j.Game, $j.Entry); continue }
  }
  $err = $j.Missing
  foreach ($s in $j.Steps) {
    $n++
    $label = "[$n/$total] $($j.Game) [$($j.Entry)]: $(Split-Path -Leaf $s.Exe)"
    $r = Invoke-Installer $s.Exe $s.Cmd $label $timeoutSec
    if ($null -eq $r.Code) { $err = $true; continue }
    # 1638/3010/1641 = already installed / reboot needed (MSI); 0x80070666 newer version present
    $ok = $j.Ignore -or $r.Code -in 0, 1638, 3010, 1641, -2147023258
    Write-Output ("  {0} {1} exit {2}, {3} s" -f $(if ($ok) { 'ok ' } else { 'ERR' }), $label, $r.Code, $r.Sec)
    $ran++
    if (-not $ok) { $err = $true }
  }
  if (-not $err -and -not $j.Partial -and $j.HasRun) { $hk = Open-Key $j.HasRun $true; $hk.SetValue($j.Entry, 1, 'DWord'); $hk.Close() }
  $marks.SetValue($j.Sig, $(if ($err) { 2 } else { 1 }), 'DWord')
  if ($err) { $fail++ }
}
Write-Output ("Steam first-run: {0} programs run in {1} min, {2} already done, {3} registry values, {4} with problems" -f $ran, [math]::Round($t.Elapsed.TotalMinutes, 1), $done, $regs, $fail)
if ($fail) { exit 1 }
