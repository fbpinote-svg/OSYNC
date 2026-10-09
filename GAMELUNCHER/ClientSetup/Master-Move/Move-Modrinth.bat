@echo off
rem Move the Modrinth launcher installed on this MASTER into GAMELUNCHER (real move).
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Move-Launcher.ps1" -Launcher Modrinth -DryRun
if errorlevel 1 ( pause & exit /b )
echo.
choice /C YN /M "Move Modrinth now"
if errorlevel 2 exit /b
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_system\Move-Launcher.ps1" -Launcher Modrinth
echo.
pause