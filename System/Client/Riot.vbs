' Riot.vbs - start a Riot game with no window: prepares the client (no Install/Repair), then starts Riot Client.
' Keep this file here with this name: the game menu and the client image (Run\RiotStart) point at it.
' Usage: wscript.exe Riot.vbs valorant | league_of_legends | teamfighttactics | riotclient | background  [more switches]
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scripts = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)) & "\Scripts"
product = "riotclient"
extra = ""
For i = 0 To WScript.Arguments.Count - 1
  a = WScript.Arguments(i)
  If i = 0 Then
    product = a
  ElseIf InStr(a, " ") > 0 Then
    extra = extra & " """ & a & """"
  Else
    extra = extra & " " & a
  End If
Next
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scripts & "\Client-Riot-Start.ps1"" -Product " & product & extra, 0, False
