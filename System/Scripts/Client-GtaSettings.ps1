# Client-GtaSettings.ps1 - CLIENT PC: GTA V / FiveM graphics from the shop's file at every boot (Client-Install step 1h).
# Settings\gta5_settings.xml (a GTA V settings.xml saved by the shop - low graphics) is written over
#   <profile>\Documents\Rockstar Games\GTA V\settings.xml      GTA V Legacy (Story / Online)
#   <profile>\AppData\Roaming\CitizenFX\gta5_settings.xml     FiveM (keeps its own copy)
# for every user profile on the PC and the Default profile (new users). Everything as in the file except
# <VideoCardDescription>: set to this PC's graphics card - GTA re-detects (and changes) the settings when the card named
# there is not the card it runs on. No card found (no driver) = the file's text stays.
# A diskless client forgets what a customer changed at reboot, so the shop's settings are back at every boot.
# GTA V Enhanced (Documents\Rockstar Games\GTAV Enhanced) has another format - not touched.
# -CheckOnly: show what would be written, write nothing.
# -TestDir <folder>: write only into <folder>\Documents\... and <folder>\AppData\Roaming\... (also on the master - testing)
param([switch]$CheckOnly, [string]$TestDir)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir) { Write-Host 'this is the master - nothing written here'; exit 0 }

$template = Join-Path $SettingsDir 'gta5_settings.xml'
if (-not (Test-Path -LiteralPath $template)) { Write-Host "GTA: no $template - skipped"; exit 0 }
$utf8 = New-Object Text.UTF8Encoding($false)
$text = $utf8.GetString([IO.File]::ReadAllBytes($template))
if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
try { $xml = [xml]$text } catch { Write-Host "GTA: $template is not valid XML ($($_.Exception.Message)) - skipped"; exit 1 }
if (-not $xml.Settings -or -not $xml.Settings.graphics) { Write-Host "GTA: $template is not a GTA V settings file (no <Settings><graphics>) - skipped"; exit 1 }

# this PC's graphics card, the name DirectX gives it (= Windows' display adapter name); virtual / remote screens left out
$gpuBad = '(?i)Microsoft Basic|Remote Display|Virtual|Parsec|Mirage|Meta Display|Citrix|VMware|Hyper-V|Indirect|IddSample|Dummy'
$controllers = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name })
function Get-GpuName {
  # PCI cards first; 17 Nov: KORI12 found none that way ("card: not found") - then any card that is not a virtual / remote screen
  $real = @($controllers | Where-Object { $_.Name -notmatch $gpuBad })
  $v = @($real | Where-Object { "$($_.PNPDeviceID)" -like 'PCI\*' })
  if (-not $v.Count) { $v = $real }
  if (-not $v.Count) { return '' }
  $pick = $v | Sort-Object @{ e = { if ($_.Name -match '(?i)NVIDIA|GeForce|Quadro') { 0 } elseif ($_.Name -match '(?i)AMD|Radeon') { 1 } else { 2 } } } | Select-Object -First 1
  "$($pick.Name)".Trim()
}
# this PC's screen (17 Nov, owner's choice: the real screen, not the shop file's 2560x1440 180 Hz): the mode a card shows now;
# a real card first, else a virtual screen (a PC without a monitor plays through its virtual display). Nothing = the file's values stay.
function Get-ScreenMode {
  $withMode = @($controllers | Where-Object { [int]$_.CurrentHorizontalResolution -gt 0 -and [int]$_.CurrentVerticalResolution -gt 0 })
  $pick = @(@($withMode | Where-Object { $_.Name -notmatch $gpuBad }) + @($withMode | Where-Object { $_.Name -match $gpuBad })) | Select-Object -First 1
  if (-not $pick) { return $null }
  [pscustomobject]@{ W = [int]$pick.CurrentHorizontalResolution; H = [int]$pick.CurrentVerticalResolution; Hz = [int]$pick.CurrentRefreshRate }
}
$gpu = Get-GpuName
$mode = Get-ScreenMode
$out = $text
if ($gpu) {
  $tag = '<VideoCardDescription>' + [Security.SecurityElement]::Escape($gpu) + '</VideoCardDescription>'
  $out = [regex]::Replace($out, '(?s)<VideoCardDescription>.*?</VideoCardDescription>', $tag.Replace('$', '$$'))
}
if ($mode) {
  $out = [regex]::Replace($out, '<ScreenWidth value="[^"]*"', "<ScreenWidth value=`"$($mode.W)`"")
  $out = [regex]::Replace($out, '<ScreenHeight value="[^"]*"', "<ScreenHeight value=`"$($mode.H)`"")
  if ($mode.Hz -gt 1) { $out = [regex]::Replace($out, '<RefreshRate value="[^"]*"', "<RefreshRate value=`"$($mode.Hz)`"") }
}
$out = [regex]::Replace($out, '<Windowed value="[^"]*"', '<Windowed value="2"')     # borderless, as in the shop file (owner's choice)

# user profiles (ProfileList) + Default
function Get-Profiles {
  $list = New-Object System.Collections.Generic.List[object]
  $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
  foreach ($k in @(Get-ChildItem -LiteralPath $pl -ErrorAction SilentlyContinue)) {
    $sid = $k.PSChildName
    if ($sid -notmatch '^S-1-5-21-[\d-]+$') { continue }
    $p = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath)")
    if ($p -and (Test-Path -LiteralPath $p)) { $list.Add([pscustomobject]@{ Name = (Split-Path -Leaf $p); Path = $p; Sid = $sid }) }
  }
  $def = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $pl -ErrorAction SilentlyContinue).Default)")
  if (-not $def) { $def = Join-Path $env:SystemDrive 'Users\Default' }
  if (Test-Path -LiteralPath $def) { $list.Add([pscustomobject]@{ Name = 'Default'; Path = $def; Sid = '' }) }
  $list
}
# Documents / Roaming of a profile: the user's own folder setting when the user is logged on (hive loaded), else the usual place
function Get-UserFolder($prof, [string]$name, [string]$fallback) {
  if ($prof.Sid) {
    # read the value NOT expanded: expanded here (SYSTEM at boot) %USERPROFILE% would be the system profile
    $v = $null
    $rk = [Microsoft.Win32.Registry]::Users.OpenSubKey("$($prof.Sid)\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", $false)
    if ($rk) { try { $v = $rk.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } finally { $rk.Close() } }
    if ($v) {
      $v = [Environment]::ExpandEnvironmentVariables(("$v" -replace '(?i)%USERPROFILE%', $prof.Path.Replace('$', '$$')))
      if ($v -match '^[A-Za-z]:\\' -and $v -notlike "$env:SystemRoot\*" -and (Test-Path -LiteralPath (Split-Path -Qualifier $v))) { return $v }
    }
  }
  Join-Path $prof.Path $fallback
}
function Write-IfChanged([string]$file, [string]$content) {
  $old = $null
  if (Test-Path -LiteralPath $file) { try { $old = [IO.File]::ReadAllText($file) } catch { } }
  if ($null -ne $old -and $old -ceq $content) { return 'same' }
  if ($CheckOnly) { return $(if ($null -eq $old) { 'would create' } else { 'would overwrite' }) }
  $dir = Split-Path -Parent $file
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path -LiteralPath $file) { $fi = Get-Item -LiteralPath $file -Force; if ($fi.IsReadOnly) { $fi.IsReadOnly = $false } }
  [IO.File]::WriteAllText($file, $content, $utf8)
  $(if ($null -eq $old) { 'created' } else { 'overwritten' })
}

$targets = if ($TestDir) { @([pscustomobject]@{ Name = 'test'; Path = $TestDir; Sid = '' }) } else { @(Get-Profiles) }
$n = 0; $fail = 0
foreach ($p in $targets) {
  $docs = Get-UserFolder $p 'Personal' 'Documents'
  $roam = Get-UserFolder $p 'AppData' 'AppData\Roaming'
  foreach ($f in @((Join-Path $docs 'Rockstar Games\GTA V\settings.xml'), (Join-Path $roam 'CitizenFX\gta5_settings.xml'))) {
    try { $r = Write-IfChanged $f $out; Write-Host "  $($p.Name): $r $f"; $n++ }
    catch { Write-Host "  $($p.Name): FAILED $f ($($_.Exception.Message))"; $fail++ }
  }
}
$vd = ([xml]$out).Settings.video
Write-Host ("GTA: shop settings, lowest ({0}x{1} {2}Hz{3}, card: {4}) -> {5} file(s){6}" -f $vd.ScreenWidth.value, $vd.ScreenHeight.value, $vd.RefreshRate.value, $(if ($mode) { ' = this PC' } else { ' = shop file, screen not read' }), $(if ($gpu) { $gpu } else { 'not found - file text kept' }), $n, $(if ($fail) { ", $fail FAILED" } else { '' }))
if ($fail) { exit 1 }
exit 0
