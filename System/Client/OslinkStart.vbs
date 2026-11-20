' OslinkStart.vbs - start OSLink (LDPlayer remote play) in the tray at logon, with no window.
' Keep this file here with this name: the client image's task OSYNC-OslinkStart (Client-Install step 1m) points at it.
' The task runs it as the user who logs on, with that user's highest rights: ldremote.exe requires administrator, so from a
' Run entry Windows would ask for permission or skip it. Installs nothing, changes no setting.
'   1 OSLink's own service (LDRemoteSvc) starts ldremote.exe by itself a few seconds after logon: when it runs, nothing to
'     do - never a second copy (opening OSLink again can bring its window to the front)
'   2 waits until OSLink's drivers are loaded (boot step 1l puts them in; OSLink checks them when it starts) - 3 min at most
'   3 starts "ldremote.exe --pcstart" hidden = OSLink's own "start with Windows" command (its Run entry on the master)
' Not elevated (a standard user) = not started: it would ask for an administrator.
' Log: C:\Users\Public\OSYNC-OslinkStart.log    Test: cscript //nologo OslinkStart.vbs /check (shows only, starts nothing)
Option Explicit
Dim sh, fso, wmi, exe, checkOnly, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
checkOnly = False
If WScript.Arguments.Count > 0 Then checkOnly = (InStr(1, WScript.Arguments(0), "check", vbTextCompare) > 0)

Sub Log(text)
  On Error Resume Next
  Dim f
  If checkOnly Then WScript.Echo text : Exit Sub
  Set f = fso.OpenTextFile(sh.ExpandEnvironmentStrings("%PUBLIC%") & "\OSYNC-OslinkStart.log", 8, True)
  f.WriteLine Now & " " & sh.ExpandEnvironmentStrings("%USERNAME%") & " " & text
  f.Close
End Sub

Function RegRead(path)
  Dim v
  On Error Resume Next
  v = sh.RegRead(path)
  If Err.Number <> 0 Then v = ""
  Err.Clear
  RegRead = v
End Function

Function ExeIn(folder)
  Dim d
  d = folder
  ExeIn = ""
  If d = "" Then Exit Function
  If Right(d, 1) = "\" Then d = Left(d, Len(d) - 1)
  If fso.FileExists(d & "\ldremote.exe") Then ExeIn = d & "\ldremote.exe"
End Function

' 1 the folder of the OSLink service's program  2 what OSLink's installer wrote  3 <drive>:\LDPlayer\OSLink\bin
Function FindExe()
  Dim p, n, r
  r = ""
  p = Replace(RegRead("HKLM\SYSTEM\CurrentControlSet\Services\LDRemoteSvc\ImagePath"), """", "")
  n = InStr(1, p, ".exe", vbTextCompare)
  If n > 0 Then r = ExeIn(fso.GetParentFolderName(Trim(Left(p, n + 3))))
  If r = "" Then r = ExeIn(RegRead("HKLM\SOFTWARE\XuanZhi\OSLink\InstallDir"))
  If r = "" Then r = ExeIn(RegRead("HKLM\SOFTWARE\WOW6432Node\XuanZhi\OSLink\InstallDir"))
  For n = Asc("D") To Asc("Z")
    If r <> "" Then Exit For
    r = ExeIn(Chr(n) & ":\LDPlayer\OSLink\bin")
  Next
  FindExe = r
End Function

Function IsRunning()
  Dim n
  On Error Resume Next
  n = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name = 'ldremote.exe'").Count
  If Err.Number <> 0 Then n = 0
  Err.Clear
  IsRunning = (n > 0)
End Function

' running for real: the service also starts copies that quit within a second - seen twice, 4 s apart
Function StaysRunning()
  StaysRunning = False
  If Not IsRunning() Then Exit Function
  WScript.Sleep 4000
  StaysRunning = IsRunning()
End Function

' Windows runs each driver for a device (Services\<driver>\Enum Count, written when Windows loads it)
Function DriversLoaded()
  Dim s, ok
  ok = True
  For Each s In Array("LdVMou", "LdVKbd", "LdScpVBus")
    If CLng("0" & RegRead("HKLM\SYSTEM\CurrentControlSet\Services\" & s & "\Enum\Count")) < 1 Then ok = False
  Next
  DriversLoaded = ok
End Function

' elevated = high integrity (S-1-16-12288) in this process's token
Function IsElevated()
  IsElevated = (sh.Run("cmd.exe /c whoami.exe /groups | find.exe ""S-1-16-12288"" >nul", 0, True) = 0)
End Function

exe = FindExe()
If checkOnly Then
  If exe = "" Then
    Log "OSLink: ldremote.exe not found - would do nothing"
  Else
    Log "OSLink: " & exe
    Log "drivers loaded (LdVMou, LdVKbd, LdScpVBus): " & DriversLoaded()
    Log "ldremote.exe running now: " & IsRunning()
    Log "elevated: " & IsElevated()
    Log "would start hidden, when not running after the wait: """ & exe & """ --pcstart"
  End If
  WScript.Quit 0
End If
If exe = "" Then Log "ldremote.exe not found - nothing started" : WScript.Quit 0

' 1 + 2: give the service 20 s, then start as soon as the drivers are loaded (3 min at most)
For i = 1 To 90
  If StaysRunning() Then Log "OSLink already running (started by its service) - nothing to do" : WScript.Quit 0
  If i >= 10 And DriversLoaded() Then Exit For
  WScript.Sleep 2000
Next
If StaysRunning() Then Log "OSLink already running - nothing to do" : WScript.Quit 0
If Not IsElevated() Then Log "not elevated (not an administrator) - not started, it would ask for an administrator" : WScript.Quit 0
' 3
sh.CurrentDirectory = fso.GetParentFolderName(exe)
sh.Run """" & exe & """ --pcstart", 0, False
If DriversLoaded() Then
  Log "started hidden: " & exe & " --pcstart"
Else
  Log "started hidden: " & exe & " --pcstart (drivers still not loaded after 3 min - OSLink may show its driver warning)"
End If
