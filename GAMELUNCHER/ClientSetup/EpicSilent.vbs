' EpicSilent.vbs - run EpicStart.ps1 with no visible window.
' Usage: wscript.exe EpicSilent.vbs <AppName>      e.g. Fortnite
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
app = "Fortnite"
If WScript.Arguments.Count > 0 Then app = WScript.Arguments(0)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\_system\EpicStart.ps1"" -App """ & app & """"
sh.Run cmd, 0, False
