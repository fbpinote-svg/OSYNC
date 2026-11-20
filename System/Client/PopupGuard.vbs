' PopupGuard.vbs - start the hidden popup guard for this Windows session (closes the CrossDeviceResume error popup).
' Keep this file here with this name: the client image (Run\OSYNC-PopupGuard) points at it.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-PopupGuard.ps1""", 0, False
