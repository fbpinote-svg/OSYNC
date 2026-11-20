# Client-Mic.ps1 - CLIENT PC: WO Mic Client (phone microphone, driven by the shop agent) and VB-CABLE (virtual audio cable).
# Each one is installed silently ONLY when this PC does not have it yet (an image saved with them = nothing to do, seconds).
#   WO Mic  : Tools\WOMic\WOMicClientSetup*.exe /S  = program + desktop icon + driver (driver signed by Microsoft), no autostart,
#             no reboot. Goes to Program Files (x86)\WOMic; the agent finds it through its Windows "Installed apps" entry.
#   VB-CABLE: Tools\VBCABLE\ = the whole unzipped VB-CABLE pack (the setup needs the .inf/.sys/.cat next to it); setup -i -h.
#             Its driver is signed by its author, not by Microsoft: his certificate goes into this PC's Trusted Publishers
#             first - the same as ticking "Always trust software from Vincent Burel" when installing by hand. Without it
#             Windows asks, and a silent install as SYSTEM cannot answer.
#   A new audio device can become Windows' default: if the default speaker / microphone turned into a CABLE device, the
#   one from before is put back (customers' headphones keep their sound).
# Called by Client-Install step 1f (at boot as SYSTEM, or in image mode by the admin). Never on the master.
# Setting: ClientMicDrivers=off skips it. Exit 0 = both there, 1 = something did not install (see the lines above it).
# 20 Nov 2026 (owner: "the sound / mic drivers cannot be installed on some Windows"): the clients boot one of two images -
# Windows 10 IoT LTSC 2021 (19045) or Windows 11 Pro (26300, KORI06/11/23/25 seen). On Windows 11 boots VB-CABLE's setup said
# exit 0 but made no device. Now a WO Mic / VB-CABLE device without a working driver no longer counts as installed, and when
# VB-CABLE's setup leaves no working device its driver is installed directly (devcon, VB-Audio's Microsoft-signed Windows 10+
# package in Tools\VBCABLE). Only these two (our menu system's mic / sound drivers) - nothing else on the PC is touched.
#   -CheckOnly: only shows what it would do. On the master only with $env:OSYNC_MIC_TEST=1 (tests).
# 20 Nov 2026 (KORI06, Windows 11): at this point of the boot Windows 11 shows NO speaker / mic of the PC yet, so the new
# CABLE device became the default speaker (customers would hear nothing once their headphones appear). When the default speaker
# or mic is a CABLE device (or none) at the end, a copy of this script stays in the background (-WatchDefaults, 20 min) and,
# as soon as a real speaker / mic of the PC shows up, puts the default back on it. Only away from OUR CABLE device - another
# program's device is never chosen, a default the customer picked that is not CABLE is never changed.
#   -WatchDefaults [-WatchMinutes 20]: that background part only. Log C:\Users\Public\OSYNC-AudioDefaults.log
param([switch]$CheckOnly, [switch]$WatchDefaults, [int]$WatchMinutes = 20)
. (Join-Path $PSScriptRoot 'Common.ps1')
# x64 program? (PE machine 0x8664)
function Test-X64Exe([string]$p) { try { $b = [IO.File]::ReadAllBytes($p); $pe = [BitConverter]::ToInt32($b, 0x3C); [BitConverter]::ToUInt16($b, $pe + 4) -eq 0x8664 } catch { $false } }
if ((Test-IsMaster) -and -not ($CheckOnly -and $env:OSYNC_MIC_TEST)) { Write-Host 'this is the master - nothing installed here'; exit 0 }
$osBuild = [int]"0$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).CurrentBuildNumber)"
$WoMicDir = Join-Path $ToolsDir 'WOMic'
$VbDir = Join-Path $ToolsDir 'VBCABLE'
$failed = $false

function Get-MediaDevice([string]$Pattern) {
  # any class: Windows can list the VB-CABLE device with an EMPTY class and name (only HardwareID VBAudioVACWDM - seen on the
  # master 2026-11-17), so -Class MEDIA missed it; speakers / mics (AudioEndpoint, "CABLE Input (VB-Audio ...)") count too
  @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { "$($_.FriendlyName)" -match $Pattern -or (@($_.HardwareID) -match $Pattern) })
}
# 20 Nov 2026: only a device that WORKS counts - Windows can keep a root device with no driver (empty class and name, only the
# HardwareID; the master has one for VB-CABLE since May), which looked "already on this PC" and was never repaired
function Get-WorkingDevice([string]$Pattern) {
  @(Get-MediaDevice $Pattern | Where-Object { "$($_.Status)" -eq 'OK' -and @('MEDIA', 'AudioEndpoint') -contains "$($_.Class)" })
}
function Find-WoMicClient {
  $c = @()
  foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Wolicheng\WOMic', 'HKLM:\SOFTWARE\Wolicheng\WOMic') {
    $d = (Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue).Install_Dir
    if ($d) { $c += (Join-Path $d 'WOMicClient.exe') }
  }
  $keys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  foreach ($a in @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { "$($_.DisplayName)" -like 'WO Mic*' })) {
    if ($a.DisplayIcon) { $c += ("$($a.DisplayIcon)" -replace '^"([^"]+)".*$', '$1' -replace ',\d+$', '').Trim() }
  }
  foreach ($pf in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) { if ($pf) { $c += (Join-Path $pf 'WOMic\WOMicClient.exe'); $c += (Join-Path $pf 'WO Mic\WOMicClient.exe') } }
  $c | Where-Object { $_ -and $_ -match '\.exe$' -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
# runs a setup hidden; stops it (and what it started) when it is still busy after $Seconds - a setup waiting on a window
# nobody can see (SYSTEM at boot) must not hold up the rest of the boot setup
function Invoke-Setup([string]$Exe, [string]$Arguments, [int]$Seconds = 180) {
  $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory (Split-Path -Parent $Exe) -WindowStyle Hidden -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit($Seconds * 1000)) {
    & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /T /F /PID $p.Id 2>$null | Out-Null
    return "still running after $Seconds s - stopped"
  }
  "exit $($p.ExitCode)"
}

# ---------- default speaker / microphone (Windows Core Audio; IPolicyConfig = what the Sound panel uses) ----------
$audioOk = $false
try {
  if (-not ('OsyncAudio.Defaults' -as [type])) {
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace OsyncAudio {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }
  [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class PolicyConfigClient { }
  [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
  }
  [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, out IntPtr iface);
    [PreserveSig] int OpenPropertyStore(int access, out IntPtr store);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
  }
  [Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPolicyConfig {
    [PreserveSig] int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr format);
    [PreserveSig] int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id, int isDefault, IntPtr format);
    [PreserveSig] int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id);
    [PreserveSig] int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr endpointFormat, IntPtr mixFormat);
    [PreserveSig] int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string id, int isDefault, IntPtr defaultPeriod, IntPtr minPeriod);
    [PreserveSig] int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr period);
    [PreserveSig] int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr mode);
    [PreserveSig] int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr mode);
    [PreserveSig] int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr key, IntPtr value);
    [PreserveSig] int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr key, IntPtr value);
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
    [PreserveSig] int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string id, int visible);
  }
  public static class Defaults {
    // flow 0 = speakers (render), 1 = microphones (capture); role 0 console, 1 multimedia, 2 communications
    public static string Get(int flow, int role) {
      IMMDeviceEnumerator e = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
      IMMDevice d;
      if (e.GetDefaultAudioEndpoint(flow, role, out d) != 0 || d == null) return "";
      string id;
      if (d.GetId(out id) != 0) return "";
      return id ?? "";
    }
    public static int Set(string id) {
      IPolicyConfig p = (IPolicyConfig)(new PolicyConfigClient());
      int hr = 0;
      for (int r = 0; r < 3; r++) { int h = p.SetDefaultEndpoint(id, r); if (h != 0) hr = h; }
      return hr;
    }
    // "Enable" in the Sound panel (a disabled speaker / mic) = endpoint visibility 1
    public static int Enable(string id) {
      IPolicyConfig p = (IPolicyConfig)(new PolicyConfigClient());
      return p.SetEndpointVisibility(id, 1);
    }
  }
}
'@
  }
  $audioOk = $true
} catch { Write-Host "  (default speaker / mic check not available: $($_.Exception.Message))" }
function Get-EndpointName([string]$Id) {
  if (-not $Id) { return '(none)' }
  $d = Get-PnpDevice -InstanceId ('SWD\MMDEVAPI\' + $Id) -ErrorAction SilentlyContinue
  if ($d -and $d.FriendlyName) { "$($d.FriendlyName)" } else { $Id }
}
function Get-AudioDefaults {
  if (-not $audioOk) { return $null }
  $r = @{}
  foreach ($f in 0, 1) { foreach ($role in 0, 1, 2) { $r["$f/$role"] = [OsyncAudio.Defaults]::Get($f, $role) } }
  $r
}
function Show-AudioDefaults([string]$When) {
  if (-not $audioOk) { return }
  Write-Host ("  default speaker {0}: {1}  |  default mic: {2}" -f $When, (Get-EndpointName ([OsyncAudio.Defaults]::Get(0, 0))), (Get-EndpointName ([OsyncAudio.Defaults]::Get(1, 0))))
}
$oursCable = '(?i)CABLE|VB-Audio'                                                                    # our VB-CABLE endpoints
$notReal   = '(?i)CABLE|VB-Audio|WO Mic|Parsec|Steam Streaming|Virtual|Sunshine|Zako|Remote Audio|Voicemeeter|Broadcast'
# the PC's own active speaker (flow 0) / mic (flow 1): not ours, not another program's virtual device
function Get-RealEndpoint([int]$Flow) {
  $pre = 'SWD\MMDEVAPI\{0.0.' + $Flow + '.*'
  Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { "$($_.Status)" -eq 'OK' -and "$($_.InstanceId)" -like $pre -and "$($_.FriendlyName)" -notmatch $notReal } | Select-Object -First 1
}
if ($WatchDefaults) {
  if (-not $audioOk) { exit 0 }
  $wlog = Join-Path $env:PUBLIC 'OSYNC-AudioDefaults.log'
  function WLog([string]$s) { try { [IO.File]::AppendAllText($wlog, ('{0} {1}{2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $s, "`r`n")) } catch { } }
  WLog "watching the default speaker / mic for $WatchMinutes min (away from VB-CABLE once the PC's own device shows up)"
  $end = (Get-Date).AddMinutes($WatchMinutes)
  $done = @{ 0 = $false; 1 = $false }
  while ((Get-Date) -lt $end -and -not ($done[0] -and $done[1])) {
    foreach ($f in 0, 1) {
      if ($done[$f]) { continue }
      $what = if ($f) { 'mic' } else { 'speaker' }
      $cur = [OsyncAudio.Defaults]::Get($f, 0)
      $curName = Get-EndpointName $cur
      if ($cur -and $curName -notmatch $oursCable) { $done[$f] = $true; WLog "default $what is $curName - left as it is"; continue }
      $real = Get-RealEndpoint $f
      if ($real -and $CheckOnly) { WLog "default $what is $curName - WOULD set it to the PC's $($real.FriendlyName) (check only)"; $done[$f] = $true }
      elseif ($real) {
        $hr = [OsyncAudio.Defaults]::Set($real.InstanceId.Substring(13))
        WLog ("default {0} was {1} - set to the PC's {2} (0x{3:X8})" -f $what, $curName, $real.FriendlyName, $hr)
        $done[$f] = $true
      }
    }
    if (-not ($done[0] -and $done[1])) { Start-Sleep -Seconds 15 }
  }
  WLog "done (speaker $(if ($done[0]) { 'ok' } else { 'no real one appeared' }), mic $(if ($done[1]) { 'ok' } else { 'no real one appeared' }))"
  exit 0
}
# devcon.exe for installing a driver straight from its .inf (WO Mic / VB-CABLE fallback)
# 18 Nov 2026: the devcon in WO Mic's own package is ARM64 only ("not a valid application for this OS platform" on every
# x64 client) - then OSLink's x64 devcon is used (game disk, signed by its maker, the same one Client-OslinkDrivers uses)
# 19 Nov 2026: "UnknownError" = its root (DigiCert Trusted Root G4) is not on this PC yet - accepted when the file is
# exactly OSLink 1.3.29.5's devcon.exe (SHA256 pinned, read on the master), as in Client-OslinkDrivers.ps1
function Get-Devcon {
  $own = Join-Path $WoMicDir 'driver\devcon.exe'
  if ((Test-Path -LiteralPath $own) -and (Test-X64Exe $own)) { return $own }
  $dcHash = 'A0E6271C610F096959D047D985DC69BC8819BBF26FB4CBD12CD776A24E625FA6'
  @(foreach ($d in (Get-SharedDrives).ToCharArray()) { "${d}:\LDPlayer\OSLink\bin\devcon.exe" }) | Where-Object { (Test-Path -LiteralPath $_) -and (Test-X64Exe $_) -and $(
    $sg = Get-AuthenticodeSignature -LiteralPath $_
    ($sg.Status -eq 'Valid' -and "$($sg.SignerCertificate.Subject)" -match 'Shanghai Chang Zhi') -or ((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -eq $dcHash)) } | Select-Object -First 1
}
# devcon exit codes: 0 done, 1 done but Windows wants a restart, 2 failed
function Format-DevconExit([string]$r) { switch ($r) { 'exit 0' { 'exit 0 (done)' } 'exit 1' { 'exit 1 (done, Windows wants a restart - the device can work already)' } 'exit 2' { 'exit 2 (FAILED)' } default { $r } } }

# Owner, 20 Nov 2026: only the sound / mic drivers of OUR menu system (WO Mic, VB-CABLE) are handled here - never the PC's
# own sound card, Windows' sound services or any other program's audio device. The line below only READS what Windows shows
# (for the report), it changes nothing.
function Show-Sound([string]$When) {
  $ep = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue)
  Write-Host ("  speakers / mics {0} (Windows build {1}): {2}" -f $When, $osBuild, $(if ($ep) { ($ep | ForEach-Object { "$($_.FriendlyName) [$($_.Status)]" }) -join ', ' } else { 'none' }))
}
Show-Sound 'before'

# ---------- WO Mic ----------
$wmExe = Find-WoMicClient
$wmDev = Get-WorkingDevice '(?i)WOMic|WO Mic'
if ($wmExe -and $wmDev.Count) {
  Write-Host "WO Mic: already on this PC ($wmExe; device: $($wmDev[0].FriendlyName))"
} else {
  $setup = Get-ChildItem -LiteralPath $WoMicDir -Filter 'WOMicClientSetup*.exe' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
  if (-not $setup) {
    Write-Host "WO Mic: missing on this PC, and no installer in $WoMicDir - skipped"
  } elseif ($CheckOnly) {
    Write-Host "WO Mic: missing on this PC (program: $(if ($wmExe) { 'yes' } else { 'no' }), device: $(if ($wmDev.Count) { 'yes' } else { 'no' })) - would install $($setup.Name)"
  } else {
    Write-Host "WO Mic: missing (program: $(if ($wmExe) { 'yes' } else { 'no' }), device: $(if ($wmDev.Count) { 'yes' } else { 'no' })) - installing $($setup.Name) silently"
    Show-AudioDefaults 'before'
    # WO Mic 6.x's driver is signed by its maker (Beijing Wolicheng), not by Microsoft: trust that publisher first - the same
    # as ticking "Always trust" by hand - or the silent driver install waits on a question nobody sees (2026-11-17, KORI12)
    $wmDrv = Join-Path $WoMicDir 'driver'
    $wmCat = Join-Path $wmDrv 'womic.cat'
    $wmThumb = 'DBFE96736ED5A71652ED4F6A2554B9135DA246DE'
    if (Test-Path -LiteralPath $wmCat) {
      $sg = Get-AuthenticodeSignature -LiteralPath $wmCat
      if ($sg.Status -eq 'Valid' -and $sg.SignerCertificate.Thumbprint -eq $wmThumb) {
        $st = New-Object Security.Cryptography.X509Certificates.X509Store('TrustedPublisher', 'LocalMachine')
        $st.Open('ReadWrite')
        if (@($st.Certificates | Where-Object { $_.Thumbprint -eq $wmThumb }).Count) { Write-Host "  publisher already trusted ($wmThumb)" }
        else { $st.Add($sg.SignerCertificate); Write-Host "  publisher 'Beijing Wolicheng' added to Trusted Publishers ($wmThumb)" }
        $st.Close()
      } else { Write-Host "  $wmCat is not validly signed by Wolicheng (signature $($sg.Status)) - publisher not trusted" }
    }
    $r = Invoke-Setup $setup.FullName '/S'
    $wmExe = Find-WoMicClient
    $wmDev = Get-WorkingDevice '(?i)WOMic|WO Mic'
    $dc = Get-Devcon
    if ($dc -and $dc -ne (Join-Path $wmDrv 'devcon.exe')) { Write-Host "  WO Mic's own devcon is not x64 - using $dc" }
    $wmInf = Join-Path $wmDrv 'womic.inf'
    if (-not $wmDev.Count -and $dc -and (Test-Path -LiteralPath $dc) -and (Test-Path -LiteralPath $wmInf)) {
      Write-Host '  device still missing - installing the driver directly: devcon install womic.inf *WOMic'
      # 19 Nov 2026: built outside the "..." - the nested quotes inside $( ) split it, and 'Seconds' got the .inf path (FAIL on 8 PCs)
      $dcArgs = 'install "' + $wmInf + '" *WOMic'
      $dcRes = Invoke-Setup $dc $dcArgs 90
      Write-Host "  devcon: $(Format-DevconExit $dcRes)"
      Start-Sleep -Seconds 3
      $wmDev = Get-WorkingDevice '(?i)WOMic|WO Mic'
    }
    if ($wmExe -and $wmDev.Count) { Write-Host "WO Mic: installed ($r) -> $wmExe; device: $($wmDev[0].FriendlyName)" }
    else { Write-Host "WO Mic: NOT installed ($r; program: $(if ($wmExe) { $wmExe } else { 'missing' }), device: $(if ($wmDev.Count) { 'yes' } else { 'missing' }))"; $failed = $true }
    Show-AudioDefaults 'after'
  }
}

# ---------- VB-CABLE ----------
$vbPattern = '(?i)VBAudioVACWDM|VB-Audio Virtual Cable'
$vbDev = Get-WorkingDevice $vbPattern
# VB-Audio's Windows 10+ driver package (signed by Microsoft) for the direct install; older Windows: the Windows 7 one
$vbInf = Join-Path $VbDir $(if ($osBuild -ge 16299) { 'vbMmeCable64_win10.inf' } else { 'vbMmeCable64_win7.inf' })
# root device(s) with VB-CABLE's HardwareID but no working driver (the setup / an old install left them)
function Get-VbBroken { @(Get-MediaDevice '(?i)VBAudioVACWDM' | Where-Object { "$($_.InstanceId)" -like 'ROOT\*' -and -not ("$($_.Status)" -eq 'OK' -and "$($_.Class)" -eq 'MEDIA') }) }
# Windows may switch the default to the new CABLE device a moment after it appears: watch ~20 s, put the old one back
function Restore-AudioDefaults($before) {
  for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 2
    if (-not $before) { return }
    foreach ($f in 0, 1) {
      $old = $before["$f/0"]
      if (-not $old -or (Get-EndpointName $old) -match '(?i)CABLE') { continue }
      $now = @(0, 1, 2 | ForEach-Object { [OsyncAudio.Defaults]::Get($f, $_) })
      if (@($now | Where-Object { $_ -and $_ -ne $old -and (Get-EndpointName $_) -match '(?i)CABLE' }).Count) {
        $hr = [OsyncAudio.Defaults]::Set($old)
        Write-Host ("  default {0} had become a CABLE device - put back to {1} (0x{2:X8})" -f $(if ($f) { 'mic' } else { 'speaker' }), (Get-EndpointName $old), $hr)
      }
    }
  }
}
if ($vbDev.Count) {
  Write-Host "VB-CABLE: already on this PC ($($vbDev[0].FriendlyName))"
} else {
  $vbBroken = Get-VbBroken
  if ($vbBroken) { Write-Host "VB-CABLE: device without a working driver: $(($vbBroken | ForEach-Object { "$($_.InstanceId) [$($_.Status), class '$($_.Class)']" }) -join ', ')" }
  $setup = Join-Path $VbDir $(if ([Environment]::Is64BitOperatingSystem) { 'VBCABLE_Setup_x64.exe' } else { 'VBCABLE_Setup.exe' })
  $cat = Join-Path $VbDir $(if ([Environment]::Is64BitOperatingSystem) { 'vbaudio_cable64_win7.cat' } else { 'vbaudio_cable_win7.cat' })
  if (-not (Test-Path -LiteralPath $setup) -or -not (Test-Path -LiteralPath $cat)) {
    Write-Host "VB-CABLE: missing on this PC, and no complete VB-CABLE pack in $VbDir - skipped"
  } elseif ($CheckOnly) {
    Write-Host "VB-CABLE: missing on this PC - would install $(Split-Path -Leaf $setup); if that makes no working device: devcon $(if (Get-VbBroken) { 'update' } else { 'install' }) $(Split-Path -Leaf $vbInf) VBAudioVACWDM (devcon: $(if (Get-Devcon) { Get-Devcon } else { 'NONE FOUND' }); Windows build $osBuild)"
  } else {
    # only the author's own signed files: the setup and the driver catalog must both be validly signed by him
    $sigCat = Get-AuthenticodeSignature -LiteralPath $cat
    $sigExe = Get-AuthenticodeSignature -LiteralPath $setup
    # VB-Audio signs as "Vincent Burel" (driver catalogs) and, since pack 45, "BUREL VINCENT Entrepreneur individuel" (setup)
    $okSig = { param($s) $s.Status -eq 'Valid' -and $s.SignerCertificate -and $s.SignerCertificate.Subject -match '(^|, )CN="?(Vincent Burel|BUREL VINCENT Entrepreneur individuel)"?(,|$)' }
    if (-not (& $okSig $sigCat) -or -not (& $okSig $sigExe)) {
      Write-Host "VB-CABLE: NOT installed - the files in $VbDir are not validly signed by VB-Audio (Vincent Burel): catalog $($sigCat.Status) $($sigCat.SignerCertificate.Subject -replace ',.*$', ''), setup $($sigExe.Status) $($sigExe.SignerCertificate.Subject -replace ',.*$', '')"
      $failed = $true
    } else {
      Write-Host "VB-CABLE: missing - installing $(Split-Path -Leaf $setup) silently"
      $cert = $sigCat.SignerCertificate
      $st = New-Object Security.Cryptography.X509Certificates.X509Store('TrustedPublisher', 'LocalMachine')
      $st.Open('ReadWrite')
      if (@($st.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }).Count) { Write-Host "  publisher already trusted ($($cert.Thumbprint))" }
      else { $st.Add($cert); Write-Host "  publisher 'Vincent Burel' added to Trusted Publishers ($($cert.Thumbprint))" }
      $st.Close()
      $before = Get-AudioDefaults
      Show-AudioDefaults 'before'
      $r = Invoke-Setup $setup '-i -h'
      Restore-AudioDefaults $before
      $vbDev = Get-WorkingDevice $vbPattern
      # 20 Nov 2026: on the Windows 11 image the setup says exit 0 and makes nothing - then the driver goes in directly, the way
      # Windows' own device installer does it (devcon = SetupAPI): a new root device "VBAudioVACWDM", or the driverless one updated
      if (-not $vbDev.Count) {
        $dc = Get-Devcon
        if ($dc -and (Test-Path -LiteralPath $vbInf)) {
          $verb = if (Get-VbBroken) { 'update' } else { 'install' }
          Write-Host "  the setup ($r) made no working VB-CABLE - installing the driver directly: devcon $verb $(Split-Path -Leaf $vbInf) VBAudioVACWDM"
          $dcRes = Invoke-Setup $dc ($verb + ' "' + $vbInf + '" VBAudioVACWDM') 90
          Write-Host "  devcon: $(Format-DevconExit $dcRes)"
          Restore-AudioDefaults $before
          $vbDev = Get-WorkingDevice $vbPattern
          $r = "setup $r, devcon $verb $dcRes"
        } else { Write-Host "  the setup ($r) made no working VB-CABLE, and no devcon / $(Split-Path -Leaf $vbInf) for a direct install" }
      }
      if ($vbDev.Count) { Write-Host "VB-CABLE: installed ($r) -> $($vbDev[0].FriendlyName)" }
      else {
        $left = Get-VbBroken
        Write-Host "VB-CABLE: NOT installed ($r)$(if ($left) { ' - device without driver: ' + (($left | ForEach-Object { "$($_.InstanceId) $($_.Status)" }) -join ', ') })"
        $failed = $true
      }
      Show-AudioDefaults 'after'
    }
  }
}
# ---------- VB-CABLE's speaker / mic switched off in the Sound panel ----------
# 20 Nov 2026 (owner: "Sunshine does not find VB-CABLE"): Sunshine 0JAYSHOP's mic for remote players (0JayMic, mic_backend auto /
# vb_cable) writes the customer's voice into an ACTIVE speaker whose adapter is "VB-Audio Virtual Cable", and the game hears it
# on "CABLE Output". A VB-CABLE speaker / mic that was disabled (in the image; several PCs show one renamed "NOT USE") is not
# seen at all - so they are enabled here again, names kept. Only VB-CABLE's own endpoints; nothing else is touched.
# MMDevices registry: DeviceState 1 active, 2 disabled, 4 not present, 8 unplugged
function Get-VbEndpoints {
  foreach ($flow in 'Render', 'Capture') {
    foreach ($k in @(Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\$flow" -ErrorAction SilentlyContinue)) {
      $p = Get-ItemProperty -LiteralPath (Join-Path $k.PSPath 'Properties') -ErrorAction SilentlyContinue
      $adapter = "$($p.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6')"
      if ($adapter -notmatch '(?i)VB-Audio') { continue }
      $st = [int64]"0$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).DeviceState)" -band 0xF
      [pscustomobject]@{ Flow = $flow; Name = "$($p.'{a45c254e-df1c-4efd-8020-67d146a850e0},2')"; Adapter = $adapter; State = $st
        Id = '{0.0.' + $(if ($flow -eq 'Render') { '0' } else { '1' }) + '.00000000}.' + $k.PSChildName.ToLowerInvariant() }
    }
  }
}
function Format-EpState([int]$s) { switch ($s) { 1 { 'active' } 2 { 'DISABLED' } 4 { 'not present' } 8 { 'unplugged' } default { "state $s" } } }
$vbEps = @(Get-VbEndpoints | Where-Object { $_.State -ne 4 })
if ($vbEps) {
  Write-Host "  VB-CABLE speakers / mics: $(($vbEps | ForEach-Object { "$($_.Flow) '$($_.Name)' $(Format-EpState $_.State)" }) -join ', ')"
  foreach ($e in @($vbEps | Where-Object { $_.State -eq 2 })) {
    if ($CheckOnly -or -not $audioOk) { Write-Host "  would enable VB-CABLE $($e.Flow) '$($e.Name)' (Sunshine's mic needs it)"; continue }
    $hr = try { [OsyncAudio.Defaults]::Enable($e.Id) } catch { -1 }
    Start-Sleep -Milliseconds 500
    $now = @(Get-VbEndpoints | Where-Object { $_.Id -eq $e.Id } | Select-Object -First 1)
    Write-Host ("  enabled VB-CABLE {0} '{1}' (Sunshine's mic needs it): 0x{2:X8} -> {3}" -f $e.Flow, $e.Name, $hr, $(if ($now) { Format-EpState $now[0].State } else { '?' }))
  }
  if (-not @($vbEps | Where-Object { $_.Flow -eq 'Render' -and $_.State -ne 4 }).Count) { Write-Host '  VB-CABLE has no speaker side on this PC - Sunshine cannot pass the remote player''s mic' }
}
# default speaker / mic is our CABLE device (or there is none yet - Windows 11 at this point of the boot): watch in the
# background and give it back to the PC's own device when that shows up
if (-not $CheckOnly -and $audioOk) {
  $dSpk = Get-EndpointName ([OsyncAudio.Defaults]::Get(0, 0)); $dMic = Get-EndpointName ([OsyncAudio.Defaults]::Get(1, 0))
  if ($dSpk -match "$oursCable|^\(none\)$" -or $dMic -match "$oursCable|^\(none\)$") {
    Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-WatchDefaults', '-WatchMinutes', '20')
    Write-Host "  default speaker $dSpk / mic $dMic - watching 20 min in the background: back to the PC's own device when it shows up (C:\Users\Public\OSYNC-AudioDefaults.log)"
  }
}
if ($failed) { exit 1 }
exit 0
