# Master-Steam-Library.ps1 - MASTER (OSYNC.bat > 7 Tools > 2): move the Steam games that sit inside the Steam program
# folder (Launchers\Steam\steamapps = library 0) into the games folder (GAME\Steam) on the same drive. Same drive = the
# folders are renamed, nothing is copied, so even hundreds of GB take seconds. Steam finds them in the new library.
#   Master-Steam-Library.ps1 -DryRun            show what would move
#   Master-Steam-Library.ps1                    do it (closes Steam first, run as administrator)
#   -Target <folder>                            default: <GamesFolder>\Steam
# A library Steam does not know yet is added to Steam's libraryfolders.vdf here (Steam closed; the old files are backed
# up to System\Backup); Steam fills in its game list itself at the next start.
param([switch]$DryRun, [string]$Target = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$steam = Get-SteamDir
if (-not $steam) { Write-Output 'Steam not found.'; exit 1 }
if (-not $Target) { $Target = Join-Path $GamesRoot 'Steam' }
$Target = $Target.TrimEnd('\')
$src = Join-Path $steam 'steamapps'
$dst = Join-Path $Target 'steamapps'
Write-Output "from $src"; Write-Output "to   $dst"
if ([IO.Path]::GetPathRoot($steam) -ine [IO.Path]::GetPathRoot($Target)) { Write-Output 'Target is on another drive - this tool only moves within the same drive.'; exit 1 }
if ((Get-SharedDrives).IndexOf($Target.Substring(0, 1).ToUpper()) -lt 0) { Write-Output "WARNING $Target is not on a shared drive: clients will not see these games." }

# the library must be known to Steam (libraryfolders.vdf), or Steam will not look there
$vdf = [IO.File]::ReadAllText((Join-Path $src 'libraryfolders.vdf'))
$known = [regex]::Matches($vdf, '"path"\s+"([^"]+)"') | ForEach-Object { ($_.Groups[1].Value -replace '\\\\', '\').TrimEnd('\') } | Where-Object { $_ -ieq $Target }
if (-not $known) { Write-Output "Steam does not know $Target yet: it is added to Steam's library list (Steam closed) before the move." }

$jobs = @()
foreach ($m in Get-ChildItem -LiteralPath $src -Filter 'appmanifest_*.acf' -File) {
  $t = [IO.File]::ReadAllText($m.FullName)
  $appid = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
  $name  = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value
  $dir   = [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value
  $from  = Join-Path $src "common\$dir"
  $to    = Join-Path $dst "common\$dir"
  if (Test-Path -LiteralPath $to) { Write-Output "skip $name : $to already exists"; continue }
  $gb = if (Test-Path -LiteralPath $from) { (Get-ChildItem -LiteralPath $from -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB } else { 0 }
  $jobs += [pscustomobject]@{ AppId = $appid; Name = $name; Manifest = $m.FullName; From = $from; To = $to; GB = $gb }
}
if (-not $jobs) { Write-Output 'No games to move.'; exit 0 }
$jobs | ForEach-Object { Write-Output ('{0,-10} {1,8:N1} GB  {2}' -f $_.AppId, $_.GB, $_.Name) }
Write-Output ('{0} games, {1:N1} GB (renamed on the same drive, no copy)' -f $jobs.Count, ($jobs | Measure-Object GB -Sum).Sum)
if ($DryRun) { Write-Output 'DryRun: nothing changed.'; exit 0 }
if (-not (Test-Admin)) { throw 'Run as administrator.' }

# Steam must be closed, or it re-creates what is being moved
if (Get-Process -Name steam -ErrorAction SilentlyContinue) {
  Write-Output 'closing Steam ...'
  Start-Process -FilePath (Join-Path $steam 'steam.exe') -ArgumentList '-shutdown'
  for ($i = 0; $i -lt 60 -and (Get-Process -Name steam, steamwebhelper -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Seconds 1 }
  if (Get-Process -Name steam -ErrorAction SilentlyContinue) { throw 'Steam did not close - close it, then run again' }
}
New-Item -ItemType Directory -Force -Path (Join-Path $dst 'common') | Out-Null
# add the library to Steam's list (what Steam > Settings > Storage > Add drive writes)
if (-not $known) {
  $bk = Join-Path $BackupDir ('steam-libraryfolders-' + (Get-Date -Format 'yyyyMMdd-HHmmss')); New-Item -ItemType Directory -Force -Path $bk | Out-Null
  $cid = [string]([uint64](Get-Random -Minimum 1000000000 -Maximum 2147483647) * 4294967 + (Get-Random -Maximum 4294967))
  [IO.File]::WriteAllText((Join-Path $Target 'libraryfolder.vdf'), "`"libraryfolder`"`n{`n`t`"contentid`"`t`t`"$cid`"`n`t`"label`"`t`t`"`"`n}`n", (New-Object Text.UTF8Encoding $false))
  foreach ($rel in 'steamapps\libraryfolders.vdf', 'config\libraryfolders.vdf') {
    $f = Join-Path $steam $rel
    if (-not (Test-Path -LiteralPath $f)) { continue }
    Copy-Item -LiteralPath $f -Destination (Join-Path $bk ($rel -replace '\\', '_'))
    $t = [IO.File]::ReadAllText($f)
    if ($t -match [regex]::Escape(($Target -replace '\\', '\\'))) { continue }
    $next = (@([regex]::Matches($t, '(?m)^\t"(\d+)"\s*$') | ForEach-Object { [int]$_.Groups[1].Value }) | Measure-Object -Maximum).Maximum + 1
    $entry = "`t`"$next`"`n`t{`n`t`t`"path`"`t`t`"$($Target.ToLower() -replace '\\', '\\')`"`n`t`t`"label`"`t`t`"`"`n`t`t`"contentid`"`t`t`"$cid`"`n`t`t`"totalsize`"`t`t`"0`"`n`t`t`"update_clean_bytes_tally`"`t`t`"0`"`n`t`t`"time_last_update_verified`"`t`t`"0`"`n`t`t`"apps`"`n`t`t{`n`t`t}`n`t}`n"
    $i = $t.LastIndexOf('}')
    [IO.File]::WriteAllText($f, $t.Substring(0, $i) + $entry + $t.Substring($i), (New-Object Text.UTF8Encoding $false))
    Write-Output "library added to $rel (backup: $bk)"
  }
}
foreach ($j in $jobs) {
  if (Test-Path -LiteralPath $j.From) { [IO.Directory]::Move($j.From, $j.To) }
  Move-Item -LiteralPath $j.Manifest -Destination $dst
  foreach ($w in "workshop\appworkshop_$($j.AppId).acf", "workshop\content\$($j.AppId)") {
    $p = Join-Path $src $w
    if (Test-Path -LiteralPath $p) { $q = Join-Path $dst $w; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $q) | Out-Null; Move-Item -LiteralPath $p -Destination $q }
  }
  Write-Output "moved: $($j.Name)"
}
Write-Output 'Done. Open Steam: the games are in the new library. Then OSYNC.bat > 1 so the menu and clients use the new place.'
