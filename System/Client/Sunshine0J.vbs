' Sunshine0J.vbs - the game menu's "Sunshine 0JAYSHOP" card (17 Nov 2026): starts the shop's newer Sunshine from
' Tools\Sunshine0J on demand - not a service, not at boot. System\Scripts\Client-Sunshine0J.ps1 does the work, hidden:
' it stops the image's own Sunshine first (same ports), sets the port from this PC's IP, then starts it (tray icon).
' Argument AutoStart (logon task OSYNC-Sunshine0J, 18 Nov 2026): tray start only on PCs without their own Sunshine, no popup.
' Keep this file here with this name: the game menu points at it.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps1 = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts\Client-Sunshine0J.ps1"
args = ""
If WScript.Arguments.Count > 0 Then args = " -" & WScript.Arguments(0)
rc = sh.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """" & args, 0, True)
If rc <> 0 And WScript.Arguments.Count = 0 Then sh.Popup "Sunshine 0JAYSHOP did not start. Log: C:\Users\Public\OSYNC-Sunshine0J.log", 15, "OSYNC", 48
