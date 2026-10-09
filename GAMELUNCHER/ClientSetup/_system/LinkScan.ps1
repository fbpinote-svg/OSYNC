# LinkScan.ps1 - run on a CLIENT. Lists folder links (junctions/symlinks) in the usual launcher
# locations and flags the ones whose target no longer exists (e.g. pointed into J:\AutoSync).
$out = Join-Path $env:TEMP 'LinkScan.txt'
$r = New-Object System.Collections.Generic.List[string]
$r.Add("LinkScan  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "  PC=" + $env:COMPUTERNAME + "  user=" + $env:USERNAME)
$roots = @(
    @('C:\', 1), @($env:ProgramData, 2), @('C:\Program Files', 2), @('C:\Program Files (x86)', 2),
    @($env:LOCALAPPDATA, 2), @($env:APPDATA, 2), @("$env:USERPROFILE\Documents", 2), @('C:\Riot Games', 2))
$broken = 0; $ok = 0
foreach ($rt in $roots) {
    $base = $rt[0]; $depth = $rt[1]
    if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
    $items = Get-ChildItem -LiteralPath $base -Directory -Force -Recurse -Depth ($depth - 1) -ErrorAction SilentlyContinue -Attributes ReparsePoint
    foreach ($i in $items) {
        if ($i.FullName -match '\\(Application Data|Local Settings|My Documents|NetHood|PrintHood|Recent|SendTo|Start Menu|Templates|Cookies|My Music|My Pictures|My Videos|History|Temporary Internet Files|Desktop|Documents|Favorites|Documents and Settings|All Users|Default User)$') { continue }   # Windows compatibility links
        $t = ($i.Target -join '')
        if (-not $t) { continue }
        $exists = $t -and (Test-Path -LiteralPath $t)
        if ($exists) { $ok++ } else { $broken++ }
        $r.Add(("{0}  {1}  ->  {2}" -f $(if ($exists) { 'ok    ' } else { 'BROKEN' }), $i.FullName, $t))
    }
}
$r.Insert(1, "broken links: $broken   working links: $ok")
[IO.File]::WriteAllLines($out, $r)
Start-Process notepad.exe $out
