@echo off
rem Move HoYoPlay into GAMELUNCHER (same drive = instant rename). Its games go to <drive>:\Mobile\<game>.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Move-Launcher.ps1" -Launcher HoYoPlay -DryRun
if errorlevel 1 ( pause & exit /b )
echo.
choice /C YN /M "Move HoYoPlay now"
if errorlevel 2 exit /b
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Move-Launcher.ps1" -Launcher HoYoPlay
echo.
pause