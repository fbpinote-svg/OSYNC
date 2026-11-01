@echo off
rem CLIENT PC (image edit mode, then save the image): stop setting up new games at every boot
rem (removes task OSYNC-Client-Boot that CLIENT-Install-All.bat creates). Back on: run CLIENT-Install-All.bat again.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
schtasks.exe /Delete /TN OSYNC-Client-Boot /F
echo.
pause
