@echo off
rem Every logon: silently prepare Riot and start Riot Client in the tray.
rem Diskless clients: run ONCE as administrator in super-workstation (image edit) mode.
for %%I in ("%~dp0..\RiotSilent.vbs") do set "VBS=%%~fI"
set "SCOPE=current user (HKCU)"
net session >nul 2>&1
if %errorlevel%==0 (
  reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v RiotStart /t REG_SZ /d "wscript.exe \"%VBS%\" background" /f >nul
  set "SCOPE=all users (HKLM)"
) else (
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v RiotStart /t REG_SZ /d "wscript.exe \"%VBS%\" background" /f >nul
)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v RiotClient /f >nul 2>&1
echo.
echo   Riot startup installed for %SCOPE%
echo   Runs at logon: wscript.exe "%VBS%" background
echo.
start "" wscript.exe "%VBS%" background
ping -n 6 127.0.0.1 >nul