' Medal.vbs - the game menu's "Medal" card (18 Nov 2026): Medal (game clips / screen recording) runs straight from the game
' disk (Tools\Medal = Medal's own signed package, unpacked; nothing installed, every customer signs in with their own account,
' a reboot forgets it). Medal's first start puts a "Medal" shortcut on the desktop; in this shop the desktop shows only the
' game menu (Settings ClientDesktopMenuOnly), so that shortcut is taken off again while Medal starts.
' Keep this file here with this name: the game menu points at it.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)))
exe = root & "\Tools\Medal\Medal.exe"
If Not fso.FileExists(exe) Then
  sh.Popup "Medal not found: " & exe, 15, "OSYNC", 48
  WScript.Quit 1
End If
sh.CurrentDirectory = fso.GetParentFolderName(exe)
sh.Run """" & exe & """", 1, False
desk = sh.SpecialFolders("Desktop") & "\Medal.lnk"
pub = sh.SpecialFolders("AllUsersDesktop") & "\Medal.lnk"
On Error Resume Next
For i = 1 To 45
  WScript.Sleep 2000
  If fso.FileExists(desk) Then fso.DeleteFile desk, True
  If fso.FileExists(pub) Then fso.DeleteFile pub, True
Next
