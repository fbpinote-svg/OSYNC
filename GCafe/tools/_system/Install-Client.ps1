# Install-Client.ps1 - run on a CLIENT PC (super workstation / image mode) so the change stays in the image.
# Adds the game-menu program to Startup (all users) and to the Public Desktop.
#   Install-Client.ps1             install + start it now
#   Install-Client.ps1 -Uninstall  remove both shortcuts
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$gcafe = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exe   = Join-Path $gcafe 'app\0JAYSHOP.exe'
$cfg   = try { Get-Content -LiteralPath (Join-Path $gcafe 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
$name  = if ($cfg -and $cfg.brandName) { $cfg.brandName } else { '0JAYSHOP' }
$lnks  = @((Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\StartUp\$name.lnk"),
           (Join-Path $env:PUBLIC "Desktop\$name.lnk"))

if ($Uninstall) {
  foreach ($l in $lnks) { if (Test-Path -LiteralPath $l) { Remove-Item -LiteralPath $l -Force; Write-Output "removed $l" } }
  Get-Process -Name '0JAYSHOP' -ErrorAction SilentlyContinue | Stop-Process -Force
  return
}
if (-not (Test-Path -LiteralPath $exe)) { throw "not found: $exe (run tools\Build-App.bat on the master first)" }
$sh = New-Object -ComObject WScript.Shell
foreach ($l in $lnks) {
  $s = $sh.CreateShortcut($l)
  $s.TargetPath = $exe; $s.WorkingDirectory = Split-Path -Parent $exe; $s.IconLocation = "$exe,0"; $s.Description = "$name game menu"
  $s.Save(); Write-Output "shortcut: $l"
}
# start it now as the normal (non-elevated) user
if (-not (Get-Process -Name '0JAYSHOP' -ErrorAction SilentlyContinue)) { Start-Process explorer.exe -ArgumentList "`"$exe`"" }
Write-Output "Done. $name starts with Windows on this PC."
