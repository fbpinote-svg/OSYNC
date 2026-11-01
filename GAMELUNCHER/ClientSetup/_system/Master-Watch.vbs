' Master-Watch.vbs - start Master-Watch.ps1 with no window (HKCU Run "OSYNC-Master" runs this at logon).
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Master-Watch.ps1""", 0, False
