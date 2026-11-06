@echo off
rem GameSync DESTINATION - on a master that copies games from the source master.
rem Set pull.url (e.g. http://100.64.0.10:18765) and the same "key" as the source in GameSync\gamesync.json first.
rem   GAMESYNC-Pull.bat            copy what changed, now (only inside pull.hours)
rem   GAMESYNC-Pull.bat list       show what would change, copy nothing
rem   GAMESYNC-Pull.bat --watch    keep checking every pull.everyMinutes (keep the window open)
rem   GAMESYNC-Pull.bat status     what is up to date
rem Steam games are only copied while Steam is closed on this PC. Files removed at the source are moved (never
rem deleted) to the trash folder on the same drive - see GameSync\README-TH.md.
setlocal
title OSYNC GameSync - pull
if /i "%~1"=="list"   ( call "%~dp0GameSync\run-node.cmd" list & pause & exit /b )
if /i "%~1"=="status" ( call "%~dp0GameSync\run-node.cmd" status & pause & exit /b )
call "%~dp0GameSync\run-node.cmd" pull %*
pause
