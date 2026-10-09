@echo off
rem CLIENT PC (super workstation / image mode): install EA AntiCheat for Apex / Battlefield, then save the image.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\EAAntiCheat-Install.ps1"
echo.
pause
