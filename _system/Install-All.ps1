# _system\Install-All.ps1 - forwarder for client images made with the old OSYNC layout (before Tool-Migrate):
# their task OSYNC-Client-Boot runs <OSYNC>\_system\Install-All.ps1 -Boot. The boot setup is now System\Client\Boot.ps1.
# Make new images with OSYNC.bat client; when every image is new, this folder can go.
param([switch]$Boot)
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'System\Client\Boot.ps1')
exit $LASTEXITCODE
