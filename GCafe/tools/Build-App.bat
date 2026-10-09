@echo off
rem MASTER: rebuild the program from source\ and publish it to app\ (only after editing source\).
rem Close 0JAYSHOP on this PC first. Ends with a self-test that opens the game menu for a few seconds.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\Build-App.ps1"
echo.
pause
