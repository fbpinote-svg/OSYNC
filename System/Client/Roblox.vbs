' Roblox.vbs - Roblox straight from the game disk: points this user's roblox:// links at the newest Roblox in
' Launchers\Roblox (no install on the client), then starts Roblox when asked.
' Keep this file here with this name: the game menu and the client image (Run\RobloxPrep) point at it.
' Usage: wscript.exe Roblox.vbs launch | background
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
mode = "launch"
If WScript.Arguments.Count > 0 Then mode = WScript.Arguments(0)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-Roblox.ps1"" -Mode " & mode, 0, False
