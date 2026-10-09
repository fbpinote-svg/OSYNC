# Snapshot-EA.ps1 - run on the MASTER (no admin needed). Exports the EA app registry
# (HKLM Electronic Arts keys + origin/origin2/link2ea/ealink protocols) into ea-client.reg,
# with every install path pointed at the shared copy in GAMELUNCHER. EA-ClientInstall.ps1 imports it.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Settings.ps1')
$setupDir = $KitSystem
$shared = Get-SharedDrives
$oldEsc = 'C:\\Program Files\\Electronic Arts\\EA Desktop'
$newEsc = (Join-Path $KitRoot 'EA Desktop') -replace '\\', '\\'
Write-Output "shared drives: $shared   EA app: $(Join-Path $KitRoot 'EA Desktop')"
$keys = 'HKLM\SOFTWARE\Electronic Arts', 'HKLM\SOFTWARE\WOW6432Node\Electronic Arts',
        'HKLM\SOFTWARE\Classes\origin', 'HKLM\SOFTWARE\Classes\origin2',
        'HKLM\SOFTWARE\Classes\link2ea', 'HKLM\SOFTWARE\Classes\ealink'
$tmp = Join-Path $env:TEMP ('ea_snap_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$body = New-Object System.Text.StringBuilder
[void]$body.AppendLine('Windows Registry Editor Version 5.00')
$i = 0
foreach ($k in $keys) {
    $i++; $f = Join-Path $tmp "$i.reg"
    & reg.exe export $k $f /y 2>$null | Out-Null
    if (-not (Test-Path $f)) { Write-Warning "missing key: $k"; continue }
    $t = [IO.File]::ReadAllText($f)        # reg export writes UTF-16 LE
    $t = $t -replace '^\s*Windows Registry Editor Version 5\.00\s*', ''
    [void]$body.AppendLine(''); [void]$body.Append($t.Replace($oldEsc, $newEsc).Replace($oldEsc.ToLower(), $newEsc))
}
$out = Join-Path $setupDir 'ea-client.reg'
[IO.File]::WriteAllText($out, $body.ToString(), [Text.Encoding]::Unicode)
Get-ChildItem $tmp | ForEach-Object { $_.Delete() }; [IO.Directory]::Delete($tmp)
$left = (Select-String -Path $out -Pattern 'Program Files\\\\Electronic Arts' -SimpleMatch:$false | Measure-Object).Count
Write-Output "written: $out  (lines still pointing at C:\Program Files\Electronic Arts: $left)"

# --- games installed through the EA app: their "Install Dir" keys (EA's install check), their
#     uninstall keys (by Product GUID) and EA's install records, for games on shared disks E-I
$gameKeys = @{}
foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node', 'HKLM:\SOFTWARE') {
    foreach ($pub in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        foreach ($k in Get-ChildItem $pub.PSPath -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            $d = $p.'Install Dir'
            if ($d -and $d -match ('^[' + $shared + ']:\\') -and (Test-Path -LiteralPath $d)) { $gameKeys[$k.Name] = $p.'Product GUID' }
        }
    }
}
$gb = New-Object System.Text.StringBuilder
[void]$gb.AppendLine('Windows Registry Editor Version 5.00')
$exportList = New-Object System.Collections.Generic.List[string]
foreach ($name in $gameKeys.Keys) {
    $exportList.Add($name)
    $guid = $gameKeys[$name]
    if ($guid) { foreach ($u in "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$guid", "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid") { if (Test-Path "Registry::$u") { $exportList.Add($u) } } }
}
$tmp2 = Join-Path $env:TEMP ('ea_games_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp2 | Out-Null
$j = 0
foreach ($k in ($exportList | Sort-Object -Unique)) {
    $j++; $f = Join-Path $tmp2 "$j.reg"
    & reg.exe export $k $f /y 2>$null | Out-Null
    if (Test-Path $f) { [void]$gb.AppendLine(''); [void]$gb.Append(([IO.File]::ReadAllText($f) -replace '^\s*Windows Registry Editor Version 5\.00\s*', '')) }
}
Get-ChildItem $tmp2 | ForEach-Object { $_.Delete() }; [IO.Directory]::Delete($tmp2)
$gamesReg = Join-Path $setupDir 'ea-games.reg'
[IO.File]::WriteAllText($gamesReg, $gb.ToString(), [Text.Encoding]::Unicode)
$installData = Join-Path $env:ProgramData 'EA Desktop\InstallData'
if (Test-Path $installData) { & robocopy.exe $installData (Join-Path $setupDir 'EA-InstallData') /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null }
Write-Output ("EA games for clients: " + (($gameKeys.Keys | ForEach-Object { ($_ -split '\\')[-1] + ' -> ' + (Get-ItemProperty "Registry::$_").'Install Dir' }) -join '; '))
Write-Output "written: $gamesReg  + EA-InstallData ($((Get-ChildItem (Join-Path $setupDir 'EA-InstallData') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', '))"
