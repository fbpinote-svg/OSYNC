@echo off
rem EASY-INSTALL.bat - install OSYNC on THIS master PC from this folder (a download of the OSYNC project,
rem e.g. GitHub > Code > Download ZIP, unzipped). It looks at the PC first and suggests where each part goes
rem (Enter = the suggestion), then copies OSYNC there and starts the first-time setup.
rem Guide: System\Docs\00-EASY-INSTALL.md
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System\Scripts\Setup-Install.ps1" -Source "%~dp0." %*
