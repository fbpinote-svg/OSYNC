# Client-Runtimes.ps1 - CLIENT PC: the runtimes other programs need (18 Nov 2026, the owner: "so the programs are complete").
#   WebView2  Microsoft Edge WebView2 Runtime: installed silently ONLY when this PC does not have it (Tools\WebView2 =
#             Microsoft's offline installer, per machine). Programs with a web-page window need it - e.g. the Sunshine
#             0JAYSHOP panel asked for it. An image saved with it = a check of a second.
#   Node.js   Tools\NodeJS (the official portable build, nothing installed): its folder goes on the machine PATH, so
#             node / npm / npx work in every console and program.
#   Python    Tools\Python (the official installer, installed on the master into the game disk): python.exe and its
#             Scripts folder go on the machine PATH, Python is registered for Windows (PEP 514: HKLM\SOFTWARE\Python\
#             PythonCore\<x.y>, so programs that look for an installed Python find it) and .py / .pyw files open with it
#             when nothing else opens them yet.
#   PATH entries are added at the end (nothing that is already there changes); nothing is copied to C:.
# Called by Client-Install step 1o (at boot as SYSTEM, or in image mode by the admin). Never changes the master.
# Settings: ClientWebView2 / ClientNodeJs / ClientPython = off skips that part.
# -CheckOnly: report only (also on the master).  -TestKey <subkey>: PATH / registry go to HKCU\<subkey> instead of the
# machine (tests on the master); WebView2 is then only checked, not installed.
# Exit 0 = everything that is on is in place, 1 = something did not work (the line says what).
param([switch]$CheckOnly, [string]$TestKey = '')
. (Join-Path $PSScriptRoot 'Common.ps1')
if ((Test-IsMaster) -and -not $TestKey -and -not $CheckOnly) { Write-Host 'this is the master - nothing changed here'; exit 0 }
function Test-Off([string]$Name) { (Get-Setting $Name 'on') -match '^(?i)(off|no|0|false)$' }
$rc = 0
$changedPath = $false

# ---------- registry roots (machine, or HKCU\<TestKey> for tests) ----------
function Open-Key([string]$Sub, [bool]$Write = $true) {
  $root = if ($TestKey) { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }
  $path = if ($TestKey) { "$TestKey\$Sub" } else { $Sub }
  if ($Write) { return $root.CreateSubKey($path) }
  $root.OpenSubKey($path)   # read only (-CheckOnly works without admin)
}
function Add-MachinePath([string[]]$Dirs) {
  $k = Open-Key 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' (-not $CheckOnly)
  if (-not $k) { return , @($Dirs) }
  try {
    $cur = [string]$k.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($p in ($cur -split ';')) { if ($p.Trim()) { $parts.Add($p) } }
    $added = @()
    foreach ($d in $Dirs) {
      $have = $false; foreach ($p in $parts) { if ($p.Trim().TrimEnd('\') -ieq $d.TrimEnd('\')) { $have = $true } }
      if (-not $have) { $parts.Add($d); $added += $d }
    }
    if ($added.Count -and -not $CheckOnly) {
      $kind = if ($cur -and $k.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::String) { [Microsoft.Win32.RegistryValueKind]::String } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
      $k.SetValue('Path', ($parts -join ';'), $kind)
      $script:changedPath = $true
    }
    , $added
  } finally { $k.Close() }
}

# ---------- 1 WebView2 ----------
function Get-WebView2Version {
  foreach ($sub in 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
                   'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}') {
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub)
    if ($k) { $v = [string]$k.GetValue('pv', ''); $k.Close(); if ($v -and $v -ne '0.0.0.0') { return $v } }
  }
  ''
}
if (Test-Off 'ClientWebView2') { Write-Host 'WebView2: SKIP (ClientWebView2=off)' }
else {
  $v = Get-WebView2Version
  $setup = Join-Path $ToolsDir 'WebView2\MicrosoftEdgeWebView2RuntimeInstallerX64.exe'
  if ($v) { Write-Host "WebView2: already on this PC ($v)" }
  elseif (-not (Test-Path -LiteralPath $setup)) { Write-Host "WebView2: missing, and no installer at $setup"; $rc = 1 }
  elseif ($CheckOnly -or $TestKey) { Write-Host "WebView2: missing on this PC - would install $(Split-Path $setup -Leaf) /silent /install" }
  else {
    $sig = Get-AuthenticodeSignature -LiteralPath $setup
    if ($sig.Status -ne 'Valid' -or "$($sig.SignerCertificate.Subject)" -notmatch '(^|, )CN=Microsoft Corporation(,|$)') {
      Write-Host "WebView2: NOT installed - the installer is not validly signed by Microsoft ($($sig.Status): $($sig.SignerCertificate.Subject))"; $rc = 1
    } else {
      Write-Host 'WebView2: missing - installing silently (Microsoft offline installer, about a minute)'
      $p = Start-Process -FilePath $setup -ArgumentList '/silent /install' -WindowStyle Hidden -PassThru
      $null = $p.Handle
      if (-not $p.WaitForExit(300000)) { & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /T /F /PID $p.Id 2>$null | Out-Null; Write-Host 'WebView2: installer still busy after 5 min - stopped' }
      $v = Get-WebView2Version
      if ($v) { Write-Host "WebView2: installed ($v)" } else { Write-Host "WebView2: did NOT install (installer exit $($p.ExitCode))"; $rc = 1 }
    }
  }
}

# ---------- 2 Node.js ----------
if (Test-Off 'ClientNodeJs') { Write-Host 'Node.js: SKIP (ClientNodeJs=off)' }
else {
  $node = Join-Path $ToolsDir 'NodeJS'
  if (-not (Test-Path -LiteralPath (Join-Path $node 'node.exe'))) { Write-Host "Node.js: not found in $node - skipped"; $rc = 1 }
  else {
    $a = Add-MachinePath @($node)
    $ver = (Get-Item -LiteralPath (Join-Path $node 'node.exe')).VersionInfo.ProductVersion
    Write-Host "Node.js $ver : $(if ($a.Count) { "$(if ($CheckOnly) { 'would add' } else { 'added' }) to PATH: $($a -join '; ')" } else { 'already on PATH' })"
  }
}

# ---------- 3 Python ----------
if (Test-Off 'ClientPython') { Write-Host 'Python: SKIP (ClientPython=off)' }
else {
  $py = Join-Path $ToolsDir 'Python'
  $exe = Join-Path $py 'python.exe'
  if (-not (Test-Path -LiteralPath $exe)) { Write-Host "Python: not found in $py - skipped"; $rc = 1 }
  else {
    $fv = [version]((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -replace '[^\d\.].*$', '')
    $tag = "$($fv.Major).$($fv.Minor)"; $full = "$($fv.Major).$($fv.Minor).$($fv.Build)"
    $a = Add-MachinePath @($py, (Join-Path $py 'Scripts'))
    $msg = "Python $full : $(if ($a.Count) { "$(if ($CheckOnly) { 'would add' } else { 'added' }) to PATH: $($a -join '; ')" } else { 'already on PATH' })"
    if (-not $CheckOnly) {
      # PEP 514 registration (what the official installer writes for an all-users install)
      $k = Open-Key "SOFTWARE\Python\PythonCore\$tag"
      try {
        $k.SetValue('DisplayName', "Python $tag (64-bit)"); $k.SetValue('SupportUrl', 'https://www.python.org/')
        $k.SetValue('Version', $full); $k.SetValue('SysVersion', $tag); $k.SetValue('SysArchitecture', '64bit')
        $ip = $k.CreateSubKey('InstallPath')
        $ip.SetValue('', ($py.TrimEnd('\') + '\')); $ip.SetValue('ExecutablePath', $exe); $ip.SetValue('WindowedExecutablePath', (Join-Path $py 'pythonw.exe')); $ip.Close()
        $pp = $k.CreateSubKey('PythonPath'); $pp.SetValue('', ((Join-Path $py 'Lib') + ';' + (Join-Path $py 'DLLs'))); $pp.Close()
      } finally { $k.Close() }
      # .py / .pyw open with it - only when nothing opens them yet
      $assoc = @()
      foreach ($x in @(@('.py', 'Python.File', $exe, 'Python File'), @('.pyw', 'Python.NoConFile', (Join-Path $py 'pythonw.exe'), 'Python File (no console)'))) {
        $c = Open-Key "SOFTWARE\Classes\$($x[0])"
        try {
          $cur = [string]$c.GetValue('', '')
          if (-not $cur -or $cur -eq $x[1]) {
            $c.SetValue('', $x[1])
            $f = Open-Key "SOFTWARE\Classes\$($x[1])"; $f.SetValue('', $x[3])
            $di = $f.CreateSubKey('DefaultIcon'); $di.SetValue('', "`"$exe`",0"); $di.Close()
            $cm = $f.CreateSubKey('shell\open\command'); $cm.SetValue('', "`"$($x[2])`" `"%1`" %*"); $cm.Close(); $f.Close()
            $assoc += $x[0]
          }
        } finally { $c.Close() }
      }
      $msg += "; registered (PythonCore\$tag)$(if ($assoc.Count) { "; opens $($assoc -join ' ')" } else { '; .py already opens with another program (left as is)' })"
    }
    Write-Host $msg
  }
}

# ---------- tell running programs (Explorer) that PATH changed ----------
if ($changedPath -and -not $TestKey) {
  try {
    Add-Type -Namespace OSYNC -Name EnvNotify -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);' -ErrorAction Stop
    $r = [UIntPtr]::Zero
    [void][OSYNC.EnvNotify]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
  } catch { }
}
exit $rc
