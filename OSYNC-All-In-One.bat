@echo off
rem OSYNC-All-In-One: the one button for every PC. It works out which PC it is on, then does everything:
rem   MASTER (has C:\lwserver, or MASTER-Start-All already set up): refresh client data now (MASTER-Update-All),
rem          then keep every launcher open and refresh by itself from now on (MASTER-Start-All)
rem   CLIENT (every other PC): asks for admin and installs everything (CLIENT-Install-All).
rem          Run it in super workstation (image edit) mode, then save the image.
rem Wrong PC type (e.g. a master without C:\lwserver)? Say which: OSYNC-All-In-One.bat master   or   ... client
rem How it all works: HOW-IT-WORKS.md
setlocal
rem started from PowerShell 7: its module path breaks Windows PowerShell (Get-FileHash not found)
set "PSModulePath="
set "mode=%~1"
if defined mode goto chosen
set "mode=client"
if exist "C:\lwserver\" set "mode=master"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OSYNC-Master >nul 2>&1
if not errorlevel 1 set "mode=master"
:chosen
if /i "%mode%"=="master" goto master
if /i "%mode%"=="client" goto client
echo Use: %~nx0 [master^|client]
pause
exit /b 1

:master
echo OSYNC All-In-One: this PC is the MASTER
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Update-All.ps1"
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GAMELUNCHER\ClientSetup\_system\Master-Watch.ps1" -Register
echo.
pause
exit /b

:client
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'client' -Verb RunAs"
  exit /b
)
echo OSYNC All-In-One: this PC is a CLIENT
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Install-All.ps1"
echo.
pause
