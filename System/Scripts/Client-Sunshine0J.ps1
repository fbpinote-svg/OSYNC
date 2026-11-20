# Client-Sunshine0J.ps1 - CLIENT PC: the game menu card "Sunshine 0JAYSHOP" (System\Client\Sunshine0J.vbs runs this hidden).
# Starts the shop's newer Sunshine (v1.0.0-beta.4, Tools\Sunshine0J) on demand - it is NOT a service and does NOT start at
# boot (17 Nov 2026, the owner: the Sunshine already in the client image starts at boot and the two must not clash).
#   1 already running from Tools\Sunshine0J  -> nothing to do (it keeps running)
#   2 the image's own Sunshine (any service / sunshine.exe from another folder) is stopped first - same ports. Only stopped:
#     its service stays as it was, so it is back at the next boot (a diskless reboot also resets everything below)
#   3 port from this PC's IP like the shop Sunshine: 192.168.51.(100+n) -> 20000 + n x 100 (web page = that + 1),
#     other IPs -> Sunshine's own default (47989 / web 47990). Display, graphics card, encoder: automatic.
#   4 Windows Firewall on -> one allow rule for this sunshine.exe (the image's rules are for its own sunshine.exe)
#   5 sunshine.exe <its config> started hidden (tray icon). Log: C:\Users\Public\OSYNC-Sunshine0J.log
#   -Stop   stop it again (the image's Sunshine service is started back)      -Check   report only
#   -AutoStart  (18 Nov 2026, logon task OSYNC-Sunshine0J = Client-Install step 1u): start it in the tray at logon - but a PC
#               that has a Sunshine of its own (service / install folder / running) is left alone: nothing stopped or started
#   -Service    (18 Nov 2026, Client-Install step 0 at the very start of the boot): the same, but as the Windows service
#               SunshineService (tools\sunshinesvc.exe, like the shop's own Sunshine): it starts sunshine.exe from the start of
#               Windows (also at the sign-in screen), restarts it if it dies, and sunshine.exe puts its panel in the tray (--hidden)
param([switch]$Stop, [switch]$Check, [switch]$AutoStart, [switch]$Service)
. (Join-Path $PSScriptRoot 'Common.ps1')
$log = Join-Path $env:PUBLIC 'OSYNC-Sunshine0J.log'
function Log([string]$m) { $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"; Write-Host $l; try { Add-Content -LiteralPath $log -Value $l -Encoding UTF8 } catch { } }
if (Test-IsMaster) { Log 'this is the master - Sunshine 0JAYSHOP is for client PCs'; exit 0 }

$dir  = Join-Path $ToolsDir 'Sunshine0J'
$exe  = Join-Path $dir 'sunshine.exe'
$conf = Join-Path $dir 'config\sunshine.conf'
if (-not (Test-Path -LiteralPath $exe)) { Log "not found: $exe"; exit 1 }
$mine = @(Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $exe })
$theirSvc = @(Get-CimInstance Win32_Service | Where-Object { ($_.Name -match '(?i)sunshine' -or $_.PathName -match '(?i)sunshine') -and $_.PathName -notlike "*$dir*" })
$theirProc = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)^sunshine' -and $_.ExecutablePath -and $_.ExecutablePath -notlike "$dir\*" })

if ($Check) {
  Log "Sunshine 0JAYSHOP running: $([bool]$mine.Count) | image's Sunshine services: $(($theirSvc | ForEach-Object { "$($_.Name)=$($_.State)" }) -join ', ') | other sunshine processes: $($theirProc.Count)"
  exit 0
}
if ($Stop) {
  $mine | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  foreach ($s in $theirSvc) { if ($s.StartMode -eq 'Auto') { try { Start-Service -Name $s.Name -ErrorAction Stop; Log "image's Sunshine started back: $($s.Name)" } catch { Log "could not start $($s.Name): $($_.Exception.Message)" } } }
  Log 'Sunshine 0JAYSHOP stopped'; exit 0
}
if ($mine.Count) { Log 'already running - nothing to do'; exit 0 }
if ($AutoStart -or $Service) {
  $own = @($theirSvc | Where-Object { $_.StartMode -ne 'Disabled' } | ForEach-Object { "service $($_.Name)" }) + @($theirProc | ForEach-Object { "running $($_.ExecutablePath)" })
  foreach ($p in @('C:\Program Files\Sunshine', 'C:\Sunshine') + @(Get-ChildItem 'C:\Users\*\Sunshine' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)) { if (Test-Path -LiteralPath (Join-Path $p 'sunshine.exe')) { $own += "installed $p" } }
  if ($own.Count) { Log "autostart: this PC has its own Sunshine - not started ($($own -join '; '))"; exit 0 }
  $mySvc = Get-CimInstance Win32_Service -Filter "Name='SunshineService'" -ErrorAction SilentlyContinue
  if ($Service -and $mySvc -and $mySvc.State -eq 'Running' -and $mySvc.PathName -like "*$dir*") { Log 'service: SunshineService (0JAYSHOP) already running'; exit 0 }
  Log 'autostart: no other Sunshine on this PC - starting Sunshine 0JAYSHOP in the tray'
}

# 2 the image's Sunshine off (same ports) - card only: -AutoStart / -Service never get here when there is one
foreach ($s in @(if (-not ($AutoStart -or $Service)) { $theirSvc })) {
  if ($s.State -eq 'Running') { try { Stop-Service -Name $s.Name -Force -ErrorAction Stop; Log "image's Sunshine service stopped: $($s.Name) (back at the next boot)" } catch { Log "could not stop $($s.Name): $($_.Exception.Message)" } }
}
Start-Sleep -Seconds 2
foreach ($p in @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '(?i)^sunshine' -and $_.ExecutablePath -and $_.ExecutablePath -notlike "$dir\*" })) {
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; Log "stopped $($p.Name) from $($p.ExecutablePath)"
}

# 3 port from the IP (the config copy on this PC; a diskless reboot puts the shared one back)
$ip = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^192\.168\.51\.(\d+)$' } | ForEach-Object IPAddress) | Select-Object -First 1
$port = $null
if ($ip -and $ip -match '\.(\d+)$') { $n = [int]$Matches[1] - 100; if ($n -ge 1 -and $n -le 99) { $port = 20000 + $n * 100 } }
$text = [IO.File]::ReadAllText($conf, [Text.Encoding]::UTF8)
$text = [regex]::Replace($text, '(?m)^\s*port\s*=.*(\r?\n)?', '')
if ($port) { $text = $text.TrimEnd() + "`r`nport = $port`r`n" }
[IO.File]::WriteAllText($conf, $text, (New-Object Text.UTF8Encoding($false)))
Log "IP $ip -> port $(if ($port) { "$port (web page $($port + 1))" } else { 'Sunshine default 47989 (web page 47990)' })"

# 4 firewall rule for this sunshine.exe when Windows Firewall is on
if (@(Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object Enabled).Count) {
  $rn = 'OSYNC Sunshine 0JAYSHOP'
  if (-not (Get-NetFirewallRule -DisplayName $rn -ErrorAction SilentlyContinue)) {
    try { New-NetFirewallRule -DisplayName $rn -Direction Inbound -Program $exe -Action Allow -Profile Any -ErrorAction Stop | Out-Null; Log "firewall: allow rule added for $exe" } catch { Log "firewall rule: $($_.Exception.Message)" }
  }
}

# 5 start it: as the service SunshineService (-Service) or hidden right now (card / -AutoStart)
if ($Service) {
  $svcExe = Join-Path $dir 'tools\sunshinesvc.exe'
  if (-not (Test-Path -LiteralPath $svcExe)) { Log "service: not found $svcExe"; exit 1 }
  $verb = if (Get-CimInstance Win32_Service -Filter "Name='SunshineService'" -ErrorAction SilentlyContinue) { 'config' } else { 'create' }
  $out = & sc.exe $verb SunshineService binPath= "`"$svcExe`"" start= auto DisplayName= 'Sunshine Service' 2>&1
  if ($LASTEXITCODE) { Log "service: sc $verb failed ($LASTEXITCODE) $out"; exit 1 }
  try { Start-Service -Name SunshineService -ErrorAction Stop } catch { Log "service: could not start: $($_.Exception.Message)"; exit 1 }
  $ok = 0
  for ($i = 0; $i -lt 20 -and -not $ok; $i++) { Start-Sleep -Seconds 1; $ok = @(Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" | Where-Object { $_.ExecutablePath -ieq $exe }).Count }
  Log "service: SunshineService (0JAYSHOP, $svcExe) $(if ($ok) { 'started - sunshine.exe running' } else { 'started, sunshine.exe not seen yet (it waits for a desktop session)' })"
  exit 0
}
Start-Process -FilePath $exe -ArgumentList ('"' + $conf + '"') -WorkingDirectory $dir -WindowStyle Hidden
Start-Sleep -Seconds 4
$ok = @(Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" | Where-Object { $_.ExecutablePath -ieq $exe }).Count
Log "Sunshine 0JAYSHOP $(if ($ok) { 'started' } else { 'did NOT stay running - see its log in ' + (Join-Path $dir 'config') })"
exit $(if ($ok) { 0 } else { 1 })
