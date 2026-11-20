# Tool-Organize-Drive.ps1 - tidy the games into the OSYNC games folder (Settings GamesFolder, default <OSYNC>\GAME):
#   GAME\Steam\  GAME\Garena\  GAME\HoYoPlay\  GAME\Online\ (games of small / one-game publishers)  GAME\Gacha\ ...
# and shop tools that are not games into <OSYNC>\Tools\. Same-drive moves only (folder renames, nothing is copied,
# nothing is deleted). Registry values (uninstall entries, the game's own keys) and shortcuts that point into a moved
# folder are repointed; a backup goes to System\Backup. Folder icons are set afterwards (Tool-Folder-Icons.ps1).
# Run while the shop is CLOSED and every client PC is OFF (Tool-Migrate.ps1 runs it as one step).
#   Tool-Organize-Drive.ps1 -DryRun        show what would move
#   Tool-Organize-Drive.ps1                do it (administrator)
#   -MoveTools                             also move X:\Agen, X:\Appdata, X:\123.bat, X:\ZakoVirtualMouse* into Tools\
# What moves (only when it exists and the target does not):
#   X:\Online\<game>, X:\Games\Online\<game>, GAME\<game> (FiveM, RedM ...)  -> GAME\Online\<game>
#   X:\Delta Force (Garena) -> GAME\Garena\Delta Force          X:\Games\<kind>\<game> -> GAME\<kind>\<game>
#   GAME\DiscordPTB, GAME\RustDesk, GAME\OSLink (tools, not games) -> Tools\
# Not moved: X:\Riot Games (Riot would repair VALORANT everywhere), X:\LDPlayer (its remote service runs from there),
# games a launcher keeps the path of itself (Garena's own downloads stay where Garena put them).
param([switch]$DryRun, [switch]$MoveTools)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
$D = $Root.Substring(0, 2)
if (-not $DryRun -and -not (Test-Admin)) { Write-Host 'Run as administrator.' -ForegroundColor Red; exit 1 }
$bk = Join-Path $BackupDir ('organize-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$sh = New-Object -ComObject WScript.Shell
$uninst = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$lnkDirs = 'C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\Users\Public\Desktop', [Environment]::GetFolderPath('Desktop'), "$env:APPDATA\Microsoft\Windows\Start Menu"
$gameKeys = 'HKCU:\Software\CitizenFX', 'HKCU:\Software\Garena', 'HKLM:\SOFTWARE\WOW6432Node\Garena', 'HKCU:\Software\Juvio'       # games' own keys that keep their folder
$tools = 'DiscordPTB', 'Discord', 'RustDesk', 'OSLink', 'Sunshine', 'Agent', 'CooperAgent'
$moves = 0

# move one folder (or file) on the same drive and repoint what points into it
function Move-Thing([string]$from, [string]$to, [string]$why) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  if ($from.TrimEnd('\') -ieq $to.TrimEnd('\')) { return }
  Write-Host "`n-- $why" -ForegroundColor Cyan
  Write-Host "   $from  ->  $to"
  if (Test-Path -LiteralPath $to) { Write-Host "   SKIP: $to already exists" -ForegroundColor Yellow; return }
  if ([IO.Path]::GetPathRoot($from) -ine [IO.Path]::GetPathRoot($to)) { Write-Host '   SKIP: another drive (this tool only renames on the same drive)' -ForegroundColor Yellow; return }
  $isDir = (Get-Item -LiteralPath $from -Force).PSIsContainer
  $rx = [regex]::Escape($from) + '(?![\w.-])'; $rxF = [regex]::Escape(($from -replace '\\', '/')) + '(?![\w.-])'
  $keys = @(foreach ($r in $uninst) { Get-ChildItem $r -ErrorAction SilentlyContinue }) + @(foreach ($r in $gameKeys) { if (Test-Path $r) { Get-Item $r; Get-ChildItem $r -Recurse -ErrorAction SilentlyContinue } })
  $vals = @(foreach ($k in $keys) {
      foreach ($n in $k.GetValueNames()) { $kind = $k.GetValueKind($n); if ($kind -ne 'String' -and $kind -ne 'ExpandString') { continue }
        $v = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames'); if ($v -and ($v -imatch $rx -or $v -imatch $rxF)) { [pscustomobject]@{ Key = $k.Name; Name = $n; Kind = $kind; New = ($v -ireplace $rx, $to.Replace('$', '$$') -ireplace $rxF, ($to -replace '\\', '/').Replace('$', '$$')) } } } })
  $lnks = @(foreach ($d in $lnkDirs) { Get-ChildItem -LiteralPath $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | Where-Object { $t = $sh.CreateShortcut($_.FullName).TargetPath; $t -and $t -imatch $rx } | ForEach-Object FullName })
  if ($isDir) { $lnks += @(Get-ChildItem -LiteralPath $from -Filter *.lnk -File -ErrorAction SilentlyContinue | Where-Object { $sh.CreateShortcut($_.FullName).TargetPath -imatch $rx } | ForEach-Object { Join-Path $to $_.Name }) }
  $running = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($from + '\', [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object Name | Sort-Object -Unique)
  Write-Host "   registry values to repoint: $($vals.Count)   shortcuts: $($lnks.Count)"
  $vals | ForEach-Object { Write-Host ("     {0} [{1}]" -f ($_.Key -replace '^HKEY_LOCAL_MACHINE', 'HKLM' -replace '^HKEY_CURRENT_USER', 'HKCU'), $_.Name) -ForegroundColor DarkGray }
  if ($running) { Write-Host "   running from there: $($running -join ', ')$(if (-not $DryRun) { ' - closing them' })" -ForegroundColor Yellow }
  if ($DryRun) { return }
  if ($running) { Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($from + '\', [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 3 }
  New-Item -ItemType Directory -Force -Path $bk | Out-Null
  $i = 0; foreach ($k in ($vals | ForEach-Object Key | Sort-Object -Unique)) { $i++; & reg.exe export $k (Join-Path $bk ("reg_{0}_{1}.reg" -f (Split-Path -Leaf $from), $i)) /y | Out-Null }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
  if ($isDir) { [IO.Directory]::Move($from, $to) } else { [IO.File]::Move($from, $to) }
  foreach ($v in $vals) {
    $hive = if ($v.Key -like 'HKEY_LOCAL_MACHINE*') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $w = $hive.OpenSubKey($v.Key.Substring($v.Key.IndexOf('\') + 1), $true); if ($w) { $w.SetValue($v.Name, $v.New, [Microsoft.Win32.RegistryValueKind]$v.Kind); $w.Close() }
  }
  foreach ($l in $lnks) {
    if (-not (Test-Path -LiteralPath $l)) { continue }
    $s = $sh.CreateShortcut($l)
    $s.TargetPath = $s.TargetPath -ireplace $rx, $to.Replace('$', '$$')
    if ($s.WorkingDirectory) { $s.WorkingDirectory = $s.WorkingDirectory -ireplace $rx, $to.Replace('$', '$$') }
    if ($s.IconLocation) { $s.IconLocation = $s.IconLocation -ireplace $rx, $to.Replace('$', '$$') }
    $s.Save()
  }
  $script:moves++
  Write-Host '   done' -ForegroundColor Green
}

Write-Host "Organize games into $GamesRoot$(if ($DryRun) { '   (DryRun: nothing changes)' })" -ForegroundColor Cyan
$online = Join-Path $GamesRoot 'Online'
# 1 games of small / one-game publishers -> GAME\Online
foreach ($src in "$D\Online", "$D\Games\Online", "$D\PvP") { foreach ($g in Get-ChildItem -LiteralPath $src -Directory -ErrorAction SilentlyContinue) { Move-Thing $g.FullName (Join-Path $online $g.Name) 'online game' } }
foreach ($g in Get-ChildItem -LiteralPath $GamesRoot -Directory -ErrorAction SilentlyContinue) {
  if ($tools -contains $g.Name) { continue }
  if ('Steam', 'Garena', 'HoYoPlay', 'Online', 'Gacha', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'PvP', 'Epic', 'EA', 'Ubisoft', 'BattleNet', 'Battle.net', 'GOG', 'Amazon', 'Rockstar', 'Riot', 'Nexon' -contains $g.Name) { continue }
  Move-Thing $g.FullName (Join-Path $online $g.Name) 'game straight in the games folder -> Online'
}
# 2 Garena games and other X:\Games\<kind>\<game>
Move-Thing "$D\Delta Force" (Join-Path $GamesRoot 'Garena\Delta Force') 'Delta Force (Garena server) - the Steam copy stays in the Steam library'
foreach ($k in Get-ChildItem -LiteralPath "$D\Games" -Directory -ErrorAction SilentlyContinue) {
  if ((Join-Path $D 'Games') -ieq $GamesRoot) { break }
  foreach ($g in Get-ChildItem -LiteralPath $k.FullName -Directory -ErrorAction SilentlyContinue) { Move-Thing $g.FullName (Join-Path (Join-Path $GamesRoot $k.Name) $g.Name) "games folder: $($k.Name)" }
}
# 3 tools that are not games -> Tools\
foreach ($t in $tools) { Move-Thing (Join-Path $GamesRoot $t) (Join-Path $ToolsDir $t) 'shop tool (not a game) -> Tools' }
if ($MoveTools) {
  Move-Thing "$D\Agen" (Join-Path $ToolsDir 'Agent') 'shop tools: CooperAgent installer'
  Move-Thing "$D\Appdata" (Join-Path $ToolsDir 'Sunshine') 'shop tools: Sunshine auto-config'
  foreach ($f in Get-ChildItem "$D\" -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'ZakoVirtualMouse*' -or $_.Name -eq '123.bat' }) {
    $name = if ($f.Name -eq '123.bat') { 'Sunshine-AutoConfig-old (123).bat' } else { $f.Name }
    Move-Thing $f.FullName (Join-Path $ToolsDir "Sunshine\$name") "shop tools: $($f.Name)"
  }
} else { Write-Host "`n-- $D\Agen, $D\Appdata, $D\123.bat, $D\ZakoVirtualMouse*: left where they are (-MoveTools moves them into Tools\)" -ForegroundColor DarkGray }

# 4 folder icons (each game / launcher / tool folder shows its own icon in Explorer)
if (-not $DryRun) { [void](Run-Ps 'Tool-Folder-Icons.ps1') } else { Write-Host "`n-- would set folder icons (Tool-Folder-Icons.ps1)" -ForegroundColor DarkGray }
Write-Host "`nStays: $D\Riot Games (VALORANT), $D\LDPlayer (remote service OSLink); Garena keeps its own downloads where it put them"
if (-not $DryRun) { Write-Host "moved: $moves$(if (Test-Path -LiteralPath $bk) { "   registry backup: $bk" })" }
