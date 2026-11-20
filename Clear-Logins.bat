@echo off
rem Clear-Logins.bat - CLIENT PC: sign out of every game launcher for every user of this PC.
rem   FiveM / RedM, Rockstar (Social Club), Steam, Epic, EA app, Riot, Ubisoft, Battle.net, Garena, HoYoPlay, Discord:
rem   closes them, then deletes their saved logins. Games, game settings (GTA graphics) and saves stay.
rem   Does nothing on the master (the shop's own logins live there).
rem   Clear-Logins.bat          clear now (asks for administrator)
rem   Clear-Logins.bat check    only list what would be deleted
rem The same runs by itself at every client boot (Client-Install step 1i; Settings ClientClearLogins=on/off).
rem How it works: System\Scripts\Client-ClearLogins.ps1
setlocal
set "PSModulePath="
set "OSYNC_BAT=%~f0"
set "OSYNC_ARG=%~1"
fltmc >nul 2>&1
if errorlevel 1 (
  echo Needs administrator rights: press Yes on the Windows prompt.
  powershell.exe -NoProfile -Command "$a = @{ FilePath = $env:OSYNC_BAT; Verb = 'RunAs' }; if ($env:OSYNC_ARG) { $a.ArgumentList = $env:OSYNC_ARG }; Start-Process @a"
  exit /b
)
if /i "%~1"=="check" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System\Scripts\Client-ClearLogins.ps1" -CheckOnly
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System\Scripts\Client-ClearLogins.ps1"
)
echo.
pause
