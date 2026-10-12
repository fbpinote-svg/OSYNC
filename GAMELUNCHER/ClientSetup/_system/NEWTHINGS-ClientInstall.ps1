# NEWTHINGS-ClientInstall.ps1 - set up the NEWTHINGS-GAMES launcher (GTA SA / SA-MP) on a CLIENT PC.
# The launcher lives on a game disk (e.g. H:\...\NEWTHINGS-GAMES); a client needs the registry the installer
# writes, SA-MP's gta_sa.exe path and shortcuts. Optional: fix Thai text that shows as "alien" letters.
# Run as administrator in super-workstation (image edit) mode, then save the image (and restart if Thai was fixed).
#   NEWTHINGS-ClientInstall.ps1                 register + shortcuts
#   NEWTHINGS-ClientInstall.ps1 -FixThaiText    also: system locale Thai, UTF-8 beta off (restart needed)
#   NEWTHINGS-ClientInstall.ps1 -Path <folder>  launcher folder, if not found automatically
param([string]$Path, [switch]$FixThaiText)
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run as administrator.' }

# 1) find the launcher on the game disks: X:\<folder>\NEWTHINGS-GAMES or X:\<folder>\<folder>\NEWTHINGS-GAMES
if (-not $Path) {
  foreach ($d in Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[D-Z]:\\$' }) {
    $hit = Get-ChildItem -Path (Join-Path $d.Root '*\NEWTHINGS-GAMES\NEWTHINGS-GAMES.exe'), (Join-Path $d.Root '*\*\NEWTHINGS-GAMES\NEWTHINGS-GAMES.exe') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { $Path = $hit.DirectoryName; break }
  }
}
if (-not $Path -or -not (Test-Path -LiteralPath (Join-Path $Path 'NEWTHINGS-GAMES.exe'))) { Write-Output 'NEWTHINGS-GAMES not found on the game disks - skipped.'; exit 0 }
$exe = Join-Path $Path 'NEWTHINGS-GAMES.exe'
$gta = Join-Path $Path 'bin\newthings\gta_sa.exe'
Write-Output "NEWTHINGS-GAMES: $Path"

# 2) registry the installer writes (current user = the account players use)
New-Item -Path 'HKCU:\Software\newthings\NEWTHINGS-GAMES' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\newthings\NEWTHINGS-GAMES' -Name '(default)' -Value $Path
$u = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NEWTHINGS-GAMES'
New-Item -Path $u -Force | Out-Null
$ver = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
@{ DisplayName = 'NEWTHINGS-GAMES'; Publisher = 'newthings'; DisplayVersion = "$ver"; DisplayIcon = "`"$exe`""
   InstallLocation = "`"$Path`""; UninstallString = "`"$(Join-Path $Path 'uninstall.exe')`"" }.GetEnumerator() | ForEach-Object { Set-ItemProperty $u -Name $_.Key -Value $_.Value }
Write-Output 'registry: HKCU\Software\newthings + uninstall entry'
# SA-MP finds GTA San Andreas through this value
if (Test-Path -LiteralPath $gta) {
  New-Item -Path 'HKCU:\Software\SAMP' -Force | Out-Null
  Set-ItemProperty 'HKCU:\Software\SAMP' -Name gta_sa_exe -Value $gta
  Write-Output "SA-MP gta_sa_exe: $gta"
}

# 3) shortcuts for every user
$sh = New-Object -ComObject WScript.Shell
foreach ($l in (Join-Path $env:PUBLIC 'Desktop\NEWTHINGS-GAMES.lnk'), (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\NEWTHINGS-GAMES.lnk')) {
  $s = $sh.CreateShortcut($l); $s.TargetPath = $exe; $s.WorkingDirectory = $Path; $s.IconLocation = "$exe,0"; $s.Save()
}
Write-Output 'shortcuts: Public Desktop + Start Menu'

# 4) Thai text: GTA SA / SA-MP and older Thai games read text with the system code page. With the
#    "Beta: Use Unicode UTF-8" option (code page 65001) Thai shows as alien letters; Thai needs 874.
$acp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP
$loc = (Get-WinSystemLocale).Name
Write-Output "system locale: $loc  code page: $acp"
if ($FixThaiText) {
  if ($loc -eq 'th-TH' -and $acp -eq '874') { Write-Output 'Thai text: already OK' }
  else {
    Set-WinSystemLocale -SystemLocale th-TH
    $cp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage'
    Set-ItemProperty $cp -Name ACP -Value '874'; Set-ItemProperty $cp -Name OEMCP -Value '874'; Set-ItemProperty $cp -Name MACCP -Value '10021'
    Write-Output 'Thai text: system locale Thai, UTF-8 beta off  ->  RESTART this PC (and save the image) to apply'
  }
} elseif ($acp -eq '65001') { Write-Output 'NOTE Thai text will look broken in-game (UTF-8 beta is on). Run again with -FixThaiText.' }
Write-Output 'Done.'
