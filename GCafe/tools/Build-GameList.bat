@echo off
rem MASTER: scan Steam / Riot / EA / data\games.custom.json / GAMELUNCHER and rewrite data\games.json.
rem No rebuild needed: clients read data\games.json at start (restart the client PC to see changes).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Build-GameList.ps1"
echo.
pause
