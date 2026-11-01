@echo off
rem MASTER: run after installing / updating / removing games (GAMELUNCHER\ClientSetup\MASTER-Start-All.bat does it by itself).
rem Refreshes Riot, EA, Epic and EasyAntiCheat data for clients and rescans the game menu list.
setlocal
rem started from PowerShell 7: its module path breaks Windows PowerShell (Get-FileHash not found)
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Update-All.ps1"
echo.
pause
