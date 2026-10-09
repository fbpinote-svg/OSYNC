@echo off
echo Close Riot Client first if a game is still updating.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Snapshot-Metadata.ps1"
echo.
pause
