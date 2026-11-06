@echo off
rem GameSync SOURCE - on the master that HAS the games. Indexes the games on the drives in GameSync\gamesync.json
rem (source.drives, default EFHI) and shares them with other masters. Keep this window open.
rem First run makes GameSync\gamesync.json with a new key: copy that key to every destination.
rem Allow the port once in Windows Firewall (Command Prompt as admin, change 18765 if you changed the port):
rem   netsh advfirewall firewall add rule name="OSYNC GameSync" dir=in action=allow protocol=TCP localport=18765
rem   GAMESYNC-Source.bat           index + share
rem   GAMESYNC-Source.bat status    what is indexed
setlocal
title OSYNC GameSync - source
if /i "%~1"=="status" ( call "%~dp0GameSync\run-node.cmd" status & pause & exit /b )
call "%~dp0GameSync\run-node.cmd" serve %*
pause
