@echo off
rem MASTER: stop MASTER-Start-All (launchers are no longer reopened, client data no longer refreshed by itself).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Master-Watch.ps1" -Unregister
echo.
pause
