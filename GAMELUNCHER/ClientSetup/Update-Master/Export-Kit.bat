@echo off
echo Packing the GAMELUNCHER kit for another branch...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Export-Kit.ps1"
echo.
pause
