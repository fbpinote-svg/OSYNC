' WOMic.vbs - the game menu's "WO Mic" card: starts WO Mic Client installed on this PC (Client-Mic.ps1 installs it at
' boot when missing). WO Mic Client is not on the master, so the card cannot point at the program itself.
' Keep this file here with this name: the game menu points at it.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
exe = ""
On Error Resume Next
For Each k In Array("HKLM\SOFTWARE\WOW6432Node\Wolicheng\WOMic\Install_Dir", "HKLM\SOFTWARE\Wolicheng\WOMic\Install_Dir")
  d = ""
  d = sh.RegRead(k)
  If exe = "" And d <> "" Then
    If fso.FileExists(d & "\WOMicClient.exe") Then exe = d & "\WOMicClient.exe"
  End If
Next
On Error GoTo 0
If exe = "" Then
  For Each pf In Array(sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%"), sh.ExpandEnvironmentStrings("%ProgramFiles%"))
    For Each sub1 In Array("\WOMic\WOMicClient.exe", "\WO Mic\WOMicClient.exe")
      If exe = "" And fso.FileExists(pf & sub1) Then exe = pf & sub1
    Next
  Next
End If
If exe = "" Then
  sh.Popup "WO Mic is not installed on this PC yet. Restart the PC: it is installed at startup.", 15, "OSYNC", 48
Else
  sh.Run """" & exe & """", 1, False
End If
