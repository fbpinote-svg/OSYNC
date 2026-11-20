' GameStart.vbs - start a game the iPlay way, with no window: closes hung copies of the game / anti-cheat, checks the PC,
' then the publisher's launcher starts it (System\Scripts\Client-GameStart.ps1, games in Settings\game-start.json).
' Keep this file here with this name: the game menu points at it.
' Usage: wscript.exe GameStart.vbs <menu card id>      e.g. steam-1172470
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
If WScript.Arguments.Count = 0 Then WScript.Quit 1
id = WScript.Arguments(0)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-GameStart.ps1"" -Id """ & id & """", 0, False
