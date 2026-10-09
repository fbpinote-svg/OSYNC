# Settings.ps1 - shared helpers, dot-sourced by the other scripts.
#   $KitSystem  ...\ClientSetup\_system      $KitSetup  ...\ClientSetup      $KitRoot  ...\GAMELUNCHER
$KitSystem = $PSScriptRoot
$KitSetup  = Split-Path -Parent $KitSystem
$KitRoot   = Split-Path -Parent $KitSetup

# Drive letters that client PCs see (same letters as on the master), from ClientSetup\settings.txt.
# Empty = every fixed drive except the system drive.
function Get-SharedDrives {
    $f = Join-Path $KitSetup 'settings.txt'
    $v = ''
    if (Test-Path -LiteralPath $f) {
        $line = Get-Content -LiteralPath $f | Where-Object { $_ -match '^\s*SharedDrives\s*=' } | Select-Object -First 1
        if ($line) { $v = (($line -split '=', 2)[1] -replace '[^A-Za-z]', '').ToUpper() }
    }
    if (-not $v) {
        $sys = $env:SystemDrive.Substring(0, 1).ToUpper()
        $v = ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID.Substring(0, 1).ToUpper() } | Where-Object { $_ -ne $sys }) -join '')
    }
    $v
}
