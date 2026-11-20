# Master-SteamQueue.ps1 - MASTER: the worker of the Steam game requests (SteamQueue-Lib.ps1). One job at a time, oldest first:
#   1 checking    already in a shop Steam library -> "exists"; game info (name, installdir, build, depots, size) from
#                 api.steamcmd.net (AppID only); pick the shared drive with a Steam library and the most free space where
#                 free - game size stays above SteamRequestMinFreeGB (30 GB)
#   2 waiting-qr  DepotDownloader (Tools\DepotDownloader, SteamRE 3.4.0) -qr: the QR it prints goes to the job, the client
#                 menu draws it, the customer approves it in the Steam app on their phone (their own account, this download
#                 only - nothing is saved). Not scanned in SteamRequestQrMinutes (5) -> failed
#   3 downloading into <drive>:\OSYNCStaging\<AppID> (never into the library half-done); stops when the drive would drop
#                 under the free-space limit, or on cancel
#   4 verifying   size + SHA1 of every file against the depot manifests DepotDownloader saved
#   5 importing   rename into <drive>:\SteamLibrary\steamapps\common\<installdir> (same drive) + appmanifest_<AppID>.acf;
#                 Master-Watch sees the new appmanifest and updates the menu list; clients see the game after a reboot
# A request again after a failure reuses the files (DepotDownloader -validate). An old folder of the game without an
# appmanifest is reused the same way. Started by the listener when a job comes in; exits after a while with nothing to do.
# Log: C:\ProgramData\OSYNC\SteamQueue\worker.log, per job jobs\<id>.log (DepotDownloader's output).
# Tests: -TestLibrary <folder with steamapps\common> (only library, no drive rules), -Anonymous (no QR: free/anonymous apps),
#        -IdleSeconds <n>
param([string]$TestLibrary = '', [switch]$Anonymous, [int]$IdleSeconds = 90)
# a test listener passes the test library on to the worker it starts (env OSYNC_SQ_TESTLIB)
if (-not $TestLibrary -and $env:OSYNC_SQ_TESTLIB) { $TestLibrary = $env:OSYNC_SQ_TESTLIB }
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'SteamQueue-Lib.ps1')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $SqJobs | Out-Null
$created = $false
$mutex = New-Object Threading.Mutex($true, $SqWorkerMutex, [ref]$created)
if (-not $created) { exit 0 }
$WorkerLog = Join-Path $SqDir 'worker.log'
function Log([string]$m) { try { [IO.File]::AppendAllText($WorkerLog, ('{0} {1}{2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m, "`r`n"), $SqUtf8) } catch { } }

Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.Security.Cryptography;
public class OsyncSqEntry { public string Name; public long Size; public uint Flags; public string Sha; }
public static class OsyncSq {
  static ulong V(byte[] b, ref int i) { ulong r = 0; int s = 0; while (true) { byte x = b[i++]; r |= (ulong)(x & 0x7f) << s; s += 7; if (x < 0x80) return r; } }
  static void Skip(byte[] b, ref int i, int t) {
    if (t == 0) V(b, ref i); else if (t == 1) i += 8; else if (t == 5) i += 4;
    else if (t == 2) { int n = (int)V(b, ref i); i += n; } else throw new InvalidDataException("wire type " + t);
  }
  static string Hex(byte[] b, int i, int n) { var sb = new StringBuilder(n * 2); for (int k = 0; k < n; k++) sb.Append(b[i + k].ToString("x2")); return sb.ToString(); }
  // a Steam depot manifest (magic 0x71F617D0 + length + ContentManifestPayload): field 1 = file mapping
  // (1 name, 2 size, 3 flags, 5 sha_content)
  public static List<OsyncSqEntry> ParseManifest(string path) {
    byte[] b = File.ReadAllBytes(path);
    if (b.Length < 8 || BitConverter.ToUInt32(b, 0) != 0x71F617D0) throw new InvalidDataException("not a Steam depot manifest: " + path);
    int end = 8 + (int)BitConverter.ToUInt32(b, 4), i = 8;
    var list = new List<OsyncSqEntry>();
    while (i < end) {
      ulong key = V(b, ref i); int f = (int)(key >> 3), t = (int)(key & 7);
      if (t == 2 && f == 1) {
        int n = (int)V(b, ref i), e = i + n; var m = new OsyncSqEntry();
        while (i < e) {
          ulong k2 = V(b, ref i); int f2 = (int)(k2 >> 3), t2 = (int)(k2 & 7);
          if (t2 == 2) { int n2 = (int)V(b, ref i); if (f2 == 1) m.Name = Encoding.UTF8.GetString(b, i, n2).Replace('/', '\\'); else if (f2 == 5) m.Sha = Hex(b, i, n2); i += n2; }
          else if (t2 == 0) { ulong v = V(b, ref i); if (f2 == 2) m.Size = (long)v; else if (f2 == 3) m.Flags = (uint)v; }
          else Skip(b, ref i, t2);
        }
        list.Add(m);
      } else Skip(b, ref i, t);
    }
    return list;
  }
  public static string Sha1(string path) {
    using (var s = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
    using (var h = SHA1.Create()) { return Hex(h.ComputeHash(s), 0, 20); }
  }
}
'@

function Set-SqState($J, [string]$State, [string]$Message, [int]$Progress = -1) {
  $J.state = $State; if ($Message) { $J.message = $Message }; if ($Progress -ge 0) { $J.progress = $Progress }
  Write-SqJob $J
}
function Stop-SqJob($J, [string]$State, [string]$Message) { $J.qr = $null; Set-SqState $J $State $Message; Log "$($J.id) $State : $Message" }

function Get-SqAppInfo([int]$App) {
  $r = Invoke-RestMethod -Uri "https://api.steamcmd.net/v1/info/$App" -Headers @{ 'User-Agent' = 'osync-steamqueue' } -TimeoutSec 40 -UseBasicParsing
  if ($r.status -ne 'success') { throw "api.steamcmd.net: $($r.status)" }
  $d = $r.data."$App"
  if (-not $d -or -not $d.common) { throw 'ไม่พบเกมนี้ใน Steam (AppID ผิด?)' }
  $d
}
# the depots DepotDownloader takes by default on this PC: Windows, 64-bit or any, English or no language, no DLC / low violence
function Get-SqDepots($Info) {
  $list = @()
  foreach ($p in $Info.depots.PSObject.Properties) {
    if ($p.Name -notmatch '^\d+$') { continue }
    $v = $p.Value; $c = $v.config
    if ($c) {
      if ($c.oslist -and (@("$($c.oslist)" -split ',') -notcontains 'windows')) { continue }
      if ($c.osarch -and "$($c.osarch)" -ne '64') { continue }
      if ($c.language -and "$($c.language)" -ne 'english') { continue }
      if ("$($c.lowviolence)" -eq '1') { continue }
    }
    if ($v.dlcappid) { continue }
    $shared = "$($v.sharedinstall)" -eq '1'
    $size = 0L; if ($v.manifests -and $v.manifests.public -and $v.manifests.public.size) { $size = [int64]$v.manifests.public.size }
    $list += [pscustomobject]@{ Id = [int]$p.Name; Size = $size; Shared = $shared; FromApp = "$($v.depotfromapp)" }
  }
  $list
}
# Steam libraries: Get-SteamLibraries + the Steam folder from HKLM (this worker runs as SYSTEM: no HKCU Steam path)
function Get-SqLibraries {
  $l = New-Object System.Collections.Generic.List[string]
  foreach ($x in @(Get-SteamLibraries)) { $l.Add($x) }
  $hk = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
  if ($hk) {
    $l.Add($hk)
    $vdf = Join-Path $hk 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) { [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"') | ForEach-Object { $l.Add(($_.Groups[1].Value -replace '\\\\', '\')) } }
  }
  $seen = @{}
  foreach ($x in $l) { $x = "$x".TrimEnd('\'); if ($x -and -not $seen.ContainsKey($x.ToLower()) -and (Test-Path -LiteralPath (Join-Path $x 'steamapps'))) { $seen[$x.ToLower()] = 1; $x } }
}
function Get-FreeBytes([string]$Path) { try { [int64](New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($Path))).AvailableFreeSpace } catch { 0L } }
function Get-DirBytes([string]$Path) { $s = 0L; Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { $s += $_.Length }; $s }
function Get-QrRows([System.Collections.Generic.List[string]]$Lines) {
  # DepotDownloader draws each module as 2 characters (dark = a block, shown as "??" when the console cannot print it),
  # quiet zone included -> rows of 0/1 without the quiet zone; $null unless it is a whole, square QR code
  $rows = @(foreach ($l in $Lines) { $s = ''; for ($i = 0; $i + 1 -lt $l.Length; $i += 2) { $s += $(if ($l[$i] -ne ' ') { '1' } else { '0' }) }; $s })
  $rows = @($rows | Where-Object { $_ -match '1' })
  if ($rows.Count -lt 21) { return $null }
  $w = ($rows | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
  $rows = @($rows | ForEach-Object { $_.PadRight($w, '0') })
  $first = ($rows | ForEach-Object { $_.IndexOf('1') } | Measure-Object -Minimum).Minimum
  $last = ($rows | ForEach-Object { $_.LastIndexOf('1') } | Measure-Object -Maximum).Maximum
  $rows = @($rows | ForEach-Object { $_.Substring($first, $last - $first + 1) })
  if ($rows[0].Length -ne $rows.Count -or (($rows.Count - 17) % 4) -ne 0) { return $null }
  if (-not $rows[0].StartsWith('1111111')) { return $null }   # the top-left finder pattern
  , $rows
}
function Write-SqAppManifest([string]$Lib, $J, $Info, $Depots, [hashtable]$Man, [hashtable]$Sizes) {
  $q = { param($s) '"' + ("$s" -replace '\\', '\\' -replace '"', '\"') + '"' }
  $t = [char]9
  $total = 0L; foreach ($k in $Sizes.Keys) { $total += $Sizes[$k] }
  $o = New-Object System.Collections.Generic.List[string]
  $o.Add('"AppState"'); $o.Add('{')
  $kv = [ordered]@{ appid = $J.app; universe = 1; name = $Info.common.name; StateFlags = 4; installdir = $J.installdir
    LastUpdated = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); LastPlayed = 0; SizeOnDisk = $total; StagingSize = 0
    buildid = "$($Info.depots.branches.public.buildid)"; LastOwner = 0; DownloadType = 1; UpdateResult = 0; BytesToDownload = 0
    BytesDownloaded = 0; BytesToStage = 0; BytesStaged = 0; TargetBuildID = "$($Info.depots.branches.public.buildid)"
    AutoUpdateBehavior = 0; AllowOtherDownloadsWhileRunning = 0; ScheduledAutoUpdate = 0 }
  foreach ($k in $kv.Keys) { $o.Add("$t$(& $q $k)$t$t$(& $q $kv[$k])") }
  $o.Add("$t`"InstalledDepots`""); $o.Add("$t{")
  foreach ($d in ($Man.Keys | Sort-Object { [int]$_ })) {
    $o.Add("$t$t$(& $q $d)"); $o.Add("$t$t{"); $o.Add("$t$t$t`"manifest`"$t$t$(& $q $Man[$d])"); $o.Add("$t$t$t`"size`"$t$t$(& $q $Sizes[$d])"); $o.Add("$t$t}")
  }
  $o.Add("$t}")
  $sh = @($Depots | Where-Object { $_.Shared -and $_.FromApp })
  if ($sh) { $o.Add("$t`"SharedDepots`""); $o.Add("$t{"); foreach ($s in $sh) { $o.Add("$t$t$(& $q $s.Id)$t$t$(& $q $s.FromApp)") }; $o.Add("$t}") }
  foreach ($blk in 'UserConfig', 'MountedConfig') { $o.Add("$t`"$blk`""); $o.Add("$t{"); $o.Add("$t$t`"language`"$t$t`"english`""); $o.Add("$t}") }
  $o.Add('}')
  $acf = Join-Path $Lib "steamapps\appmanifest_$($J.app).acf"
  [IO.File]::WriteAllText("$acf.tmp", (($o -join "`n") + "`n"), $SqUtf8)
  Move-Item -LiteralPath "$acf.tmp" -Destination $acf -Force
  $acf
}

function Invoke-SqJob($J) {
  $set = Get-SqSettings
  $minFree = [int64]$set.MinFreeGB * 1GB
  Log "$($J.id) start app $($J.app) for $($J.pc) ($($J.ip))"
  if (Test-SqCancel $J) { Stop-SqJob $J 'canceled' 'ยกเลิกแล้ว'; return }
  if (-not (Test-Path -LiteralPath $set.Exe)) { Stop-SqJob $J 'failed' 'เครื่องแม่ยังไม่มีตัวโหลด (Tools\DepotDownloader) แจ้งพนักงาน'; return }
  Set-SqState $J 'checking' 'กำลังตรวจข้อมูลเกม' 0

  $libs = @(if ($TestLibrary) { $TestLibrary.TrimEnd('\') } else { Get-SqLibraries })
  $shared = Get-SharedDrives
  foreach ($l in $libs) {
    if (-not $TestLibrary -and $shared.IndexOf($l.Substring(0, 1).ToUpper()) -lt 0) { continue }   # clients cannot see it (e.g. C:)
    $acf = Join-Path $l "steamapps\appmanifest_$($J.app).acf"
    if (Test-Path -LiteralPath $acf) {
      $n = [regex]::Match([IO.File]::ReadAllText($acf), '"name"\s+"([^"]*)"').Groups[1].Value
      $J.name = $n; Stop-SqJob $J 'exists' "ร้านมีเกมนี้แล้ว$(if ($n) { " ($n)" }) ถ้ายังไม่เห็นในเมนูให้รีบูตเครื่อง"; return
    }
  }
  try { $info = Get-SqAppInfo $J.app } catch { Stop-SqJob $J 'failed' "ดึงข้อมูลเกมไม่ได้: $($_.Exception.Message)"; return }
  $J.name = "$($info.common.name)"
  $type = "$($info.common.type)".ToLower()
  if ($type -and @('game', 'application', 'tool', 'demo', 'beta') -notcontains $type) { Stop-SqJob $J 'failed' "AppID $($J.app) ไม่ใช่เกม (ประเภท $type) ถ้าเป็น DLC ให้ขอเกมหลัก"; return }
  $dir = "$($info.config.installdir)".Trim()
  if (-not $dir -or $dir -match '[\\/:*?"<>|]|^\.+$|\.\.') { Stop-SqJob $J 'failed' "ชื่อโฟลเดอร์ของเกมใช้ไม่ได้ ($dir)"; return }
  $J.installdir = $dir
  $depots = @(Get-SqDepots $info)
  $est = 0L; foreach ($d in $depots) { if (-not $d.Shared) { $est += $d.Size } }
  $J.sizeGB = [math]::Round($est / 1GB, 1)

  # library: an old folder of this game (no appmanifest) is reused; else the drive with the most room
  $cands = @()
  foreach ($l in $libs) {
    if (-not $TestLibrary -and $set.Drives.IndexOf($l.Substring(0, 1).ToUpper()) -lt 0) { continue }
    if ($l -match '(?i)\\steam$' -and -not $TestLibrary) { continue }   # the Steam program folder itself (F:\Steam) - games go to SteamLibrary folders
    if (-not (Test-Path -LiteralPath (Join-Path $l 'steamapps\common'))) { continue }
    $old = Join-Path $l "steamapps\common\$dir"
    $have = if (Test-Path -LiteralPath $old) { Get-DirBytes $old } else { 0L }
    $cands += [pscustomobject]@{ Lib = $l; Free = (Get-FreeBytes $l); Old = $(if ($have) { $old } else { '' }); Have = $have }
  }
  $pick = $cands | Where-Object Old | Select-Object -First 1
  if ($pick -and ($pick.Free + $pick.Have - $est) -lt $minFree) { Stop-SqJob $J 'failed' "มีไฟล์เก่าของเกมนี้ที่ไดรฟ์ $($pick.Lib.Substring(0,1)) แต่พื้นที่ไม่พอ (ต้องเหลือ $($set.MinFreeGB) GB) แจ้งพนักงาน"; return }
  if (-not $pick) {
    $pick = $cands | Where-Object { ($_.Free - $est) -gt $minFree } | Sort-Object Free -Descending | Select-Object -First 1
    if (-not $pick) {
      $best = $cands | Sort-Object Free -Descending | Select-Object -First 1
      Stop-SqJob $J 'failed' ("พื้นที่ไม่พอ: เกมนี้ประมาณ {0:N1} GB ไดรฟ์ที่ว่างที่สุดเหลือ {1:N0} GB (ต้องเหลือ {2} GB หลังลง) แจ้งพนักงาน" -f ($est / 1GB), $(if ($best) { $best.Free / 1GB } else { 0 }), $set.MinFreeGB)
      return
    }
  }
  $lib = $pick.Lib; $J.drive = $lib.Substring(0, 1).ToUpper()
  $stageRoot = Join-Path ([IO.Path]::GetPathRoot($lib)) 'OSYNCStaging'
  if ($TestLibrary) { $stageRoot = Join-Path (Split-Path -Parent $lib) 'OSYNCStaging' }
  $stage = Join-Path $stageRoot "$($J.app)"
  $meta = Join-Path $stageRoot "_meta\$($J.app)"
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  $revalidate = @(Get-ChildItem -LiteralPath $stage -Force -ErrorAction SilentlyContinue).Count -gt 0
  if ($pick.Old) {
    # same drive: a rename. Its files are checked and only what is missing or wrong is downloaded.
    Get-ChildItem -LiteralPath $pick.Old -Force | ForEach-Object { if (-not (Test-Path -LiteralPath (Join-Path $stage $_.Name))) { Move-Item -LiteralPath $_.FullName -Destination $stage } }
    if (-not @(Get-ChildItem -LiteralPath $pick.Old -Force).Count) { Remove-Item -LiteralPath $pick.Old -Force }
    $revalidate = $true; Log "$($J.id) reusing the old folder $($pick.Old)"
  }
  if ((Test-Path -LiteralPath $meta) -and -not (Test-Path -LiteralPath (Join-Path $stage '.DepotDownloader'))) { Move-Item -LiteralPath $meta -Destination (Join-Path $stage '.DepotDownloader') }
  Write-SqJob $J
  Log "$($J.id) $($J.name) ($dir) ~$($J.sizeGB) GB -> $lib (free $([math]::Round($pick.Free/1GB)) GB) stage $stage revalidate=$revalidate"

  # ---- DepotDownloader ----
  $log = Join-Path $SqJobs "$($J.id).log"
  $ddArgs = @('-app', "$($J.app)", '-dir', "`"$stage`"", '-max-downloads', '16', '-os', 'windows', '-osarch', '64', '-language', 'english')
  if (-not $Anonymous) { $ddArgs += '-qr' }
  if ($revalidate) { $ddArgs += '-validate' }
  $p = Start-Process -FilePath $set.Exe -ArgumentList $ddArgs -WorkingDirectory (Split-Path -Parent $set.Exe) -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden -PassThru
  $null = $p.Handle   # keeps the exit code readable after the process ends
  Set-SqState $J $(if ($Anonymous) { 'downloading' } else { 'checking' }) $(if ($Anonymous) { 'กำลังโหลด' } else { 'กำลังเตรียม QR' })
  $pos = 0L; $partial = ''; $qrLines = $null; $qrStart = $null
  $man = @{}; $cur = ''; $doneDepots = @{}; $finished = $false; $err = ''; $lastErr = ''; $lastWrite = Get-Date; $lastFree = Get-Date
  $depotSize = @{}; foreach ($d in $depots) { $depotSize["$($d.Id)"] = $d.Size }
  $why = ''
  while ($true) {
    $exited = $p.HasExited
    try {
      $fs = New-Object IO.FileStream($log, 'Open', 'Read', 'ReadWrite, Delete')
      if ($fs.Length -gt $pos) { $fs.Position = $pos; $buf = New-Object byte[] ($fs.Length - $pos); $n = $fs.Read($buf, 0, $buf.Length); $pos += $n; $partial += $SqUtf8.GetString($buf, 0, $n) }
      $fs.Dispose()
    } catch { }
    $lines = @($partial -split "`r?`n"); $partial = $lines[-1]
    if ($exited) { $partial = '' } elseif ($lines.Count -le 1) { $lines = @() } else { $lines = $lines[0..($lines.Count - 2)] }
    foreach ($ln in $lines) {
      if ($ln -match 'sign in with this QR code|The QR code has changed') { $qrLines = New-Object System.Collections.Generic.List[string]; continue }
      if ($null -ne $qrLines) {
        if ($ln -notmatch '[A-Za-z0-9]') { $qrLines.Add($ln); continue }   # spaces + one block character (or "?" / U+FFFD)
        $qrLines = $null
      }
      if ($ln -match '^Got AppInfo for|^Using app branch') { if ($J.state -ne 'downloading') { $J.qr = $null; Set-SqState $J 'downloading' 'เข้าสู่ระบบแล้ว กำลังโหลด' } }
      elseif ($ln -match '^Processing depot (\d+)') { $cur = $Matches[1] }
      elseif ($ln -match '^Manifest (\d+) \(' -and $cur) { $man[$cur] = $Matches[1] }
      elseif ($ln -match '^Depot (\d+) - Downloaded') { $doneDepots[$Matches[1]] = 1 }
      elseif ($ln -match '^\s*(\d{1,3}\.\d+)% ') {
        $pct = [double]$Matches[1]
        $tot = 0L; $don = 0L; foreach ($k in $man.Keys) { $sz = [int64]$depotSize[$k]; $tot += $sz; if ($doneDepots.ContainsKey($k)) { $don += $sz } elseif ($k -eq $cur) { $don += [int64]($sz * $pct / 100) } }
        $J.progress = $(if ($est -gt 0) { [int][math]::Min(99, 100 * $don / [math]::Max($est, $tot)) } else { [int]$pct })
      }
      elseif ($ln -match '^Total downloaded:') { $finished = $true }
      elseif ($ln -match 'is not available from this account|No subscription|AccessDenied') { $err = 'บัญชี Steam นี้ไม่มีเกมนี้ (ต้องใช้บัญชีที่มีเกมนี้)' }
      elseif ($ln -match 'not enough space|There is not enough space|disk full') { $err = 'พื้นที่ดิสก์ไม่พอ' }
      elseif ($ln -match '(?i)error|fail|unable|exception') { $lastErr = $ln.Trim() }
    }
    if ($null -ne $qrLines -and $qrLines.Count -ge 21) {
      $rows = Get-QrRows $qrLines
      if ($rows -and (($rows -join '') -ne ($J.qr -join ''))) {
        $J.qr = $rows; if (-not $qrStart) { $qrStart = Get-Date; $J.qrUntil = $qrStart.AddMinutes($set.QrMinutes).ToString('yyyy-MM-dd HH:mm:ss') }
        Set-SqState $J 'waiting-qr' 'สแกน QR ด้วยแอป Steam บนมือถือ (บัญชีที่มีเกมนี้)'
      }
    }
    if ($exited) { break }
    if (Test-SqCancel $J) { $why = 'canceled'; break }
    if ($J.state -eq 'waiting-qr' -and $qrStart -and ((Get-Date) - $qrStart).TotalMinutes -ge $set.QrMinutes) { $why = 'qr'; break }
    if (((Get-Date) - $lastFree).TotalSeconds -ge 10) {
      $lastFree = Get-Date
      if ((Get-FreeBytes $lib) -lt $minFree) { $why = 'space'; break }
    }
    if (((Get-Date) - $lastWrite).TotalSeconds -ge 2) { $lastWrite = Get-Date; Write-SqJob $J }
    Start-Sleep -Milliseconds 700
  }
  if (-not $p.HasExited) { try { Stop-Process -Id $p.Id -Force } catch { }; try { $p.WaitForExit(15000) | Out-Null } catch { } }
  switch ($why) {
    'canceled' { Stop-SqJob $J 'canceled' 'ยกเลิกแล้ว (ไฟล์ที่โหลดไว้เก็บไว้ ขอใหม่แล้วโหลดต่อได้)'; return }
    'qr'       { Stop-SqJob $J 'failed' "ไม่ได้สแกน QR ภายใน $($set.QrMinutes) นาที กดขอใหม่ได้"; return }
    'space'    { Stop-SqJob $J 'failed' "หยุดโหลด: ไดรฟ์ $($J.drive) จะเหลือน้อยกว่า $($set.MinFreeGB) GB แจ้งพนักงาน"; return }
  }
  $code = $p.ExitCode
  if ($err) { Stop-SqJob $J 'failed' $err; return }
  if (-not $finished -or $code -ne 0) {
    $m = if ($lastErr) { $lastErr } else { (Get-Content -LiteralPath "$log.err" -ErrorAction SilentlyContinue | Select-Object -Last 1) }
    if ($m -and $m.Length -gt 160) { $m = $m.Substring(0, 160) }
    Stop-SqJob $J 'failed' "โหลดไม่สำเร็จ (รหัส $code)$(if ($m) { ": $m" }) กดขอใหม่เพื่อโหลดต่อ"; return
  }
  if (-not $man.Count) { Stop-SqJob $J 'failed' 'ไม่มีไฟล์ของเกมนี้ให้โหลดสำหรับ Windows'; return }

  # ---- verify: size + SHA1 of every file in the manifests ----
  Set-SqState $J 'verifying' 'กำลังตรวจไฟล์ (SHA1)' 0
  $entries = New-Object System.Collections.Generic.List[object]; $sizes = @{}
  foreach ($d in $man.Keys) {
    $mf = Join-Path $stage ".DepotDownloader\${d}_$($man[$d]).manifest"
    if (-not (Test-Path -LiteralPath $mf)) { Stop-SqJob $J 'failed' "ไม่พบ manifest ของ depot $d"; return }
    $ents = [OsyncSq]::ParseManifest($mf)
    $s = 0L; foreach ($e in $ents) { if (($e.Flags -band 64) -eq 0) { $s += $e.Size; $entries.Add($e) } }
    $sizes[$d] = $s
  }
  $total = 0L; foreach ($e in $entries) { $total += $e.Size }
  $checked = 0L; $bad = New-Object System.Collections.Generic.List[string]; $lastWrite = Get-Date
  foreach ($e in $entries) {
    if (Test-SqCancel $J) { Stop-SqJob $J 'canceled' 'ยกเลิกแล้ว'; return }
    $f = Join-Path $stage $e.Name
    $fi = New-Object IO.FileInfo $f
    if (-not $fi.Exists -or $fi.Length -ne $e.Size) { $bad.Add($e.Name) }
    elseif ($e.Size -gt 0 -and $e.Sha -and $e.Sha -notmatch '^0+$' -and ([OsyncSq]::Sha1($f) -ne $e.Sha)) { $bad.Add($e.Name) }
    $checked += $e.Size
    if (((Get-Date) - $lastWrite).TotalSeconds -ge 2) { $lastWrite = Get-Date; $J.progress = $(if ($total) { [int](100 * $checked / $total) } else { 100 }); Write-SqJob $J }
  }
  if ($bad.Count) { Stop-SqJob $J 'failed' "ไฟล์ไม่ครบหรือเสีย $($bad.Count) ไฟล์ (เช่น $($bad[0])) กดขอใหม่เพื่อซ่อม"; return }
  Log "$($J.id) verified $($entries.Count) files, $([math]::Round($total/1GB,2)) GB"

  # ---- import: same drive -> renames ----
  Set-SqState $J 'importing' 'กำลังเพิ่มเข้าคลังเกม' 100
  $target = Join-Path $lib "steamapps\common\$dir"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  foreach ($it in @(Get-ChildItem -LiteralPath $stage -Force | Where-Object Name -ne '.DepotDownloader')) {
    $to = Join-Path $target $it.Name
    if (Test-Path -LiteralPath $to) { Stop-SqJob $J 'failed' "มี $to อยู่แล้ว แจ้งพนักงาน"; return }
    Move-Item -LiteralPath $it.FullName -Destination $to
  }
  # DepotDownloader's own records (manifests, depot.config) stay next to the staging folder for the next -validate
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $meta) | Out-Null
  if (Test-Path -LiteralPath $meta) { Remove-Item -LiteralPath $meta -Recurse -Force }
  if (Test-Path -LiteralPath (Join-Path $stage '.DepotDownloader')) { Move-Item -LiteralPath (Join-Path $stage '.DepotDownloader') -Destination $meta }
  if (-not @(Get-ChildItem -LiteralPath $stage -Force).Count) { Remove-Item -LiteralPath $stage -Force }
  $acf = Write-SqAppManifest $lib $J $info $depots $man $sizes
  Log "$($J.id) imported -> $target, $acf"
  Stop-SqJob $J 'done' "โหลดเสร็จแล้ว: $($J.name) (ไดรฟ์ $($J.drive)) รีบูตเครื่องแล้วเกมจะขึ้นในเมนู"
}

# ---------------- the loop ----------------
Log "worker start (pid $PID, user $env:USERNAME)"
# a job that was running when an earlier worker stopped (reboot, crash) cannot go on: only one worker runs at a time
foreach ($j in @(Get-SqJobs | Where-Object { $SqActive -contains $_.state -and $_.state -ne 'queued' })) {
  $j.qr = $null; Set-SqState $j 'failed' 'ระบบโหลดหยุดกลางคัน (เครื่องแม่รีสตาร์ต?) กดขอใหม่เพื่อโหลดต่อ'; Log "$($j.id) was $($j.state) - marked failed"
}
$idleSince = Get-Date
while ($true) {
  $next = Get-SqJobs | Where-Object { $_.state -eq 'queued' } | Select-Object -First 1
  if (-not $next) {
    if (((Get-Date) - $idleSince).TotalSeconds -ge $IdleSeconds) { break }
    Start-Sleep -Seconds 2; continue
  }
  try { Invoke-SqJob $next }
  catch {
    Log "$($next.id) ERROR $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)"
    try { $next.qr = $null; Set-SqState $next 'failed' "ระบบโหลดขัดข้อง: $($_.Exception.Message)" }
    catch {
      # the job file cannot even be written: put it aside, or the loop would pick it up again and again
      Log "$($next.id) cannot write the job file - moved to .bad"
      try { Move-Item -LiteralPath (Join-Path $SqJobs "$($next.id).json") -Destination (Join-Path $SqJobs "$($next.id).bad") -Force } catch { break }
    }
  }
  $idleSince = Get-Date
  # keep the newest 200 jobs, logs for 7 days
  @(Get-ChildItem -LiteralPath $SqJobs -Filter '*.json' -File | Sort-Object Name -Descending | Select-Object -Skip 200) | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  @(Get-ChildItem -LiteralPath $SqJobs -Filter '*.log*' -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }) | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  @(Get-ChildItem -LiteralPath $SqJobs -Filter '*.cancel' -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) }) | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}
Log 'worker idle - exit'
$mutex.ReleaseMutex()
