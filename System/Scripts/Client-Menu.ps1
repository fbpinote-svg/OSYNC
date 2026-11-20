# Client-Menu.ps1 - CLIENT PC (super workstation / image mode, then save the image; Client-Install.ps1 step 5).
# Starts the game menu with Windows (all users) and puts its icon on the Public Desktop. The shortcuts run
# System\Client\Menu.vbs, which finds the menu program itself, so renaming the shop (= the .exe) needs no image edit.
# Shortcuts left from before (0JAYSHOP.lnk, or ones pointing at an older OSYNC folder) are replaced.
#   Client-Menu.ps1              install + start the menu now
#   Client-Menu.ps1 -NoStart     install only
#   Client-Menu.ps1 -Uninstall   remove the shortcuts
param([switch]$Uninstall, [switch]$NoStart)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$mi  = Get-MenuInfo
$vbs = Join-Path $ClientDir 'Menu.vbs'
$dirs = @((Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'), (Join-Path $env:PUBLIC 'Desktop'))
if (-not $Uninstall -and -not (Test-Path -LiteralPath $mi.Exe)) { throw "not found: $($mi.Exe) (build the menu on the master first)" }
# every shortcut of the menu: its names now and before, plus any shortcut that starts a menu exe (old folders too)
$sh = New-Object -ComObject WScript.Shell
foreach ($d in $dirs) {
  foreach ($l in Get-ChildItem -LiteralPath $d -Filter *.lnk -ErrorAction SilentlyContinue) {
    $target = $sh.CreateShortcut($l.FullName).TargetPath
    $args0  = $sh.CreateShortcut($l.FullName).Arguments
    $isMenu = ($mi.Names -contains $l.BaseName) -or ($target -match '\\(GCafe|Menu)\\app\\[^\\]+\.exe$') -or ($args0 -like '*\System\Client\Menu.vbs*')
    if ($isMenu) { Remove-Item -LiteralPath $l.FullName -Force; Write-Output "removed $($l.FullName)  ($target)" }
  }
}
if ($Uninstall) {
  Get-Process -Name $mi.Names -ErrorAction SilentlyContinue | Stop-Process -Force
  return
}
$ico = Join-Path $Menu 'data\brand\app.ico'
foreach ($d in $dirs) {
  $l = Join-Path $d "$($mi.Name).lnk"
  $s = $sh.CreateShortcut($l)
  $s.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
  $s.Arguments = '"' + $vbs + '"'
  $s.WorkingDirectory = Split-Path -Parent $mi.Exe
  $s.IconLocation = $(if (Test-Path -LiteralPath $ico) { "$ico,0" } else { "$($mi.Exe),0" })
  $s.Description = "$($mi.Name) game menu"
  $s.Save(); Write-Output "shortcut: $l -> $vbs"
}
# start it now as the normal (non-elevated) user
if (-not $NoStart -and -not (Get-Process -Name $mi.Names -ErrorAction SilentlyContinue)) { Start-Process explorer.exe -ArgumentList "`"$vbs`"" }
Write-Output "Done. $($mi.Name) starts with Windows on this PC."
