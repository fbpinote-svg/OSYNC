@echo off
rem MASTER: run after installing / updating / removing games (close Riot Client first if a game is updating).
rem Refreshes Riot, EA, Epic and EasyAntiCheat data for clients and rescans the game menu list.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Update-All.ps1"
echo.
pause
