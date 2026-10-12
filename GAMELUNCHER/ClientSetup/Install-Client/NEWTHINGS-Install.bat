@echo off
rem CLIENT PC (super workstation / image mode): set up NEWTHINGS-GAMES (GTA SA / SA-MP) and, if you answer Y,
rem fix Thai text that shows as "alien" letters (system locale Thai, UTF-8 beta off). Then save the image + restart.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "FIX="
choice /C YN /M "Fix Thai text in games (needs a restart)"
if not errorlevel 2 set "FIX=-FixThaiText"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\NEWTHINGS-ClientInstall.ps1" %FIX%
echo.
pause
