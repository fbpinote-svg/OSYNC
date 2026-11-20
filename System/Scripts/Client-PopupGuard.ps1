# Client-PopupGuard.ps1 - CLIENT: runs hidden for the whole Windows session (System\Client\PopupGuard.vbs, started by
# Run\OSYNC-PopupGuard - Client-Install.ps1 step 1d). Closes Windows error popups that customers cannot do anything about:
#   "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_...\CrossDeviceResume.exe - The parameter is incorrect."
#   Windows 11's taskbar starts CrossDeviceResume at logon and again when the taskbar comes back after the lock screen,
#   whatever the Resume setting; on a diskless image the start fails and Windows shows this. Its only button is OK,
#   and pressing it changes nothing - closing it here is the same.
#   -Once    look one time and exit (test)          -EverySec <n>   how often to look (default 2 s)
# Log: C:\Users\Public\OSYNC-PopupGuard.log (one line per closed popup)
param([int]$EverySec = 2, [switch]$Once)
$sig = @'
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class OsyncPopupGuard {
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static List<string> Close(string[] parts) {
    List<string> done = new List<string>();
    EnumWindows(delegate(IntPtr h, IntPtr p) {
      if (!IsWindowVisible(h)) return true;
      StringBuilder c = new StringBuilder(64); GetClassName(h, c, 64);
      if (c.ToString() != "#32770") return true;
      StringBuilder t = new StringBuilder(512); GetWindowText(h, t, 512);
      string title = t.ToString();
      foreach (string part in parts) {
        if (title.IndexOf(part, StringComparison.OrdinalIgnoreCase) >= 0) { PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); done.Add(title); break; }
      }
      return true;
    }, IntPtr.Zero);
    return done;
  }
}
'@
Add-Type -TypeDefinition $sig
$parts = @('CrossDeviceResume.exe')
$log = Join-Path $env:PUBLIC 'OSYNC-PopupGuard.log'
function Look { foreach ($t in [OsyncPopupGuard]::Close($parts)) { try { Add-Content -LiteralPath $log -Value ('{0:yyyy-MM-dd HH:mm:ss} {1} closed: {2}' -f (Get-Date), $env:USERNAME, $t) -Encoding UTF8 } catch { }; $t } }
if ($Once) { Look; exit 0 }
# one guard per session
$created = $false
$m = New-Object Threading.Mutex($true, 'Local\OSYNC-PopupGuard', [ref]$created)
if (-not $created) { exit 0 }
while ($true) { [void](Look); Start-Sleep -Seconds $EverySec }
