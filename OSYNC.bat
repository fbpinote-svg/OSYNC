@echo off
rem OSYNC - the one button for every PC (master and client). Without a word it shows a menu.
rem   OSYNC.bat master   update clients now + keep launchers open / auto update  (the old All-In-One for the master)
rem   OSYNC.bat client   install everything on this client (super workstation mode, then save the image)
rem   OSYNC.bat update   update clients now          OSYNC.bat check   check the system
rem   OSYNC.bat setup    first-time setup of a new master
rem How it all works: System\Docs\HOW-IT-WORKS.md
setlocal
rem started from PowerShell 7: its module path breaks Windows PowerShell (Get-FileHash not found)
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System\Scripts\OSYNC.ps1" %*
