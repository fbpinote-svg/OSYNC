# Client-Vdd.ps1 - CLIENT PC: the virtual monitor (VDD = Virtual Display Driver, MttVDD 25.7.23, 1920x1080 240 Hz).
# 18 Nov 2026, the owner: "check whether the PC has VDD 1920x1080 - none: install it; there: skip; there but disabled: skip".
#   a VDD device already on this PC (hardware id Root\MttVDD, the older Root\IddSampleDriver, or the name "Virtual Display
#     Driver") - working, disabled or with a problem -> NOTHING is changed (the line says which state it is in)
#   no VDD device -> installed from Tools\VirtualDisplay (a copy of J:\Setup\VirtualDisplay-1080p240) with its
#     tool\vdd-tool.exe install: the settings file (one monitor, 1920x1080 240 Hz) to C:\VirtualDisplayDriver, the driver's
#     publisher (SignPath Foundation, pinned inside the tool; a catalog signed by anyone else is refused) to Trusted
#     Publishers, then a Root\MttVDD device with the signed driver. A diskless reboot takes it away again, so it is put back
#     at every boot - an image saved with it = only the check (a second).
# Called by Client-Install step 1p (at boot as SYSTEM, or in image mode by the admin). Never installs on the master (its only
# display is a VDD). Setting: ClientVdd=off skips it.
# -CheckOnly: report only (also on the master). -AssumeNone: with -CheckOnly, act as if no VDD were here (tests).
# Exit 0 = a VDD is here (or was installed), 1 = it could not be installed (the lines say why).
param([switch]$CheckOnly, [switch]$AssumeNone)
. (Join-Path $PSScriptRoot 'Common.ps1')
$Pkg = Join-Path $ToolsDir 'VirtualDisplay'
$Tool = Join-Path $Pkg 'tool\vdd-tool.exe'
$ToolSha256 = 'ECA264E5BCFC8D69A761F46091A15513CDF9BCEFA5AC48F6FACA893020BDE039'   # vdd-tool.exe built 17 Nov 2026 (tool\vdd-tool.cs)

function Get-Vdd {
  @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
    (($_.HardwareID -join ',') -match '(?i)(^|,)Root\\(MttVDD|IddSampleDriver)(,|$)') -or "$($_.FriendlyName)" -eq 'Virtual Display Driver' })
}
function Get-VddState($d) {
  $pc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data
  $state = if (-not $d.Present) { 'not present' } elseif (-not $pc) { 'working' } elseif ($pc -eq 22) { 'disabled' } else { "problem code $pc" }
  "$($d.FriendlyName) $($d.InstanceId) = $state"
}

$have = @(if (-not ($AssumeNone -and $CheckOnly)) { Get-Vdd })   # @(): Windows PowerShell 5.1 has no .Count on one CIM object
if ($have.Count) { Write-Host "VDD: already on this PC - left as it is ($(($have | ForEach-Object { Get-VddState $_ }) -join '; '))"; exit 0 }
if ((Test-IsMaster) -and -not $CheckOnly) { Write-Host 'VDD: none found - this is the master, nothing installed here'; exit 0 }
if (-not (Test-Path -LiteralPath $Tool)) { Write-Host "VDD: none on this PC, and no package in $Pkg - not installed"; exit 1 }
$h = (Get-FileHash -LiteralPath $Tool -Algorithm SHA256).Hash
if ($h -ne $ToolSha256) { Write-Host "VDD: NOT installed - $Tool is not the expected file (SHA256 $h); check it, then pin the new hash here"; exit 1 }
if ($CheckOnly) { Write-Host "VDD: none on this PC - would install the virtual monitor 1920x1080 240 Hz from $Pkg"; exit 0 }

Write-Host 'VDD: none on this PC - installing the virtual monitor 1920x1080 240 Hz'
$out = & $Tool install $Pkg 2>&1
$rc = $LASTEXITCODE
foreach ($l in $out) { if ("$l".Trim()) { Write-Host "  $l" } }
if ($rc -eq 0) { Write-Host "VDD: installed ($(((Get-Vdd) | ForEach-Object { Get-VddState $_ }) -join '; '))"; exit 0 }
if ($rc -eq 3) { Write-Host 'VDD: installed, but Windows wants a restart to finish it (on a diskless PC a restart removes it again)'; exit 1 }
Write-Host "VDD: NOT installed (vdd-tool exit $rc)"
exit 1
