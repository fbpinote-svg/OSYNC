@echo off
rem Runs gamesync.js with Node.js, or with the GCafe app (Electron as Node) when Node.js is not installed.
setlocal
set "JS=%~dp0gamesync.js"
set "APP=%~dp0..\GCafe\app\0JAYSHOP.exe"
where node >nul 2>&1 || goto :electron
node "%JS%" %*
exit /b
:electron
if not exist "%APP%" goto :none
set "ELECTRON_RUN_AS_NODE=1"
"%APP%" "%JS%" %*
exit /b
:none
echo Node.js is not installed and GCafe\app\0JAYSHOP.exe is not built yet.
echo Install Node.js LTS (winget install OpenJS.NodeJS.LTS) or build the menu with GCafe\tools\Build-App.bat
exit /b 1
