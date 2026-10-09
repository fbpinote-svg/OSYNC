# Export-Kit.ps1 - pack ClientSetup into a zip for another branch's master server.
# Leaves out everything generated for THIS master (Riot/EA client data) and resets settings.txt.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Settings.ps1')
$stage = Join-Path $env:TEMP ('GAMELUNCHER-Kit_' + [guid]::NewGuid().ToString('N'))
$dst = Join-Path $stage 'GAMELUNCHER\ClientSetup'
& robocopy.exe $KitSetup $dst /E /XD Metadata EA-InstallData Epic-InstallData /XF ea-client.reg ea-games.reg riotclient-files.csv eac-products.txt *.log /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
$settings = @'
# GAMELUNCHER settings
# Drive letters that the CLIENT PCs see for the game disks (must be the same letters as on this master).
# Example: SharedDrives=EFGHI
# Leave empty = every fixed drive except the system drive.
SharedDrives=
'@
[IO.File]::WriteAllText((Join-Path $dst 'settings.txt'), ($settings -replace "`r?`n", "`r`n"), [Text.Encoding]::ASCII)
$zip = Join-Path $KitRoot ('GAMELUNCHER-Kit_' + (Get-Date -Format 'yyyyMMdd') + '.zip')
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $stage 'GAMELUNCHER') -DestinationPath $zip
Remove-Item -LiteralPath $stage -Recurse -Force
Write-Output ("kit: {0}  ({1:N0} KB)" -f $zip, ((Get-Item $zip).Length / 1KB))
