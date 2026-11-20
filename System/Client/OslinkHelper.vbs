' OslinkHelper.vbs - start the hidden OSLink sign-in helper for this Windows session (Client-OslinkHelper.ps1).
' Keep this file here with this name: task OSYNC-OslinkHelper (made at boot by Client-OslinkLogin.ps1) points at it.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-OslinkHelper.ps1""", 0, False
