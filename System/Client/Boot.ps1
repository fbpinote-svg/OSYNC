# Boot.ps1 - the client image's task OSYNC-Client-Boot runs this at every boot (as SYSTEM).
# Keep this file here with this name: client images point at it. The work is in System\Scripts.
& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Scripts\Client-Install.ps1') -Boot
exit $LASTEXITCODE
