' Epic.vbs - start an Epic game with no window: gives the client the master's Epic install list, then starts it.
' Keep this file here with this name: the game menu points at it.
' Usage: wscript.exe Epic.vbs <AppName>      e.g. Fortnite
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
app = "Fortnite"
If WScript.Arguments.Count > 0 Then app = WScript.Arguments(0)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-Epic-Start.ps1"" -App """ & app & """", 0, False
