' Master-Watch.vbs - start Master-Watch.ps1 with no window. At logon: the task "OSYNC-Master-Watch" runs it with "task",
' HKCU Run "OSYNC-Master" with "run"; Master-Watch.ps1 writes who started it to its log, and only one watcher runs.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
src = "manual"
If WScript.Arguments.Count > 0 Then
  If WScript.Arguments(0) = "task" Or WScript.Arguments(0) = "run" Then src = WScript.Arguments(0)
End If
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Master-Watch.ps1"" -From " & src, 0, False
