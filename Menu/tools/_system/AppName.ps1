# AppName.ps1 - dot-source: the game-menu program name comes from GCafe\config.json brandName (file-safe),
# so the .exe is GCafe\app\<brandName>.exe. Empty / missing config = 0JAYSHOP.
#   $AppName   e.g. "AT9 COM-ONLINE"        $AppExe   <GCafe>\app\AT9 COM-ONLINE.exe
#   $AppNames  every process name the menu may run under (current + the old 0JAYSHOP)
$__gcafe = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$__cfg = try { Get-Content -LiteralPath (Join-Path $__gcafe 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
$AppName = if ($__cfg -and $__cfg.brandName) { ($__cfg.brandName -replace '[\\/:*?"<>|]', '').Trim() } else { '' }
if (-not $AppName) { $AppName = '0JAYSHOP' }
$AppExe = Join-Path $__gcafe "app\$AppName.exe"
$AppNames = @($AppName, '0JAYSHOP') | Select-Object -Unique
