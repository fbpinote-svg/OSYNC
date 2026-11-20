# Master-Snapshot-Oslink.ps1 - MASTER (Master-Update step 7): which OSLink files the clients may trust.
# Clients install OSLink's 3 input drivers at boot with OSLink's own devcon.exe (Client-OslinkDrivers.ps1, step 1l). A client
# often cannot finish checking devcon.exe's signature at boot (its root certificate is fetched on demand: "UnknownError"),
# and another shop's OSLink can be a newer build than the one pinned in that script - then nothing was installed and OSLink
# said "driver error". Here, on the master (full certificate store, online), every file of OSLink's bin that the clients use
# is checked: a VALID signature by OSLink's maker (Shanghai Chang Zhi / XuanZhi) or by Microsoft = trusted. Written to
# System\Data\Oslink\trusted.txt: "<SHA256> <signer thumbprint> <file>" per line. A client accepts a file only when its own
# SHA256 and signer are in that list (or pinned in the script).
#   Master-Snapshot-Oslink.ps1           write the list        -Check   show only
param([switch]$Check)
. (Join-Path $PSScriptRoot 'Common.ps1')
# OSLink's bin: its service's folder, its installer's InstallDir, else <shared drive>:\LDPlayer\OSLink\bin (as on the clients)
$c = New-Object System.Collections.Generic.List[string]
$ip = "$((Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\LDRemoteSvc' -ErrorAction SilentlyContinue).ImagePath)"
$m = [regex]::Match($ip, '^\s*"?([^"]+?\.exe)'); if ($m.Success) { $c.Add((Split-Path -Parent $m.Groups[1].Value)) }
foreach ($k in 'HKLM:\SOFTWARE\XuanZhi\OSLink', 'HKLM:\SOFTWARE\WOW6432Node\XuanZhi\OSLink') { $v = "$((Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue).InstallDir)"; if ($v) { $c.Add($v.TrimEnd('\')) } }
foreach ($d in (Get-SharedDrives).ToCharArray()) { $c.Add("${d}:\LDPlayer\OSLink\bin") }
$bin = $c | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'LdVMou.inf')) } | Select-Object -First 1
if (-not $bin) { Write-Host 'OSLink: not installed on this master (no LDRemoteSvc / <drive>:\LDPlayer\OSLink\bin) - nothing to do'; exit 0 }
if (-not (Get-SharedDrives).Contains($bin.Substring(0, 1).ToUpper())) { Write-Host "OSLink: $bin is not on a drive the clients see - install OSLink to <shared drive>:\LDPlayer\OSLink" -ForegroundColor Yellow }
$lines = New-Object System.Collections.Generic.List[string]
$skipped = @()
# the files Client-OslinkDrivers checks: devcon.exe, the drivers (.sys) and catalogs (.cat), Microsoft's WDF co-installer
foreach ($f in @(Get-ChildItem -LiteralPath $bin -File -Force | Where-Object { $_.Name -ieq 'devcon.exe' -or $_.Extension -in '.sys', '.cat' -or $_.Name -like 'Wdf*.dll' })) {
  $s = Get-AuthenticodeSignature -LiteralPath $f.FullName
  $subj = if ($s.SignerCertificate) { $s.SignerCertificate.Subject } else { '' }
  if ($s.Status -eq 'Valid' -and $subj -match '(?i)Chang ?Zhi|XuanZhi|Microsoft Windows Hardware Compatibility Publisher|Microsoft Windows Component Publisher|Microsoft Windows,') {
    $lines.Add(('{0} {1} {2}' -f (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash, $s.SignerCertificate.Thumbprint, $f.Name))
  } else { $skipped += "$($f.Name) ($($s.Status) $($subj -replace ',.*$', ''))" }
}
Write-Host "OSLink $bin : $($lines.Count) files trusted for the clients$(if ($skipped) { '; not trusted: ' + ($skipped -join ', ') })"
if ($Check) { $lines | ForEach-Object { Write-Host "  $_" }; exit 0 }
$out = Join-Path $DataDir 'Oslink'; New-Item -ItemType Directory -Force -Path $out | Out-Null
$all = @("# OSLink files the clients may trust (Master-Snapshot-Oslink.ps1 on $env:COMPUTERNAME $(Get-Date -Format 'yyyy-MM-dd HH:mm'), bin $bin): SHA256 signer-thumbprint file") + $lines
[IO.File]::WriteAllLines((Join-Path $out 'trusted.txt'), [string[]]$all, (New-Object Text.UTF8Encoding $false))
Write-Host "  -> $out\trusted.txt"
exit 0
