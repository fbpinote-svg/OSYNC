# Steam-FirstRun.ps1 - do on a CLIENT PC what Steam does the first time each game starts on a PC:
# run the game's install script (anti-cheat such as BattlEye / ACE / Ricochet / EasyAntiCheat, Rockstar
# Social Club, DirectX, VC++ ...) and write its registry keys. A diskless client forgets all of this at reboot,
# so Steam would redo it (or fail) every time; done once in image mode it stays in the image.
# Works for every Steam game on the shared disks, including games installed later.
# Run as administrator in super-workstation (image edit) mode, then save the image.
#   Steam-FirstRun.ps1           run everything not done yet on this PC
#   Steam-FirstRun.ps1 -DryRun   list only
param([switch]$DryRun)
. (Join-Path $PSScriptRoot 'Settings.ps1')
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $DryRun -and -not $isAdmin) { throw 'Run as administrator.' }
# handled by other steps, or must not run on clients
$skipProcess = '(?i)EAappInstaller|EAAntiCheat|uninst'      # shared EA app / EAAntiCheat-Install.ps1 / uninstallers
$skipGames   = @('wallpaper_engine')
$timeoutSec  = 600

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

# --- Steam game folders on the shared disks
$dirs = New-Object System.Collections.Generic.List[string]
foreach ($d in (Get-SharedDrives).ToCharArray()) {
  foreach ($lib in "${d}:\SteamLibrary\steamapps\common", "${d}:\Steam\steamapps\common") {
    Get-ChildItem -LiteralPath $lib -Directory -ErrorAction SilentlyContinue | Where-Object { $skipGames -notcontains $_.Name } | ForEach-Object { $dirs.Add($_.FullName) }
  }
}

$ran = 0; $fail = 0; $done = 0; $regs = 0
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
      $hasRun = Get-V $entry.V 'HasRunKey'
      if ($hasRun) { $hk = Open-Key $hasRun $false; if ($hk -and $hk.GetValue($entry.K)) { $hk.Close(); $done++; continue } ; if ($hk) { $hk.Close() } }
      $okAll = $true; $any = $false
      for ($i = 1; $i -le 9; $i++) {
        $proc = Get-V $entry.V "process $i"
        if (-not $proc) { continue }
        $cmd = Expand ("" + (Get-V $entry.V "command $i")) $dir
        $exe = Expand $proc $dir
        if (-not [IO.Path]::IsPathRooted($exe) -and (Test-Path -LiteralPath (Join-Path $dir $exe))) { $exe = Join-Path $dir $exe }
        if ($exe -match $skipProcess) { Write-Output ("  skip {0}: {1} (handled by another step)" -f $game, (Split-Path -Leaf $exe)); $okAll = $false; continue }
        if ([IO.Path]::IsPathRooted($exe) -and -not (Test-Path -LiteralPath $exe)) { Write-Output ("  skip {0}: {1} (file not found)" -f $game, $exe); $okAll = $false; continue }
        $any = $true
        if ($DryRun) { Write-Output ("  run  {0} [{1}]: {2} {3}" -f $game, $entry.K, $exe, $cmd); continue }
        $sp = @{ FilePath = $exe; PassThru = $true; WindowStyle = 'Hidden' }
        if ($cmd) { $sp.ArgumentList = $cmd }
        if ([IO.Path]::IsPathRooted($exe)) { $sp.WorkingDirectory = Split-Path -Parent $exe }
        try {
          $p = Start-Process @sp
          if (-not $p.WaitForExit($timeoutSec * 1000)) { $p | Stop-Process -Force; Write-Output ("  TIMEOUT {0}: {1}" -f $game, (Split-Path -Leaf $exe)); $okAll = $false; continue }
          $code = $p.ExitCode
        } catch { Write-Output ("  FAIL {0}: {1} ({2})" -f $game, (Split-Path -Leaf $exe), $_.Exception.Message); $okAll = $false; continue }
        $ignore = (Get-V $entry.V 'IgnoreExitCode') -eq '1'
        # 1638/3010/1641 = already installed / reboot needed (MSI); 0x80070666 newer version present
        $okCode = $code -in 0, 1638, 3010, 1641, -2147023258
        Write-Output ("  {0} {1} [{2}]: {3} exit {4}" -f $(if ($okCode -or $ignore) { 'ok ' } else { 'ERR' }), $game, $entry.K, (Split-Path -Leaf $exe), $code)
        $ran++
        if (-not ($okCode -or $ignore)) { $okAll = $false }
      }
      if ($okAll -and $any -and $hasRun -and -not $DryRun) { $hk = Open-Key $hasRun $true; $hk.SetValue($entry.K, 1, 'DWord'); $hk.Close() }
      if (-not $okAll -and $any) { $fail++ }
    }
  }
}
Write-Output ("Steam first-run: {0} programs run, {1} already done, {2} registry values, {3} with problems" -f $ran, $done, $regs, $fail)
if ($fail) { exit 1 }
