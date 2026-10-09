@echo off
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v RiotStart /f >nul 2>&1
net session >nul 2>&1
if %errorlevel%==0 reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v RiotStart /f >nul 2>&1
echo.
echo   Riot startup removed
echo.
ping -n 5 127.0.0.1 >nul