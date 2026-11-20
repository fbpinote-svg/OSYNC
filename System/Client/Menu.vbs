' Menu.vbs - start the game menu (Menu\app\<shop name>.exe). The StartUp / desktop shortcuts point at this file,
' so a new shop name (= a new .exe name) needs no image edit. Keep this file here with this name.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)))
menu = sh.Environment("PROCESS")("OSYNC_MENU")
If menu = "" Then menu = root & "\Menu"
appDir = menu & "\app"
exe = ""
If fso.FolderExists(appDir) Then
  ' the shop-named exe; 0JAYSHOP.exe is the older name, kept as a copy, used only when nothing else is there
  For Each f In fso.GetFolder(appDir).Files
    If LCase(fso.GetExtensionName(f.Name)) = "exe" And LCase(f.Name) <> "0jayshop.exe" Then exe = f.Path
  Next
  If exe = "" And fso.FileExists(appDir & "\0JAYSHOP.exe") Then exe = appDir & "\0JAYSHOP.exe"
End If
If exe = "" Then
  sh.Popup "Game menu not found in " & appDir, 15, "OSYNC", 16
Else
  sh.CurrentDirectory = appDir
  sh.Run """" & exe & """", 1, False
End If
