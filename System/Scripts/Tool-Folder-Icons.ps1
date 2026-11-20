# Tool-Folder-Icons.ps1 - give every game, launcher and tool folder its own icon in Explorer (desktop.ini with a path
# relative to the folder, so it shows the same on client PCs). Only adds what is missing; never touches game files.
# Folders: GAME\<kind>\<game>, GAME\<game>, Launchers\<launcher>, Tools\<tool>, and the kind folders themselves.
#   Tool-Folder-Icons.ps1          set the icons
#   Tool-Folder-Icons.ps1 -Force   rewrite them (after a game changed its start exe)
param([switch]$Force)
. (Join-Path $PSScriptRoot 'Common.ps1')
$notStart = '(?i)unins|setup|install|updat|patch|crash|report|redist|dxsetup|prereq|easyanticheat|battleye|^cef|helper|service|elevat|repair|anticheat|7z'
function Pick-Exe([string]$dir) {
  Get-ChildItem -LiteralPath $dir -Filter *.exe -Recurse -Depth 2 -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 100KB -and $_.BaseName -notmatch $notStart } |
    Sort-Object @{ e = { $_.DirectoryName.Length } }, @{ e = { $_.Length }; Descending = $true } | Select-Object -First 1
}
function Set-Icon([string]$dir, [string]$iconRef) {
  $ini = Join-Path $dir 'desktop.ini'
  if ((Test-Path -LiteralPath $ini) -and -not $Force) { return $false }
  try {
    if (Test-Path -LiteralPath $ini) { (Get-Item -LiteralPath $ini -Force).Attributes = 'Normal' }
    [IO.File]::WriteAllText($ini, "[.ShellClassInfo]`r`nIconResource=$iconRef`r`n[ViewState]`r`nMode=`r`nVid=`r`nFolderType=Generic`r`n", [Text.Encoding]::Unicode)
    (Get-Item -LiteralPath $ini -Force).Attributes = 'Hidden, System'
    $d = Get-Item -LiteralPath $dir -Force; $d.Attributes = $d.Attributes -bor [IO.FileAttributes]::ReadOnly     # Explorer reads desktop.ini only on read-only/system folders
    $true
  } catch { Write-Output "  cannot set icon in ${dir}: $($_.Exception.Message)"; $false }
}
$n = 0
# games, tools: the folder's own start exe
$kinds = 'Steam', 'Garena', 'HoYoPlay', 'Online', 'Gacha', 'Mobile', 'Single Player', 'Offline', 'Web', 'Emulator', 'PvP'
$gameDirs = @()
foreach ($c in Get-ChildItem -LiteralPath $GamesRoot -Directory -ErrorAction SilentlyContinue) {
  if ($kinds -contains $c.Name) { if ($c.Name -ne 'Steam') { $gameDirs += @(Get-ChildItem -LiteralPath $c.FullName -Directory -ErrorAction SilentlyContinue) } }
  else { $gameDirs += $c }
}
$gameDirs += @(Get-ChildItem -LiteralPath $ToolsDir -Directory -ErrorAction SilentlyContinue)
foreach ($g in $gameDirs) {
  $exe = Pick-Exe $g.FullName
  if ($exe -and (Set-Icon $g.FullName ($exe.FullName.Substring($g.FullName.Length + 1) + ',0'))) { $n++; Write-Output "  icon: $($g.FullName)  <- $($exe.Name)" }
}
# launchers: their start program
foreach ($l in $LauncherTable) {
  $dir = Get-LauncherDir $l.Key; $exe = Get-LauncherExe $l.Key
  if (-not (Test-Path -LiteralPath $exe)) { continue }
  if (Set-Icon $dir ($exe.Substring($dir.Length + 1) + ',0')) { $n++; Write-Output "  icon: $dir  <- $(Split-Path -Leaf $exe)" }
}
# Roblox: its start program moves to a new version-<hash> folder at every update, so the folder gets its own Roblox.ico
$rbx = Get-RobloxExe
if ($rbx) {
  $rd = Join-Path $Launchers 'Roblox'; $ico = Join-Path $rd 'Roblox.ico'
  if (-not (Test-Path -LiteralPath $ico)) {
    try { Add-Type -AssemblyName System.Drawing; $fs = [IO.File]::Create($ico); ([System.Drawing.Icon]::ExtractAssociatedIcon($rbx)).Save($fs); $fs.Close(); (Get-Item -LiteralPath $ico -Force).Attributes = 'Hidden' } catch { Write-Output "  cannot make Roblox.ico: $($_.Exception.Message)" }
  }
  if ((Test-Path -LiteralPath $ico) -and (Set-Icon $rd 'Roblox.ico,0')) { $n++; Write-Output "  icon: $rd  <- Roblox.ico" }
}
# the kind folders: Windows' own icons (Steam folder: the Steam icon)
$kindIcon = @{ 'Online' = '%SystemRoot%\System32\imageres.dll,-1025'; 'Garena' = '%SystemRoot%\System32\imageres.dll,-1023'; 'HoYoPlay' = '%SystemRoot%\System32\imageres.dll,-1023'
               'Gacha' = '%SystemRoot%\System32\imageres.dll,-1023'; 'Mobile' = '%SystemRoot%\System32\imageres.dll,-1023' }
foreach ($k in $kindIcon.Keys) { $p = Join-Path $GamesRoot $k; if ((Test-Path -LiteralPath $p) -and (Set-Icon $p $kindIcon[$k])) { $n++ } }
$steamLib = Join-Path $GamesRoot 'Steam'; $steamExe = Join-Path (Get-SteamDir) 'steam.exe'
if ((Test-Path -LiteralPath $steamLib) -and (Test-Path -LiteralPath $steamExe) -and (Set-Icon $steamLib "$steamExe,0")) { $n++ }
Write-Output "folder icons set: $n"
