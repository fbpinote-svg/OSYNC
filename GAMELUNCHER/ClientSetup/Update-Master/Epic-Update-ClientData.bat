@echo off
rem MASTER: after installing/updating an Epic game (e.g. Fortnite) - lets client PCs see it.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Snapshot-Epic.ps1"
echo.
pause
