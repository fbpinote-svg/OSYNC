@echo off
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\EA-ClientInstall.ps1" -Autostart
echo.
echo   (window closes in 15 seconds)
ping -n 16 127.0.0.1 >nul
