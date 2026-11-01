@echo off
rem MASTER only, press once: opens every launcher now and at every logon and keeps them open, so games
rem update by themselves; when an update is done it refreshes client data (MASTER-Update-All) by itself,
rem so clients play the new version without REPAIR. Turn off: Update-Master\Master-Start-All-Off.bat
rem Log: C:\Users\Public\OSYNC-Master-Watch.log
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Master-Watch.ps1" -Register
echo.
pause
