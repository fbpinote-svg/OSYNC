# RiotDiag.ps1 - run on a CLIENT that shows "REPAIR NEEDED". Writes a short report and opens it.
$setupDir = Split-Path -Parent $MyInvocation.MyCommand.Path               # ...\ClientSetup\_system
$rc       = Join-Path (Split-Path -Parent (Split-Path -Parent $setupDir)) 'RiotClient'
$out      = Join-Path $env:TEMP 'RiotDiag.txt'
$r = New-Object System.Collections.Generic.List[string]
function A($s) { $r.Add([string]$s) }
A ("RiotDiag  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "  PC=" + $env:COMPUTERNAME + "  user=" + $env:USERNAME)
A ("admin=" + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) + "  vgc=" + ((Get-Service vgc -ErrorAction SilentlyContinue).Status) + "  vgk=" + ((Get-Service vgk -ErrorAction SilentlyContinue).Status))

# 1) Riot Client files vs the master's list
A ''; A '== 1) Riot Client files vs master =='
$exp = Import-Csv (Join-Path $setupDir 'riotclient-files.csv')
$missing = 0; $size = 0; $hash = 0; $bad = @()
foreach ($e in $exp) {
    $p = Join-Path $rc $e.Rel
    if (-not (Test-Path -LiteralPath $p)) { $missing++; $bad += "MISSING  $($e.Rel)"; continue }
    $len = (Get-Item -LiteralPath $p -Force).Length
    if ($len -ne [long]$e.Length) { $size++; $bad += "SIZE     $($e.Rel)  ($len vs $($e.Length))"; continue }
    if ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $e.SHA256) { $hash++; $bad += "CONTENT  $($e.Rel)" }
}
A ("checked $($exp.Count) files: missing=$missing size-diff=$size content-diff=$hash")
$bad | Select-Object -First 15 | ForEach-Object { A ("  " + $_) }
$extra = @(Get-ChildItem -LiteralPath $rc -Recurse -File -Force | Where-Object { $exp.Rel -notcontains $_.FullName.Substring($rc.Length + 1) })
A ("extra files on this PC (not on master): " + $extra.Count)
$extra | Select-Object -First 8 | ForEach-Object { A ("  EXTRA    " + $_.FullName.Substring($rc.Length + 1) + "  " + $_.LastWriteTime) }

# 2) local Riot state
A ''; A '== 2) ProgramData Riot Games =='
$pd = Join-Path $env:ProgramData 'Riot Games'
A ("RiotClientInstalls.json: " + ((Get-Content (Join-Path $pd 'RiotClientInstalls.json') -Raw -ErrorAction SilentlyContinue) -replace '\s+', ' '))
A ("Metadata: " + ((Get-ChildItem (Join-Path $pd 'Metadata') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', '))
A ("other Riot dirs: " + ((@('C:\Riot Games', "$env:LOCALAPPDATA\Riot Games") | Where-Object { Test-Path $_ } | ForEach-Object { $_ + '[' + ((Get-ChildItem $_ -Directory | ForEach-Object Name) -join ',') + ']' }) -join '  '))

# 3) RiotStart log
A ''; A '== 3) RiotStart.log (last lines) =='
Get-Content (Join-Path $env:TEMP 'RiotStart.log') -Tail 8 -ErrorAction SilentlyContinue | ForEach-Object { A ("  " + $_) }

# 4) Riot Client log
A ''; A '== 4) Riot Client log (repair / errors) =='
$lg = Get-ChildItem "$env:LOCALAPPDATA\Riot Games\RiotClient\Logs\Riot Client Logs", "$env:LOCALAPPDATA\Riot Games\Riot Client\Logs\Riot Client Logs" -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($lg) {
    A ("log: " + $lg.Name)
    Get-Content $lg.FullName | Select-String -Pattern 'repair|Repair|corrupt|missing|Missing|mismatch|Verification|FAIL|ERROR|denied|integrity|install at' |
        Select-Object -Last 22 | ForEach-Object { $l = $_.Line; if ($l.Length -gt 170) { $l = $l.Substring(0, 170) }; A ("  " + $l) }
} else { A 'no Riot Client log found' }

[IO.File]::WriteAllLines($out, $r)
Start-Process notepad.exe $out
