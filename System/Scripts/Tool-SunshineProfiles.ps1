# Tool-SunshineProfiles.ps1 - MASTER: write this shop's PC profiles into Tools\Sunshine0J\config\sunshine.conf
# (shop_ip_profiles + shop_gateway_list) from the port plan in Settings (SunshineIpBase / SunshinePcPrefix / SunshinePcCount,
# Get-SunshinePlan) - the same plan Client-Sunshine0J.ps1 uses for the port. A branch whose PCs have other IPs or names
# runs it once after the setup (OSYNC.bat > 7 > 24). Everything else in sunshine.conf stays as it is.
#   Tool-SunshineProfiles.ps1            write (the old file -> System\Backup\sunshine-conf-<date>.conf)
#   -DryRun                              only show what would change
#   -Gateway <ip>                        the shop router (default: this PC's default gateway, else <net>.1)
param([switch]$DryRun, [string]$Gateway = '')
. (Join-Path $PSScriptRoot 'Common.ps1')
$conf = Join-Path $ToolsDir 'Sunshine0J\config\sunshine.conf'
if (-not (Test-Path -LiteralPath $conf)) { Write-Host "Sunshine 0JAYSHOP is not here ($conf) - nothing to do"; exit 0 }
$sp = Get-SunshinePlan
if ($sp.Count -lt 1) { Write-Host 'SunshinePcCount is 0 - set the number of client PCs in Settings\settings.txt first' -ForegroundColor Yellow; exit 1 }
if (-not $Gateway) {
  $Gateway = "$(@(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction SilentlyContinue | Where-Object { $_.DefaultIPGateway } | ForEach-Object { @($_.DefaultIPGateway)[0] } | Where-Object { $_ -like "$($sp.Net).*" })[0])"
  if (-not $Gateway) { $Gateway = "$($sp.Net).1" }
}
$items = foreach ($n in 1..$sp.Count) { '{"ip":"' + $sp.Net + '.' + ($sp.Offset + $n) + '","name":"' + $sp.Prefix + $n.ToString('00') + '","port":' + (20000 + $n * 100) + '}' }
$want = [ordered]@{ 'shop_ip_profiles' = '[' + ($items -join ',') + ']'; 'shop_gateway_list' = $Gateway }

$raw = [IO.File]::ReadAllText($conf)
$bom = ([IO.File]::ReadAllBytes($conf) | Select-Object -First 3) -join ',' -eq '239,187,191'
$nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$t = $raw.TrimStart([char]0xFEFF)
$changed = @()
foreach ($k in $want.Keys) {
  $m = [regex]::Match($t, "(?m)^\s*$k\s*=\s*([^\r\n]*)")
  $now = if ($m.Success) { $m.Groups[1].Value.Trim() } else { '' }
  if ($now -eq $want[$k]) { continue }
  $changed += $k
  if ($m.Success) { $t = $t.Substring(0, $m.Index) + "$k = $($want[$k])" + $t.Substring($m.Index + $m.Length) }
  else { $t = $t.TrimEnd() + $nl + "$k = $($want[$k])" + $nl }
}
$first = "$($sp.Prefix)01 = $($sp.Net).$($sp.Offset + 1) port 20100"
$last = "$($sp.Prefix){0} = {1}.{2} port {3}" -f $sp.Count.ToString('00'), $sp.Net, ($sp.Offset + $sp.Count), (20000 + $sp.Count * 100)
Write-Host "Sunshine PC profiles: $($sp.Count) PCs, $first ... $last, router $Gateway"
if (-not $changed) { Write-Host "  $conf already has these profiles - nothing to change" -ForegroundColor Green; exit 0 }
if ($DryRun) { Write-Host "  (DryRun) would rewrite: $($changed -join ', ') in $conf" -ForegroundColor DarkGray; exit 0 }
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$bk = Join-Path $BackupDir ("sunshine-conf-{0}.conf" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $conf -Destination $bk
[IO.File]::WriteAllText($conf, $t, (New-Object Text.UTF8Encoding $bom))
Write-Host "  written: $($changed -join ', ')   (old file: $bk)" -ForegroundColor Green
Write-Host '  client PCs use it after their next reboot'
