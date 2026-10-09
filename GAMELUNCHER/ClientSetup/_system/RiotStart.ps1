# RiotStart.ps1 - prepare a diskless client so Riot Client sees the games on the
# shared game disk as already installed (no Install/Repair), then launch.
# Run on CLIENT machines every time (client C: is reset on reboot).
# Usage: RiotStart.ps1 -Product valorant | league_of_legends | teamfighttactics | riotclient | background
#   background = prepare, then start Riot Client minimized to the tray (used by Install-Startup.bat)
param(
    [string]$Product = 'riotclient',
    [switch]$NoLaunch,                              # prepare only, do not start Riot Client
    [switch]$SkipRegistry,                          # do not touch HKCU (for testing)
    [string]$ProgramDataRoot = $env:ProgramData     # override for testing
)
$ErrorActionPreference = 'Continue'
$setupDir  = Split-Path -Parent $MyInvocation.MyCommand.Path              # ...\ClientSetup\_system
$glRoot    = Split-Path -Parent (Split-Path -Parent $setupDir)            # ...\GAMELUNCHER
$clientDir = Join-Path $glRoot 'RiotClient'
$clientExe = Join-Path $clientDir 'RiotClientServices.exe'
$riotPd    = Join-Path $ProgramDataRoot 'Riot Games'
$logFile   = Join-Path $env:TEMP 'RiotStart.log'
function Log($m) { $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $m; Add-Content -Path $logFile -Value $line; Write-Output $line }

Log "start product=$Product setup=$setupDir"
if (-not (Test-Path -LiteralPath $clientExe)) {
    Log "ERROR Riot Client not found: $clientExe"
    (New-Object -ComObject WScript.Shell).Popup("Riot Client not found:`n$clientExe", 15, 'RiotStart', 16) | Out-Null
    exit 1
}

# 0) old images may have these folders as links into the removed AutoSync project; a link whose
#    target is gone makes every read/write fail, so replace it with a real folder
function Repair-Link([string]$path) {
    try { $attr = [IO.File]::GetAttributes($path) } catch { return }          # does not exist at all
    if (-not ($attr -band [IO.FileAttributes]::ReparsePoint)) { return }
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    $target = if ($item) { ($item.Target -join '') } else { '?' }
    if ($target -and $target -ne '?' -and (Test-Path -LiteralPath $target)) { Log "link ok: $path -> $target"; return }
    try { [IO.Directory]::Delete($path); New-Item -ItemType Directory -Force -Path $path | Out-Null; Log "FIXED broken link: $path (was -> $target)" }
    catch { Log "ERROR could not replace broken link $path : $($_.Exception.Message)" }
}
foreach ($p in $riotPd, (Join-Path $riotPd 'Metadata'), (Join-Path $env:LOCALAPPDATA 'Riot Games'), (Join-Path $env:LOCALAPPDATA 'Riot Games\Riot Client'), (Join-Path $env:LOCALAPPDATA 'Riot Games\RiotClient')) { Repair-Link $p }

# 1) installed-games metadata (paths inside already point to the shared disk)
$srcMeta = Join-Path $setupDir 'Metadata'
$dstMeta = Join-Path $riotPd 'Metadata'
New-Item -ItemType Directory -Force -Path $dstMeta | Out-Null
# /XO: never replace metadata that is newer than the snapshot (e.g. on the master itself)
& robocopy.exe $srcMeta $dstMeta /E /XO /XF *.lockfile /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
$rc = $LASTEXITCODE
if ($rc -ge 8) { Log "ERROR metadata copy failed (robocopy exit $rc) to $dstMeta" } else { Log "metadata copied (robocopy exit $rc)" }

# 2) tell Riot where its client lives
$exeFwd = $clientExe -replace '\\', '/'
$json = "{`r`n    ""patchlines"": {`r`n        ""KeystoneFoundationLiveWin"": ""$exeFwd""`r`n    },`r`n    ""rc_default"": ""$exeFwd"",`r`n    ""rc_live"": ""$exeFwd""`r`n}"
try {
    [IO.File]::WriteAllText((Join-Path $riotPd 'RiotClientInstalls.json'), $json, (New-Object Text.UTF8Encoding $false))
    Log "RiotClientInstalls.json -> $exeFwd"
} catch { Log "ERROR could not write RiotClientInstalls.json: $($_.Exception.Message)" }

# 3) riotclient:// protocol for this user (no admin needed)
if (-not $SkipRegistry) {
    $k = 'HKCU:\Software\Classes\riotclient'
    New-Item -Path "$k\shell\open\command" -Force | Out-Null
    New-Item -Path "$k\DefaultIcon" -Force | Out-Null
    Set-ItemProperty -Path $k -Name '(default)' -Value 'URL:Riot Games Protocol'
    Set-ItemProperty -Path $k -Name 'URL Protocol' -Value ''
    Set-ItemProperty -Path "$k\DefaultIcon" -Name '(default)' -Value ('"' + $clientExe + '",0')
    Set-ItemProperty -Path "$k\shell\open\command" -Name '(default)' -Value ('"' + $clientExe + '" --app-command="%1"')
    Log 'riotclient:// protocol set (HKCU)'
}

# 4) Vanguard is required by VALORANT / League / TFT and must be in the client image
if ($Product -notin 'riotclient', 'background' -and -not (Get-Service -Name vgc -ErrorAction SilentlyContinue)) {
    Log 'WARNING Riot Vanguard (vgc) not installed on this machine'
    (New-Object -ComObject WScript.Shell).Popup("Riot Vanguard is not installed on this PC.`nThe game will ask to install it and reboot.`nInstall Vanguard into the client image (super workstation) instead.", 10, 'RiotStart', 48) | Out-Null
}

# 5) launch
if ($NoLaunch) { Log 'NoLaunch: done'; exit 0 }
if ($Product -eq 'riotclient') { Start-Process -FilePath $clientExe -WorkingDirectory $clientDir }
elseif ($Product -eq 'background') {
    if (Get-Process -Name 'RiotClientServices' -ErrorAction SilentlyContinue) { Log 'Riot Client already running'; exit 0 }
    Start-Process -FilePath $clientExe -WorkingDirectory $clientDir -ArgumentList '--launch-background-mode'
}
else { Start-Process -FilePath $clientExe -WorkingDirectory $clientDir -ArgumentList "--launch-product=$Product", '--launch-patchline=live' }
Log "launched $Product"
