# Master-Snapshot-Riot.ps1 - MASTER, after installing/updating Riot games (Master-Update.ps1 runs it).
# Copies C:\ProgramData\Riot Games\Metadata into System\Data\Riot\Metadata so clients get the
# same "installed" state. Refuses if a game's install path is not on a shared game disk.
param([string]$SharedDrives = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $SharedDrives) { $SharedDrives = Get-SharedDrives }
$setupDir = Join-Path $DataDir 'Riot'
New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
$src = Join-Path $env:ProgramData 'Riot Games\Metadata'
$dst = Join-Path $setupDir 'Metadata'
Write-Output "shared drives: $SharedDrives"

# Riot Client may stay open; a half-patched game would make clients ask for REPAIR, so wait for it
$busy = @(Get-RiotBusy)
if ($busy) { throw ("still updating, run again when it is done (RiotClient = open Riot Client once to install its own update): " + ($busy -join ', ')) }
$bad = @()
foreach ($y in Get-ChildItem $src -Recurse -Filter '*.live.product_settings.yaml') {
    $line = Select-String -Path $y.FullName -Pattern 'product_install_full_path:\s*"(.+)"' | Select-Object -First 1
    if ($line) {
        $p = $line.Matches[0].Groups[1].Value
        $drive = $p.Substring(0,1).ToUpper()
        if ($SharedDrives.IndexOf($drive) -lt 0) { $bad += "$($y.Name): $p" }
        else { Write-Output "ok  $($y.BaseName) -> $p" }
    }
}
if ($bad) { throw ("Install path not on a shared game disk ($SharedDrives):`n" + ($bad -join "`n")) }

# Update = a downloaded Riot Client self-update; clients must not get it (each would install it on every boot)
& robocopy.exe $src $dst /MIR /XD Update /XF *.lockfile lockfile /R:1 /W:1 /NP /NFL /NDL /NJH | Select-Object -Last 4
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

# only the master patches Riot games; clients run them from the shared disk, so auto-update stays off there
foreach ($y in Get-ChildItem $dst -Recurse -Filter '*.product_settings.yaml') {
    $t = [IO.File]::ReadAllText($y.FullName)
    if ($t -match 'auto_patching_enabled_by_player:\s*true') {
        $time = $y.LastWriteTimeUtc
        [IO.File]::WriteAllText($y.FullName, ($t -replace 'auto_patching_enabled_by_player:\s*true', 'auto_patching_enabled_by_player: false'), (New-Object Text.UTF8Encoding $false))
        $y.LastWriteTimeUtc = $time    # keep the master's time so clients copy it like the other files
    }
}
Write-Output "snapshot updated: $dst"

# reference list of the Riot Client files, used by Tool-RiotDiag.ps1 on clients
$rc = Get-LauncherDir 'Riot'
if (Test-Path -LiteralPath $rc) {
    Get-ChildItem -LiteralPath $rc -Recurse -File -Force | ForEach-Object { [pscustomobject]@{ Rel = $_.FullName.Substring($rc.Length + 1); Length = $_.Length; SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } } |
        Export-Csv (Join-Path $setupDir 'riotclient-files.csv') -NoTypeInformation -Encoding ASCII
    Write-Output "riotclient-files.csv updated"
}
