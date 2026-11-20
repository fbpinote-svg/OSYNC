# Client-Parsec.ps1 - CLIENT PC: Parsec (remote desktop / game streaming). The menu's Parsec card opens
# Program Files\Parsec\parsecd.exe, so Parsec is installed silently ONLY when this PC does not have it yet (an image saved
# with it = nothing to do, a second).
#   Tools\Parsec\parsec-windows*.exe /silent /norun = Parsec's normal "Per User" install, the same as on the master:
#   every customer signs in with their own Parsec account (a normal LW boot forgets it at the next restart).
#   It puts Program Files\Parsec, the Parsec service, a firewall rule for parsecd.exe and the Parsec Virtual USB driver
#   (signed by Microsoft, so no question is asked) on the PC.
#   /norun   : the setup does not start Parsec itself (it would run as SYSTEM, invisible).
#   not used : /vdd (virtual display driver = an extra monitor) and /shared (= "Per Computer": one Parsec account for
#              everyone on this PC, open even at the Windows sign-in screen - not for a shop).
#   Only a setup validly signed by Parsec (Unity Technologies SF / Parsec Cloud, Inc.) is run.
# Called by Client-Install step 1g (at boot as SYSTEM, or in image mode by the admin). Never on the master.
# Setting: ClientParsec=off skips it. Exit 0 = Parsec is there (or nothing to do), 1 = it did not install.
param([switch]$CheckOnly)
. (Join-Path $PSScriptRoot 'Common.ps1')
if (Test-IsMaster) { Write-Host 'this is the master - nothing installed here'; exit 0 }
$ParsecDir = Join-Path $ToolsDir 'Parsec'
$pf = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$ParsecExe = Join-Path $pf 'Parsec\parsecd.exe'

# runs a setup hidden; stops it (and what it started) when it is still busy after $Seconds - a setup waiting on a window
# nobody can see (SYSTEM at boot) must not hold up the rest of the boot setup
function Invoke-Setup([string]$Exe, [string]$Arguments, [int]$Seconds = 240) {
  $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory (Split-Path -Parent $Exe) -WindowStyle Hidden -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit($Seconds * 1000)) {
    & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /T /F /PID $p.Id 2>$null | Out-Null
    return "still running after $Seconds s - stopped"
  }
  "exit $($p.ExitCode)"
}
function Get-ParsecState {
  $svc = Get-Service -Name 'Parsec' -ErrorAction SilentlyContinue
  $usb = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { "$($_.FriendlyName)" -match '(?i)Parsec Virtual USB' })
  $run = @(Get-Process -Name 'parsecd' -ErrorAction SilentlyContinue)
  $ver = if (Test-Path -LiteralPath $ParsecExe) { (Get-Item -LiteralPath $ParsecExe).VersionInfo.FileVersion } else { '' }
  'version {0}; service: {1}; virtual USB: {2}; parsecd running: {3}' -f $(if ($ver) { $ver } else { '?' }),
    $(if ($svc) { "$($svc.Status) ($($svc.StartType))" } else { 'none' }), $(if ($usb.Count) { 'yes' } else { 'no' }),
    $(if ($run.Count) { "$($run.Count) (session $((@($run | ForEach-Object { $_.SessionId }) | Sort-Object -Unique) -join ','))" } else { 'no' })
}

if (Test-Path -LiteralPath $ParsecExe) {
  Write-Host "Parsec: already on this PC ($ParsecExe; $(Get-ParsecState))"
  exit 0
}
# the newest setup in Tools\Parsec (by its file version, then by date)
$setup = Get-ChildItem -LiteralPath $ParsecDir -Filter 'parsec-windows*.exe' -File -ErrorAction SilentlyContinue | Sort-Object `
  @{ Expression = { try { [version]($_.VersionInfo.FileVersion -replace '[^\d\.].*$', '') } catch { [version]'0.0' } }; Descending = $true },
  @{ Expression = { $_.LastWriteTime }; Descending = $true } | Select-Object -First 1
if (-not $setup) { Write-Host "Parsec: missing on this PC, and no installer in $ParsecDir - skipped"; exit 0 }
if ($CheckOnly) { Write-Host "Parsec: missing on this PC ($ParsecExe) - would install $($setup.Name) /silent /norun"; exit 0 }

$sig = Get-AuthenticodeSignature -LiteralPath $setup.FullName
if ($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(^|, )CN="?(Unity Technologies SF|Parsec Cloud, Inc\.)"?(,|$)') {
  Write-Host "Parsec: NOT installed - $($setup.Name) is not validly signed by Parsec (signature $($sig.Status): $(if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { 'none' }))"
  exit 1
}
Write-Host "Parsec: missing - installing $($setup.Name) ($($setup.VersionInfo.FileVersion)) silently"
$r = Invoke-Setup $setup.FullName '/silent /norun'
if (Test-Path -LiteralPath $ParsecExe) { Write-Host "Parsec: installed ($r) -> $ParsecExe; $(Get-ParsecState)"; exit 0 }
Write-Host "Parsec: NOT installed ($r; $ParsecExe missing)"
exit 1
