# Client-WinRAR.ps1 - CLIENT PC: WinRAR (18 Nov 2026, the owner: "add WinRAR to the game menu and make the clients know it").
#   not on this PC -> installed silently from Tools\WinRAR (the official setup from rarlab.com, Thai, signed by win.rar GmbH;
#                     checked before it runs) into C:\Program Files\WinRAR: menu card "WinRAR", right-click "Extract here".
#   then           -> archives open with WinRAR: .rar .zip .7z .tar .gz .tgz .bz2 .xz .cab .arj .lzh .lz .zst .001 - set
#                     only where Windows has nothing / its own zip folder (an image saved with WinRAR = a check of a second).
# Called by Client-Install step 1s (at boot as SYSTEM, or in image mode by the admin). Never on the master.
# Setting: ClientWinRAR=off skips it. -CheckOnly: report only (also on the master). Exit 0 = WinRAR is here, 1 = it is not.
param([switch]$CheckOnly)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $CheckOnly) { Write-Host 'WinRAR: this is the master - nothing changed here'; exit 0 }
$pf = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$exe = Join-Path $pf 'WinRAR\WinRAR.exe'
$kit = Join-Path $ToolsDir 'WinRAR'

if (-not (Test-Path -LiteralPath $exe)) {
  $setup = Get-ChildItem -LiteralPath $kit -Filter 'winrar-x64-*.exe' -File -ErrorAction SilentlyContinue | Sort-Object { $_.VersionInfo.ProductVersion -as [version] } -Descending | Select-Object -First 1
  if (-not $setup) { Write-Host "WinRAR: not on this PC, and no setup in $kit"; exit 1 }
  if ($CheckOnly) { Write-Host "WinRAR: not on this PC - would install $($setup.Name) /S"; exit 0 }
  $sig = Get-AuthenticodeSignature -LiteralPath $setup.FullName
  if ($sig.Status -ne 'Valid' -or "$($sig.SignerCertificate.Subject)" -notmatch '(^|, )CN=win\.rar GmbH(,|$)') { Write-Host "WinRAR: NOT installed - $($setup.Name) is not validly signed by win.rar GmbH ($($sig.Status))"; exit 1 }
  Write-Host "WinRAR: not on this PC - installing $($setup.Name) ($($setup.VersionInfo.ProductVersion)) silently"
  $p = Start-Process -FilePath $setup.FullName -ArgumentList '/S' -WindowStyle Hidden -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit(180000)) { & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /T /F /PID $p.Id 2>$null | Out-Null; Write-Host 'WinRAR: setup still busy after 3 min - stopped' }
  if (-not (Test-Path -LiteralPath $exe)) { Write-Host "WinRAR: did NOT install (setup exit $($p.ExitCode))"; exit 1 }
  Write-Host "WinRAR: installed $((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)"
} else { Write-Host "WinRAR: on this PC ($((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion))" }

# archives open with WinRAR (what its setup does; only where Windows has nothing or its own zip folder)
$cls = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Classes', (-not $CheckOnly))
try {
  $set = @(); $kept = @()
  foreach ($id in 'WinRAR', 'WinRAR.ZIP') {
    $k = $cls.OpenSubKey("$id\shell\open\command")
    $ok = $k -and ("$($k.GetValue(''))" -like "*$exe*"); if ($k) { $k.Close() }
    if (-not $ok -and -not $CheckOnly) {
      $p = $cls.CreateSubKey($id); $p.SetValue('', $(if ($id -eq 'WinRAR') { 'WinRAR archive' } else { 'WinRAR ZIP archive' }))
      $i = $p.CreateSubKey('DefaultIcon'); $i.SetValue('', "$exe,$(if ($id -eq 'WinRAR') { 0 } else { 1 })"); $i.Close()
      $c = $p.CreateSubKey('shell\open\command'); $c.SetValue('', "`"$exe`" `"%1`""); $c.Close(); $p.Close()
    }
  }
  foreach ($ext in '.rar', '.zip', '.7z', '.tar', '.gz', '.tgz', '.bz2', '.xz', '.cab', '.arj', '.lzh', '.lz', '.zst', '.001') {
    $want = if ($ext -eq '.zip') { 'WinRAR.ZIP' } else { 'WinRAR' }
    $k = $cls.OpenSubKey($ext, (-not $CheckOnly))
    $cur = if ($k) { "$($k.GetValue(''))" } else { '' }
    if ($cur -eq $want) { if ($k) { $k.Close() }; continue }
    if (-not $cur -or $cur -match '^(?i)(CompressedFolder|Windows\.CompressedFolder|CABFolder)$') {
      if (-not $CheckOnly) { if (-not $k) { $k = $cls.CreateSubKey($ext) }; $k.SetValue('', $want) }
      $set += $ext
    } else { $kept += "$ext=$cur" }
    if ($k) { $k.Close() }
  }
  Write-Host "WinRAR: archives $(if ($CheckOnly) { 'would open' } else { 'open' }) with WinRAR$(if ($set.Count) { " (set now: $($set -join ' '))" } else { ' (already)' })$(if ($kept.Count) { "; left to their program: $($kept -join ', ')" })"
} finally { if ($cls) { $cls.Close() } }
exit 0
