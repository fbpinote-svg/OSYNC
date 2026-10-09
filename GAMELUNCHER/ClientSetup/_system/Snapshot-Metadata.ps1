# Snapshot-Metadata.ps1 - run on the MASTER server after installing/updating Riot games.
# Copies C:\ProgramData\Riot Games\Metadata into ClientSetup\Metadata so clients get the
# same "installed" state. Refuses if a game's install path is not on a shared game disk.
param([string]$SharedDrives = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Settings.ps1')
if (-not $SharedDrives) { $SharedDrives = Get-SharedDrives }
$setupDir = $KitSystem
$src = Join-Path $env:ProgramData 'Riot Games\Metadata'
$dst = Join-Path $setupDir 'Metadata'
Write-Output "shared drives: $SharedDrives"

if (Get-Process -Name 'RiotClientServices' -ErrorAction SilentlyContinue) {
    Write-Warning 'Riot Client is running. If a game is still downloading/patching, wait until it finishes first.'
}
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

& robocopy.exe $src $dst /MIR /XF *.lockfile /R:1 /W:1 /NP /NFL /NDL /NJH | Select-Object -Last 4
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Write-Output "snapshot updated: $dst"

# reference list of the Riot Client files, used by Diagnose\RiotDiag.bat on clients
$rc = Join-Path $KitRoot 'RiotClient'
if (Test-Path -LiteralPath $rc) {
    Get-ChildItem -LiteralPath $rc -Recurse -File -Force | ForEach-Object { [pscustomobject]@{ Rel = $_.FullName.Substring($rc.Length + 1); Length = $_.Length; SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } } |
        Export-Csv (Join-Path $setupDir 'riotclient-files.csv') -NoTypeInformation -Encoding ASCII
    Write-Output "riotclient-files.csv updated"
}
