# Client-OslinkHelper.ps1 - CLIENT: runs hidden after logon (task OSYNC-OslinkHelper -> System\Client\OslinkHelper.vbs, made by
# Client-OslinkLogin.ps1 = Client-Install step 1k). Keeps THIS PC's own OSLink sign-in on the master:
#   - first time (boot step found no record): OSLink signs in with the master's key, sees a new computer and asks
#     "new computer?" (Thai dialog with buttons Yes / Decline). Answered Yes here, only when UI Automation can read that
#     exact text and a button named Yes in Thai (never clicks blind) - otherwise it stays for a person to answer.
#   - whenever OSLink has saved a sign-in of its own (accounts\<uid>\userinfo.config written after this boot, own MAC in
#     settings.config) and it differs from what the master has: sent to the master (Master-OslinkLogins.ps1), which keeps it
#     for this PC's IP; the boot step puts it back at the next boot. A later change (OSLink renewed its key) is sent again.
# Stops after -Minutes (30). Log: C:\Users\Public\OSYNC-OslinkHelper.log
# Tests: -TestDir <folder> (fake OSLink: <folder>\userData, state <folder>\state.json, registry HKCU\Software\OSYNC-OslinkLoginTest)
#        -Master <host:port>   -Once (one look, no waiting)
param([string]$TestDir, [string]$Master, [switch]$Once, [int]$Minutes = 30)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestDir) { exit 0 }
$created = $false
$mutex = New-Object Threading.Mutex($true, 'Local\OSYNC-OslinkHelper', [ref]$created)
if (-not $created -and -not $TestDir) { exit 0 }

$log = if ($TestDir) { Join-Path $TestDir 'helper.log' } else { Join-Path $env:PUBLIC 'OSYNC-OslinkHelper.log' }
function Log([string]$s) { try { Add-Content -LiteralPath $log -Value ('{0:yyyy-MM-dd HH:mm:ss} {1} {2}' -f (Get-Date), $env:USERNAME, $s) -Encoding UTF8 } catch { } }
$stateFile = if ($TestDir) { Join-Path $TestDir 'state.json' } else { Join-Path $env:PUBLIC 'OSYNC-OslinkLogin.state.json' }
$state = $null; try { $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json } catch { }
if (-not $state -or $state.mode -notin 'first', 'restore') { Log "nothing to do (boot step state: $(if ($state) { $state.mode } else { 'none' }))"; exit 0 }
$since = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$state.at).LocalDateTime
$hostPort = if ($Master) { $Master } else { "$($state.master)" }

function Find-OslinkRoot {
  $svc = Get-CimInstance Win32_Service -Filter "Name='LDRemoteSvc'" -ErrorAction SilentlyContinue
  if ($svc -and $svc.PathName) {
    $m = [regex]::Match($svc.PathName, '^\s*"([^"]+)"'); if (-not $m.Success) { $m = [regex]::Match($svc.PathName, '^\s*(\S+?\.exe)') }
    if ($m.Success) { $r = Split-Path -Parent (Split-Path -Parent $m.Groups[1].Value); if (Test-Path -LiteralPath (Join-Path $r 'userData')) { return $r } }
  }
  foreach ($d in (Get-SharedDrives).ToCharArray()) { $r = "${d}:\LDPlayer\OSLink"; if (Test-Path -LiteralPath (Join-Path $r 'userData')) { return $r } }
  ''
}
$olRoot = if ($TestDir) { $TestDir } else { Find-OslinkRoot }
if (-not $olRoot) { Log 'OSLink not found'; exit 0 }
$acc = Join-Path $olRoot 'userData\accounts'

# ---------- this PC's sign-in as the master keeps it ----------
function Get-Rcmac([string]$which) {
  $sub = if ($TestDir) { if ($which -eq 'hklm') { 'Software\OSYNC-OslinkLoginTest\m\SOFTWARE\ld\OSLink' } else { 'Software\OSYNC-OslinkLoginTest\u\Software\ld\OSLink' } } else { if ($which -eq 'hklm') { 'SOFTWARE\ld\OSLink' } else { 'Software\ld\OSLink' } }
  $base = if ($TestDir -or $which -eq 'hkcu') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64') }
  $k = $base.OpenSubKey($sub); if (-not $k) { return '' }
  try { "$($k.GetValue('rcmac', ''))" } finally { $k.Close() }
}
function Get-Signin {
  $ui = Get-ChildItem -LiteralPath $acc -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4,30}$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'userinfo.config')) } | Sort-Object { (Get-Item -LiteralPath (Join-Path $_.FullName 'userinfo.config')).LastWriteTime } -Descending | Select-Object -First 1
  if (-not $ui) { return $null }
  $uif = Join-Path $ui.FullName 'userinfo.config'
  $mac = ''
  try { $raw = ([IO.File]::ReadAllText((Join-Path $acc 'settings.config'))).Trim([char]0xFEFF).Trim(); if ($raw) { $mac = "$(($raw | ConvertFrom-Json).cacheIpAdress)" } } catch { }
  $files = [ordered]@{}
  foreach ($f in 'userinfo.config', 'user.ini') { $p = Join-Path $ui.FullName $f; if (Test-Path -LiteralPath $p) { $files["accounts/$($ui.Name)/$f"] = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) } }
  $lu = Join-Path $acc 'lastuser.data'; if (Test-Path -LiteralPath $lu) { $files['accounts/lastuser.data'] = [Convert]::ToBase64String([IO.File]::ReadAllBytes($lu)) }
  [pscustomobject]@{ pc = $env:COMPUTERNAME; uid = $ui.Name; mac = $mac; rcmac = [ordered]@{ hklm = (Get-Rcmac 'hklm'); hkcu = (Get-Rcmac 'hkcu') }; files = $files; savedAt = (Get-Item -LiteralPath $uif).LastWriteTime }
}
# same fingerprint as Client-OslinkLogin.ps1 writes into the state file ("baseline" = what it put back from the master)
function Get-Hash($s) {
  $t = (@($s.files.Keys) | Sort-Object | ForEach-Object { "$_=$($s.files[$_])" }) -join '|'
  $t += "|$($s.mac)|$($s.rcmac.hklm)|$($s.rcmac.hkcu)"
  $sha = [Security.Cryptography.SHA256]::Create(); try { ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)) | ForEach-Object { $_.ToString('x2') }) -join '' } finally { $sha.Dispose() }
}
function Send-Signin($s) {
  $body = ConvertTo-Json -InputObject ([ordered]@{ pc = $s.pc; uid = $s.uid; mac = $s.mac; rcmac = $s.rcmac; files = $s.files }) -Depth 5 -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  $rq = [Net.HttpWebRequest]::Create("http://$hostPort/oslink-login"); $rq.Method = 'POST'; $rq.ContentType = 'application/json'; $rq.Timeout = 5000; $rq.ContentLength = $bytes.Length
  $st = $rq.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
  $rs = $rq.GetResponse(); $rs.Close()
}

# ---------- "new computer?" -> yes (first time only, only when the text can be read) ----------
$NewPcText = [regex]::Unescape('\u0E04\u0E2D\u0E21\u0E1E\u0E34\u0E27\u0E40\u0E15\u0E2D\u0E23\u0E4C\u0E40\u0E04\u0E23\u0E37\u0E48\u0E2D\u0E07\u0E43\u0E2B\u0E21\u0E48')   # "new computer" in Thai
$YesText = [regex]::Unescape('\u0E43\u0E0A\u0E48')   # "yes" in Thai
$script:uiaReady = $false; $script:clicked = $false; $script:seenNote = $false
function Try-AnswerNewPc {
  if ($TestDir -or $script:clicked) { return }
  $ids = @(Get-Process ldremote -ErrorAction SilentlyContinue | ForEach-Object Id)
  if (-not $ids.Count) { return }
  if (-not $script:uiaReady) { Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes; $script:uiaReady = $true }
  $A = [Windows.Automation.AutomationElement]
  $seen = @()
  foreach ($id in $ids) {
    $wins = $A::RootElement.FindAll([Windows.Automation.TreeScope]::Children, (New-Object Windows.Automation.PropertyCondition($A::ProcessIdProperty, [int]$id)))
    foreach ($w in $wins) {
      $all = $w.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)
      $names = @($w.Current.Name) + @($all | ForEach-Object { $_.Current.Name } | Where-Object { $_ })
      $r = $w.Current.BoundingRectangle
      $seen += "'$($w.Current.Name)' $([int]$r.Width)x$([int]$r.Height) [$($all.Count) parts]"
      if (-not ($names | Where-Object { $_ -like "*$NewPcText*" })) { continue }
      $yes = $all | Where-Object { $_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name -eq $YesText } | Select-Object -First 1
      if (-not $yes) { Log "new-computer question found but no button named yes (parts: $(($names | Select-Object -First 12) -join ' | '))"; continue }
      try { ($yes.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)).Invoke(); $script:clicked = $true; Log 'answered "new computer?" -> yes'; return } catch { Log "yes button found but could not press it: $($_.Exception.Message)" }
    }
  }
  if (-not $script:seenNote -and $seen.Count) { $script:seenNote = $true; Log "OSLink windows (UI Automation): $($seen -join '; ')" }
}

# ---------- watch ----------
Log "start (boot step: $($state.mode), master $hostPort)"
$lastSent = ''
if ($state.mode -eq 'restore' -and $state.baseline) { $lastSent = "$($state.baseline)" }   # what the boot step put back = what the master has
$deadline = (Get-Date).AddMinutes($Minutes)
do {
  if ($state.mode -eq 'first') { try { Try-AnswerNewPc } catch { Log "UI Automation error: $($_.Exception.Message)"; $script:clicked = $true } }
  $s = Get-Signin
  if ($s -and $s.mac -and -not $script:macNote -and $s.savedAt -lt $since.AddSeconds(-2)) { $script:macNote = $true; Log "OSLink wrote this PC's MAC ($($s.mac)) but has not saved a new sign-in yet (userinfo.config from $($s.savedAt))" }
  # a sign-in of this PC's own: saved after this boot and with this PC's own MAC
  if ($s -and $s.mac -and $s.savedAt -ge $since.AddSeconds(-2)) {
    $h = Get-Hash $s
    if ($h -ne $lastSent) {
      try { Send-Signin $s; $lastSent = $h; Log "sent this PC's sign-in to the master (uid $($s.uid), MAC $($s.mac), files $($s.files.Count))" }
      catch {
        # 403 = the master keeps only the shop's OSLink account (the one signed in on the master, 18 Nov 2026): stop sending it
        $we = $_.Exception; while ($we -and -not ($we -is [Net.WebException])) { $we = $we.InnerException }
        $code = 0; if ($we -and $we.Response) { $code = [int]$we.Response.StatusCode }
        if ($code -eq 403) { $lastSent = $h; Log "not kept: the master keeps only the shop's OSLink account (signed in on the master) - this sign-in (uid $($s.uid)) is gone at the next reboot" }
        else { Log "could not send to the master ($hostPort): $($_.Exception.Message)" }
      }
    }
  }
  if ($Once) { break }
  Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)
Log 'stop'
