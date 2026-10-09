@echo off
rem CLIENT PC (super workstation / image mode): remove the game menu from Startup and the desktop.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Install-Client.ps1" -Uninstall
echo.
pause
