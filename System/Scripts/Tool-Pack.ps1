# Tool-Pack.ps1 - make OSYNC-Setup.exe: ONE file that installs OSYNC on any shop's master PC, or updates an OSYNC
# that is already there (OSYNC.bat > 7 Tools > 19). A small launcher compiled with Windows' own C# compiler (.NET 4)
# with payload.zip appended: it unpacks to %TEMP%, runs Setup-Install.ps1 in the same window, then cleans up.
# Nothing to download.
# In the file: OSYNC.bat, README.md, System\Scripts + Client + Docs, Settings (this shop's values blanked: the setup
# writes the new shop's), the built game menu (Menu\app, one exe) + Menu\tools + a neutral Menu\config.json.
# + Tools\ (20 Nov 2026: a branch gets the SAME tool programs as this shop - Sunshine0J, WO Mic, VB-CABLE, Parsec, VDD,
#   WinRAR, WebView2, Node.js, Python, Medal, aria2, DepotDownloader, FiveM-ReShade ...) with Tools\TOOLS-MANIFEST.txt
#   (SHA256 + size of every file) so the setup and Tool-Check can prove they are the same. The file is then ~1.2 GB and
#   holds other makers' programs and the Sunshine web login: give it to your own branches only, never publish it.
# Not in it: games, launchers, client data (System\Data), backups, Menu\source, this shop's game list / logo, logs.
#   Tool-Pack.ps1                 -> System\Dist\OSYNC-Setup-<date>.exe
#   -Out <folder>   -NoExe        (-NoExe: stop after payload.zip + Setup files, e.g. to test the setup by hand)
#   -NoTools                      leave Tools\ out (small file, e.g. for another shop that brings its own programs)
param([string]$Out = '', [switch]$NoExe, [switch]$NoTools)
. (Join-Path $PSScriptRoot 'Common.ps1')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
if (-not $Out) { $Out = Join-Path $SystemDir 'Dist' }
# the long form of TEMP: a short 8.3 TEMP (C:\Users\LONGNA~1, user names over 8 letters) made every entry name in payload.zip
# start with 'd/' (the files are listed with the long form), so OSYNC-Setup.exe could not find Setup-Install.ps1
$stage = Join-Path (Get-Item -LiteralPath $env:TEMP).FullName "osync-pack-$stamp"
$pl = Join-Path $stage 'payload'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $pl, $Out | Out-Null
function Copy-Dir([string]$from, [string]$to, [string[]]$xf = @()) {
  $a = @($from, $to, '/E', '/R:1', '/W:1', '/NP', '/NFL', '/NDL', '/NJH', '/NJS'); if ($xf) { $a += '/XF'; $a += $xf }
  & robocopy.exe @a | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE): $from" }
}
Write-Host "OSYNC pack from $Root" -ForegroundColor Cyan

# 1 the system
Copy-Item -LiteralPath (Join-Path $Root 'OSYNC.bat'), (Join-Path $Root 'README.md') -Destination $pl
foreach ($d in 'Scripts', 'Client', 'Docs') { Copy-Dir (Join-Path $SystemDir $d) (Join-Path $pl "System\$d") }
[IO.File]::WriteAllText((Join-Path $pl 'System\VERSION.txt'), "OSYNC $stamp (packed on $env:COMPUTERNAME)", (New-Object Text.UTF8Encoding $false))
Write-Host '  system: OSYNC.bat, README.md, System\Scripts, Client, Docs'

# 2 Settings for a NEW shop: this shop's values blanked (the setup fills SharedDrives / MasterIP / MasterPC), games list empty
New-Item -ItemType Directory -Force -Path (Join-Path $pl 'Settings') | Out-Null
$set = [IO.File]::ReadAllText($SettingsFile, [Text.Encoding]::UTF8)
# the values only THIS shop has (same list as Setup-Install.ps1 $ShopKeys): PC names, IPs, branch name, extra game folders
$set = [regex]::Replace($set, '(?m)^(\s*(SharedDrives|MasterIP|MasterPC|GameFolders|ClientBlockCpuz|ClientApexClean|ClientSteamVerify|ClientSteamVerifyApps|OnlineBranch|OnlineBranchName|OnlineBind|OnlineExternalIP)\s*=)[^\r\n]*', '$1')
$set = [regex]::Replace($set, '(?m)^(\s*Role\s*=)[^\r\n]*', '${1}auto')
[IO.File]::WriteAllText((Join-Path $pl 'Settings\settings.txt'), $set, (New-Object Text.UTF8Encoding $false))
$xg = [IO.File]::ReadAllText($ExtraGamesFile, [Text.Encoding]::UTF8)
$xg = [regex]::Replace($xg, '"games"\s*:\s*\[[\s\S]*?\r?\n  \]', '"games": []')
[void]($xg | ConvertFrom-Json)                                                       # still valid JSON
[IO.File]::WriteAllText((Join-Path $pl 'Settings\extra-games.json'), $xg, (New-Object Text.UTF8Encoding $false))
# the other files of Settings (already in git, nothing of this shop's PCs in them): game-start.json, gta5_settings*.xml
Get-ChildItem -LiteralPath $SettingsDir -File | Where-Object { $_.Name -notin 'settings.txt', 'extra-games.json' -and $_.Extension -in '.json', '.xml' } | Copy-Item -Destination (Join-Path $pl 'Settings')
Write-Host '  settings: blank for the new shop (+ game-start.json, gta5_settings*.xml)'

# 3 the game menu: the built program (one exe; the old 0JAYSHOP.exe copy is left out), its tools, a neutral config
$mi = Get-MenuInfo
if (-not (Test-Path -LiteralPath $mi.Exe)) { throw "menu program not found: $($mi.Exe) (build it first: OSYNC.bat > 7 > 3)" }
$appDir = Split-Path -Parent $mi.Exe
$skip = @(Get-ChildItem -LiteralPath $appDir -Filter *.exe -File | Where-Object { $_.Length -gt 50MB -and $_.FullName -ne $mi.Exe } | ForEach-Object Name)
Copy-Dir $appDir (Join-Path $pl 'Menu\app') $skip
Copy-Dir (Join-Path $Menu 'tools') (Join-Path $pl 'Menu\tools')
if (Test-Path -LiteralPath (Join-Path $Menu 'README-TH.txt')) { Copy-Item -LiteralPath (Join-Path $Menu 'README-TH.txt') -Destination (Join-Path $pl 'Menu') }
$cfg = [IO.File]::ReadAllText((Join-Path $Menu 'config.json'), [Text.Encoding]::UTF8)
foreach ($kv in @(@('brandName', 'GAME CENTER'), @('brandBadge', ''), @('brandLogo', ''), @('brandMark', ''), @('apiUrl', ''), @('machineId', ''), @('hudBanner', ''), @('hudBannerTag', ''), @('hudBannerText', ''))) {
  $cfg = [regex]::Replace($cfg, '("' + $kv[0] + '"\s*:\s*")[^"]*(")', '${1}' + $kv[1] + '${2}')
}
$cfg = [regex]::Replace($cfg, '("featured"\s*:\s*)\[[^\]]*\]', '${1}[]')
[void]($cfg | ConvertFrom-Json)
[IO.File]::WriteAllText((Join-Path $pl 'Menu\config.json'), $cfg, (New-Object Text.UTF8Encoding $false))
New-Item -ItemType Directory -Force -Path (Join-Path $pl 'Menu\data') | Out-Null
Write-Host "  menu: $(Split-Path -Leaf $mi.Exe) (renamed to the shop name at setup), tools, neutral config.json"

# 3b Tools\: every tool folder as it is on this master (no logs). Sunshine0J\config goes too (this shop's Sunshine settings
#    for a new branch - its PC profiles are redone there: OSYNC.bat > 7 > 24); it is the branch's own after that, so it is
#    not in the manifest and an update keeps the branch's copy.
if (-not $NoTools -and (Test-Path -LiteralPath $ToolsDir)) {
  $tl = Join-Path $pl 'Tools'
  Copy-Dir $ToolsDir $tl @('*.log', '*.log.*', 'TOOLS-MANIFEST.txt')
  Write-Host '  tools: hashing every file (SHA256) for TOOLS-MANIFEST.txt ...'
  $man = New-Object System.Collections.Generic.List[string]
  $man.Add("# OSYNC Tools $stamp from $env:COMPUTERNAME - sha256<TAB>size<TAB>path; Sunshine0J\config is the shop's own and not listed")
  $tn = 0; $tb = 0.0
  foreach ($f in @(Get-ChildItem -LiteralPath $tl -Recurse -File -Force | Sort-Object FullName)) {
    $rel = $f.FullName.Substring($tl.Length + 1)
    if ($rel -like 'Sunshine0J\config\*') { continue }
    $man.Add((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash + "`t" + $f.Length + "`t" + $rel); $tn++; $tb += $f.Length
  }
  [IO.File]::WriteAllLines((Join-Path $tl 'TOOLS-MANIFEST.txt'), [string[]]$man, (New-Object Text.UTF8Encoding $false))
  Write-Host ("  tools: {0} folders, {1} files, {2:N0} MB ({3})" -f @(Get-ChildItem -LiteralPath $tl -Directory).Count, $tn, ($tb / 1MB), ((Get-ChildItem -LiteralPath $tl -Directory | ForEach-Object Name) -join ', '))
} else { Write-Host '  tools: left out (-NoTools)' }

# 4 payload.zip + the setup files
$zip = Join-Path $stage 'payload.zip'
Write-Host '  compressing ...'
# entries written one by one with "/" (ZipFile.CreateFromDirectory of .NET Framework writes "\", which is not standard zip)
$za = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($f in Get-ChildItem -LiteralPath $pl -Recurse -Force) {
    $rel = $f.FullName.Substring($pl.Length + 1).Replace('\', '/')
    if ($f.PSIsContainer) { if (-not (Get-ChildItem -LiteralPath $f.FullName -Force | Select-Object -First 1)) { [void]$za.CreateEntry("$rel/") }; continue }
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $rel, [IO.Compression.CompressionLevel]::Optimal)
  }
} finally { $za.Dispose() }
Copy-Item -LiteralPath (Join-Path $ScriptsDir 'Setup-Install.ps1') -Destination $stage
[IO.File]::WriteAllText((Join-Path $stage 'Setup.cmd'), "@echo off`r`nset `"PSModulePath=`"`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0Setup-Install.ps1`" %*`r`n", (New-Object Text.ASCIIEncoding))
Write-Host ("  payload.zip {0:N0} MB" -f ((Get-Item -LiteralPath $zip).Length / 1MB))
if ($NoExe) { Write-Host "`nfiles: $stage (payload.zip, Setup.cmd, Setup-Install.ps1)" -ForegroundColor Green; exit 0 }

# 5 OSYNC-Setup.exe = a small launcher (C#, compiled here by Windows' own csc.exe) + payload.zip + 16-byte footer
#   footer: 8 bytes = where payload.zip starts, then "OSYNCPK1"
$exe = Join-Path $Out "OSYNC-Setup-$stamp.exe"
$csc = @("$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe", "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) { throw 'csc.exe (.NET Framework 4) not found' }
$cs = Join-Path $stage 'OsyncSetup.cs'
@"
using System; using System.Diagnostics; using System.IO; using System.IO.Compression; using System.Text;
[assembly: System.Reflection.AssemblyTitle("OSYNC Setup")]
[assembly: System.Reflection.AssemblyProduct("OSYNC")]
[assembly: System.Reflection.AssemblyFileVersion("1.0.0.0")]
class OsyncSetup {
  static int Main(string[] args) {
    string self = Process.GetCurrentProcess().MainModule.FileName;
    string dir = Path.Combine(Path.GetTempPath(), "osync-setup-" + Guid.NewGuid().ToString("N").Substring(0, 8));
    int rc = 1;
    try {
      Directory.CreateDirectory(dir);
      string zip = Path.Combine(dir, "payload.zip");
      using (FileStream fs = new FileStream(self, FileMode.Open, FileAccess.Read, FileShare.Read)) {
        byte[] f = new byte[16]; fs.Seek(-16, SeekOrigin.End); fs.Read(f, 0, 16);
        if (Encoding.ASCII.GetString(f, 8, 8) != "OSYNCPK1") { Console.WriteLine("This file has no OSYNC inside."); return 2; }
        long off = BitConverter.ToInt64(f, 0), left = fs.Length - 16 - off;
        Console.WriteLine("OSYNC setup: unpacking ...");
        fs.Seek(off, SeekOrigin.Begin);
        using (FileStream o = File.Create(zip)) { byte[] buf = new byte[1 << 20]; while (left > 0) { int n = fs.Read(buf, 0, (int)Math.Min(buf.Length, left)); if (n <= 0) break; o.Write(buf, 0, n); left -= n; } }
      }
      string ps1 = Path.Combine(dir, "Setup-Install.ps1");
      using (ZipArchive za = ZipFile.OpenRead(zip)) { za.GetEntry("System/Scripts/Setup-Install.ps1").ExtractToFile(ps1, true); }
      StringBuilder a = new StringBuilder("-NoProfile -ExecutionPolicy Bypass -File \"" + ps1 + "\" -Payload \"" + zip + "\"");
      foreach (string s in args) a.Append(" \"" + s.Replace("\"", "") + "\"");
      ProcessStartInfo psi = new ProcessStartInfo("powershell.exe", a.ToString());
      psi.UseShellExecute = false;
      psi.EnvironmentVariables.Remove("PSModulePath");
      Process p = Process.Start(psi); p.WaitForExit(); rc = p.ExitCode;
    } catch (Exception ex) { Console.WriteLine("OSYNC setup failed: " + ex.Message); Console.WriteLine("Press Enter to close"); Console.ReadLine(); }
    finally { try { Directory.Delete(dir, true); } catch { } }
    return rc;
  }
}
"@ | Set-Content -LiteralPath $cs -Encoding ASCII
$stub = Join-Path $stage 'OsyncSetup.exe'
Write-Host '  building OSYNC-Setup.exe ...'
$o = & $csc /nologo /target:exe /optimize+ "/out:$stub" /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll $cs 2>&1
if (-not (Test-Path -LiteralPath $stub)) { throw "csc failed: $o" }
$fs = [IO.File]::Create($exe)
try {
  $sb = [IO.File]::ReadAllBytes($stub); $fs.Write($sb, 0, $sb.Length)
  $off = [long]$fs.Position
  $in = [IO.File]::OpenRead($zip); try { $in.CopyTo($fs) } finally { $in.Dispose() }
  [byte[]]$f = [BitConverter]::GetBytes($off) + [Text.Encoding]::ASCII.GetBytes('OSYNCPK1'); $fs.Write($f, 0, $f.Length)
} finally { $fs.Dispose() }
Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("`nOSYNC-Setup: {0}  ({1:N0} MB)" -f $exe, ((Get-Item -LiteralPath $exe).Length / 1MB)) -ForegroundColor Green
# the guides for the person / AI at the branch, next to the exe (SETUP-AI.md: what an AI does first, before anything is installed)
foreach ($g in 'SETUP-AI.md', '00-EASY-INSTALL.md') { Copy-Item -LiteralPath (Join-Path $DocsDir $g) -Destination (Join-Path $Out $g) -Force }
Write-Host 'Copy this one file to a master PC and run it: it installs OSYNC there, or updates the OSYNC that is already there.'
Write-Host "With an AI: copy SETUP-AI.md and 00-EASY-INSTALL.md from $Out too (the AI reads them first; OSYNC-Setup.exe -PlanOnly = check only)."