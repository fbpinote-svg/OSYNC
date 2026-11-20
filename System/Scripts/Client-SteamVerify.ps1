# Client-SteamVerify.ps1 - "game files exactly as the publisher shipped them" (rule 1 of iPlay's anti-cheat guide), checked on
# THIS PC: every file of a Steam game, as this PC reads it from the shared game disk, against Steam's own depot manifests
# (size + SHA1 per file - the same list Steam's "Verify integrity" uses). Changes nothing.
# Why (20 Nov 2026): Apex closes at "Starting EA Javelin Anticheat..." on the clients but runs on the master from the same
# E:\SteamLibrary, and the master's Steam validate is clean - so: do the clients read the same bytes?
#   Client-SteamVerify.ps1 -AppId 1172470                 check, print the result
#   Client-SteamVerify.ps1 -AppId 1172470 -Report         ... and send it to the master (port 4670, like Client-OslinkReport)
#   -DelaySeconds 240   wait first (boot)    -Quick   sizes only + SHA1 of the files in the game folder's top level
# Boot: Client-Install.ps1 starts it in the background on the PCs in Settings ClientSteamVerify (apps: ClientSteamVerifyApps).
param([Parameter(Mandatory = $true)][string]$AppId, [switch]$Report, [switch]$Quick, [int]$DelaySeconds = 0, [int]$MaxList = 300)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
if ($DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch { }

Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.Security.Cryptography;
public class OsyncSvEntry { public string Name; public long Size; public uint Flags; public string Sha; }
public static class OsyncSv {
  static ulong V(byte[] b, ref int i) { ulong r = 0; int s = 0; while (true) { byte x = b[i++]; r |= (ulong)(x & 0x7f) << s; s += 7; if (x < 0x80) return r; } }
  static void Skip(byte[] b, ref int i, int t) {
    if (t == 0) V(b, ref i); else if (t == 1) i += 8; else if (t == 5) i += 4;
    else if (t == 2) { int n = (int)V(b, ref i); i += n; } else throw new InvalidDataException("wire type " + t);
  }
  static string Hex(byte[] b, int i, int n) { var sb = new StringBuilder(n * 2); for (int k = 0; k < n; k++) sb.Append(b[i + k].ToString("x2")); return sb.ToString(); }
  // Steam depot manifest (magic 0x71F617D0 + length + ContentManifestPayload): field 1 = file mapping (1 name, 2 size, 3 flags, 5 sha_content)
  public static List<OsyncSvEntry> ParseManifest(string path) {
    byte[] b = File.ReadAllBytes(path);
    if (b.Length < 8 || BitConverter.ToUInt32(b, 0) != 0x71F617D0) throw new InvalidDataException("not a Steam depot manifest: " + path);
    int end = 8 + (int)BitConverter.ToUInt32(b, 4), i = 8;
    var list = new List<OsyncSvEntry>();
    while (i < end) {
      ulong key = V(b, ref i); int f = (int)(key >> 3), t = (int)(key & 7);
      if (t == 2 && f == 1) {
        int n = (int)V(b, ref i), e = i + n; var m = new OsyncSvEntry();
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
    using (var s = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1 << 20))
    using (var h = SHA1.Create()) { return Hex(h.ComputeHash(s), 0, 20); }
  }
}
'@

$out = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $out.Add($s); Write-Output $s }
$boot = try { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('yyyy-MM-dd HH:mm') } catch { '?' }
Say ("OSLink report  {0}  phase=steamverify-{1}  now={2}  boot={3}  user={4}" -f $env:COMPUTERNAME, $AppId, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $boot, [Security.Principal.WindowsIdentity]::GetCurrent().Name)

try {
  # the game: appmanifest in one of the Steam libraries this PC sees
  $acf = $null; $lib = $null
  foreach ($l in Get-SteamLibraries) { $p = Join-Path $l "steamapps\appmanifest_$AppId.acf"; if (Test-Path -LiteralPath $p) { $acf = $p; $lib = $l; break } }
  if (-not $acf) { throw "appmanifest_$AppId.acf is in none of the Steam libraries" }
  $t = [IO.File]::ReadAllText($acf)
  $name = [regex]::Match($t, '"name"\s+"([^"]*)"').Groups[1].Value
  $dir = Join-Path $lib ('steamapps\common\' + [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value)
  Say ("game: {0} | buildid {1} | {2} | acf {3:yyyy-MM-dd HH:mm}" -f $name, [regex]::Match($t, '"buildid"\s+"(\d+)"').Groups[1].Value, $dir, (Get-Item -LiteralPath $acf).LastWriteTime)
  $inst = [regex]::Match($t, '(?s)"InstalledDepots"\s*\{(.*?)\n\t\}').Groups[1].Value
  $depots = @([regex]::Matches($inst, '"(\d+)"\s*\{\s*"manifest"\s+"(\d+)"') | ForEach-Object { [pscustomobject]@{ Depot = $_.Groups[1].Value; Gid = $_.Groups[2].Value } })
  if (-not $depots) { throw 'no InstalledDepots in the appmanifest' }

  # Steam keeps each depot's manifest in <Steam>\depotcache (also seen: <library>\steamapps\depotcache)
  # (at boot this runs as SYSTEM: no HKCU Steam path there, so also HKLM's InstallPath and X:\Steam on the shared drives)
  $steamDirs = New-Object System.Collections.Generic.List[string]
  foreach ($c in @((Get-SteamDir), "$((Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath)") + @(([string](Get-SharedDrives)).ToCharArray() | ForEach-Object { "${_}:\Steam" })) {
    if ($c -and (Test-Path -LiteralPath (Join-Path $c 'depotcache'))) { $steamDirs.Add($c) }
  }
  $entries = New-Object System.Collections.Generic.List[object]
  foreach ($d in $depots) {
    $mf = @(@($steamDirs | ForEach-Object { Join-Path $_ "depotcache\$($d.Depot)_$($d.Gid).manifest" }) + (Join-Path $lib "steamapps\depotcache\$($d.Depot)_$($d.Gid).manifest")) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $mf) { Say "WARNING depot $($d.Depot) manifest $($d.Gid): file not found in depotcache - its files are not checked"; continue }
    $list = [OsyncSv]::ParseManifest($mf)
    $files = @($list | Where-Object { -not ($_.Flags -band 64) })
    Say ("depot {0} manifest {1}: {2} files, {3:N1} GB ({4})" -f $d.Depot, $d.Gid, $files.Count, (($files | Measure-Object Size -Sum).Sum / 1GB), $mf)
    foreach ($f in $files) { $entries.Add($f) }
  }
  if (-not $entries.Count) { throw 'no manifest could be read' }

  $sw = [Diagnostics.Stopwatch]::StartNew()
  $ok = 0; $missing = 0; $sizeBad = 0; $shaBad = 0; $readErr = 0; $hashed = 0; [long]$bytes = 0
  $bad = New-Object System.Collections.Generic.List[string]
  # one file can be in two depots (Apex: EAAntiCheat.* in the game depot of 11 Nov AND in the Javelin depot of 19 Nov):
  # the disk holds one of them, so a file is OK when it matches any depot's version
  $byName = [ordered]@{}
  foreach ($e in $entries) { $k = $e.Name.ToLowerInvariant(); if (-not $byName.Contains($k)) { $byName[$k] = New-Object System.Collections.Generic.List[object] }; $byName[$k].Add($e) }
  $n = 0
  foreach ($vers in $byName.Values) {
    $n++
    $e = $vers[0]
    $p = Join-Path $dir $e.Name
    if (-not [IO.File]::Exists($p)) { $missing++; $bad.Add("MISSING  $($e.Name)  (want $($e.Size) bytes)"); continue }
    $len = (New-Object IO.FileInfo $p).Length
    $same = @($vers | Where-Object { $_.Size -eq $len })
    if (-not $same) { $sizeBad++; $bad.Add("SIZE     $($e.Name)  this PC $len, Steam $(($vers | ForEach-Object Size) -join ' or ')"); continue }
    if ($Quick -and $e.Name.Contains('\')) { $ok++; continue }
    try { $h = [OsyncSv]::Sha1($p) } catch { $readErr++; $bad.Add("READ     $($e.Name)  $($_.Exception.Message)"); continue }
    $hashed++; $bytes += $len
    if (-not ($same | Where-Object { $_.Sha -eq $h })) { $shaBad++; $bad.Add("SHA1     $($e.Name)  this PC $h, Steam $(($same | ForEach-Object Sha) -join ' or ')  ($len bytes, changed $((Get-Item -LiteralPath $p).LastWriteTime.ToString('yyyy-MM-dd HH:mm')))") } else { $ok++ }
    if ($n % 500 -eq 0) { Write-Output ("~ {0}/{1} files, {2:N1} GB read" -f $n, $byName.Count, ($bytes / 1GB)) }
  }
  $sec = [math]::Max(1, [int]$sw.Elapsed.TotalSeconds)
  # files in the game folder that Steam does not know (leftovers of other launchers / installers)
  $known = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($e in $entries) { [void]$known.Add($e.Name) }
  $extra = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($dir.Length).TrimStart('\') } | Where-Object { -not $known.Contains($_) })
  Say ("checked {0} files in {1}: OK {2} | missing {3} | size differs {4} | SHA1 differs {5} | read errors {6} | hashed {7:N1} GB, {8:N0} MB/s{9}" -f `
    $byName.Count, (Format-Sec $sec), $ok, $missing, $sizeBad, $shaBad, $readErr, ($bytes / 1GB), ($bytes / 1MB / $sec), $(if ($Quick) { ' (QUICK: sizes + top-level SHA1 only)' } else { '' }))
  Say ("files Steam does not list: {0}" -f $extra.Count)
  $extra | Select-Object -First 40 | ForEach-Object { Say "  extra  $_" }
  $bad | Select-Object -First $MaxList | ForEach-Object { Say "  $_" }
  if ($bad.Count -gt $MaxList) { Say "  ... $($bad.Count - $MaxList) more" }
  Say $(if ($bad.Count) { "RESULT: FILES DIFFER ($($bad.Count)) - this PC does not read the files Steam shipped" } else { 'RESULT: FILES OK - every file matches Steam (size + SHA1)' })
} catch {
  Say "RESULT: ERROR $($_.Exception.Message)"
}

if ($Report) {
  $ip = Get-Setting 'MasterIP' ''
  $port = Get-Setting 'ClientReportPort' '4670'
  if ($ip) {
    try { Invoke-WebRequest -Uri "http://${ip}:${port}/oslink-report" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes(($out -join "`r`n"))) -ContentType 'text/plain; charset=utf-8' -UseBasicParsing -TimeoutSec 20 | Out-Null; Write-Output "sent to $ip" }
    catch { Write-Output "could not send to ${ip}: $($_.Exception.Message)" }
  } else { Write-Output 'no MasterIP in settings.txt - not sent' }
}
