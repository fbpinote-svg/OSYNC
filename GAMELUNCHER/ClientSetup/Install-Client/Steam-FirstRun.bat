@echo off
rem CLIENT PC (super workstation / image mode): run every Steam game's first-run setup
rem (anti-cheat, Social Club, DirectX, VC++ ...) once, then save the image.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Steam-FirstRun.ps1"
echo.
pause
