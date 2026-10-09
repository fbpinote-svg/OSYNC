# Build-App.ps1 - rebuild the client from <GCafe>\source and publish it to <GCafe>\app.
# No Node.js install needed: the Electron binary in source\node_modules runs as Node.
#   Build-App.ps1            build + publish + self-test (screenshots in <GCafe>\_build\selftest)
#   Build-App.ps1 -NoTest    skip the self-test
param([switch]$NoTest)
$ErrorActionPreference = 'Stop'
$gcafe   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$src     = Join-Path $gcafe 'source'
$runtime = Join-Path $gcafe '_build\electron-runtime'
$appDir  = Join-Path $gcafe 'app'
$electron = Join-Path $src 'node_modules\electron\dist\electron.exe'

if (Get-Process -Name '0JAYSHOP' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$appDir\*" }) { throw "Close 0JAYSHOP.exe (running from $appDir) first." }
if (-not (Test-Path -LiteralPath $electron)) { throw "source\node_modules is missing: install Node.js LTS, then run 'npm ci' in $src" }

# first build on a new PC: make the runtime from Electron (electron.exe -> 0JAYSHOP.exe, no default app)
if (-not (Test-Path -LiteralPath (Join-Path $runtime '0JAYSHOP.exe'))) {
  Write-Output 'creating _build\electron-runtime from source\node_modules\electron...'
  & robocopy.exe (Split-Path -Parent $electron) $runtime /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "runtime copy failed ($LASTEXITCODE)" }
  Move-Item -LiteralPath (Join-Path $runtime 'electron.exe') -Destination (Join-Path $runtime '0JAYSHOP.exe') -Force
  $def = Join-Path $runtime 'resources\default_app.asar'; if (Test-Path -LiteralPath $def) { Remove-Item -LiteralPath $def -Force }
}

# 1) Next.js static export -> source\out
Write-Output 'building web pages...'
Push-Location $src
try {
  $env:ELECTRON_RUN_AS_NODE = '1'; $env:NEXT_TELEMETRY_DISABLED = '1'
  & $electron (Join-Path $src 'node_modules\next\dist\bin\next') build 2>&1 | Where-Object { $_ -match 'Compiled|error|Error|warn|Route|/dialog' } | ForEach-Object { "  $_" }
  if ($LASTEXITCODE -ne 0) { throw "next build failed ($LASTEXITCODE)" }
} finally { Remove-Item Env:\ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue; Pop-Location }

# 2) publish: Electron runtime + resources\app (package.json, electron\, out\)
Write-Output 'publishing to app\...'
# (retries: right after the app closes, antivirus may still hold 0JAYSHOP.exe for a few seconds)
& robocopy.exe $runtime $appDir /E /XF app.asar /XD app /R:10 /W:3 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "runtime copy failed ($LASTEXITCODE)" }
$asar = Join-Path $appDir 'resources\app.asar'; if (Test-Path -LiteralPath $asar) { Remove-Item -LiteralPath $asar -Force }
$res = Join-Path $appDir 'resources\app'
& robocopy.exe (Join-Path $src 'electron') (Join-Path $res 'electron') /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
& robocopy.exe (Join-Path $src 'out') (Join-Path $res 'out') /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
$pkg = Get-Content -LiteralPath (Join-Path $src 'package.json') -Raw | ConvertFrom-Json
$min = [ordered]@{ name = $pkg.name; version = $pkg.version; main = 'electron/main.js' }
[IO.File]::WriteAllText((Join-Path $res 'package.json'), (ConvertTo-Json $min), (New-Object Text.UTF8Encoding $false))
# shop icon (data\brand\app.ico from Make-Brand.ps1) into the .exe
$ico = Join-Path $gcafe 'data\brand\app.ico'
if (Test-Path -LiteralPath $ico) { & (Join-Path $PSScriptRoot 'Set-ExeIcon.ps1') -Exe (Join-Path $appDir '0JAYSHOP.exe') -Ico $ico }
Write-Output "published: $appDir\0JAYSHOP.exe"

# 3) self-test: open the game menu, screenshot, count cards
if (-not $NoTest) {
  $st = Join-Path $gcafe '_build\selftest'; New-Item -ItemType Directory -Force -Path $st | Out-Null
  Get-ChildItem $st -File | Remove-Item -Force
  $env:GCAFE_SELFTEST = $st
  $p = Start-Process -FilePath (Join-Path $appDir '0JAYSHOP.exe') -PassThru
  Remove-Item Env:\GCAFE_SELFTEST
  if (-not $p.WaitForExit(40000)) { $p | Stop-Process -Force; throw 'self-test timed out' }
  Get-Content (Join-Path $st 'selftest.json')
}
