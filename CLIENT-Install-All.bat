@echo off
rem CLIENT PC: run ONCE in super workstation (image edit) mode, then save the image.
rem Installs everything: Riot silent start, EA app + games + EA AntiCheat, EasyAntiCheat, 0JAYSHOP game menu,
rem and task OSYNC-Client-Boot that sets up games added later at every boot (no image edit needed for new games).
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Install-All.ps1"
echo.
pause
