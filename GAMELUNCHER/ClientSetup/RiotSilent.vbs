' RiotSilent.vbs - run RiotStart.ps1 with no visible window.
' Usage: wscript.exe RiotSilent.vbs <product> [extra RiotStart.ps1 switches]
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
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
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\_system\RiotStart.ps1"" -Product " & product & extra
sh.Run cmd, 0, False