# Online-Torrent.ps1 - bencode + .torrent files for the online library (dot-sourced by Online-Library.ps1 / Hub-Server.ps1).
#   ConvertTo-Bencode $obj -> byte[]     (int/long, string (UTF-8), byte[], array/list, hashtable/ordered dictionary)
#   ConvertFrom-Bencode byte[] -> object (strings come back as byte[]; Get-BStr turns one into text)
#   New-GameTorrent -Folder <game folder> -Announce <tracker url> -> @{ Bytes; InfoHash (hex); Size; Files; PieceLength }
#     BitTorrent v1, private (no DHT / peer exchange), name = the folder name, files in ordinal path order.

function ConvertTo-Bencode($obj) {
  $ms = New-Object IO.MemoryStream
  Write-Bencode $ms $obj
  , $ms.ToArray()
}
function Write-BBytes([IO.Stream]$ms, [byte[]]$b) { $h = [Text.Encoding]::ASCII.GetBytes("$($b.Length):"); $ms.Write($h, 0, $h.Length); if ($b.Length) { $ms.Write($b, 0, $b.Length) } }
function Write-Bencode([IO.Stream]$ms, $obj) {
  if ($obj -is [byte[]]) { Write-BBytes $ms $obj; return }
  if ($obj -is [string]) { Write-BBytes $ms ([Text.Encoding]::UTF8.GetBytes($obj)); return }
  if ($obj -is [int] -or $obj -is [long] -or $obj -is [int16] -or $obj -is [uint32] -or $obj -is [uint64] -or $obj -is [bool]) {
    $v = if ($obj -is [bool]) { [int]$obj } else { $obj }
    $b = [Text.Encoding]::ASCII.GetBytes("i$($v)e"); $ms.Write($b, 0, $b.Length); return
  }
  if ($obj -is [Collections.IDictionary]) {
    $ms.WriteByte([byte][char]'d')
    $keys = @($obj.Keys | ForEach-Object { [string]$_ })
    $sorted = $keys | Sort-Object -Property @{ e = { [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($_)) } }   # raw byte order
    foreach ($k in $sorted) { Write-BBytes $ms ([Text.Encoding]::UTF8.GetBytes($k)); Write-Bencode $ms $obj[$k] }
    $ms.WriteByte([byte][char]'e'); return
  }
  if ($obj -is [Collections.IEnumerable]) { $ms.WriteByte([byte][char]'l'); foreach ($x in $obj) { Write-Bencode $ms $x }; $ms.WriteByte([byte][char]'e'); return }
  throw "bencode: cannot encode $($obj.GetType().FullName)"
}

function ConvertFrom-Bencode([byte[]]$b) { $pos = [ref]0; Read-Bencode $b $pos }
function Read-Bencode([byte[]]$b, [ref]$pos) {
  $c = [char]$b[$pos.Value]
  if ($c -eq 'i') { $e = [Array]::IndexOf($b, [byte][char]'e', $pos.Value); $v = [int64][Text.Encoding]::ASCII.GetString($b, $pos.Value + 1, $e - $pos.Value - 1); $pos.Value = $e + 1; return $v }
  if ($c -eq 'l') { $pos.Value++; $l = New-Object System.Collections.Generic.List[object]; while ([char]$b[$pos.Value] -ne 'e') { $l.Add((Read-Bencode $b $pos)) }; $pos.Value++; return , $l.ToArray() }
  if ($c -eq 'd') {
    $pos.Value++; $d = [ordered]@{}
    while ([char]$b[$pos.Value] -ne 'e') { $k = [Text.Encoding]::UTF8.GetString((Read-Bencode $b $pos)); $d[$k] = Read-Bencode $b $pos }
    $pos.Value++; return $d
  }
  if ($c -match '\d') {
    $colon = [Array]::IndexOf($b, [byte][char]':', $pos.Value)
    $len = [int][Text.Encoding]::ASCII.GetString($b, $pos.Value, $colon - $pos.Value)
    $s = New-Object byte[] $len; [Array]::Copy($b, $colon + 1, $s, 0, $len); $pos.Value = $colon + 1 + $len
    return , $s
  }
  throw "bencode: bad byte at $($pos.Value)"
}
function Get-BStr($v) { if ($v -is [byte[]]) { [Text.Encoding]::UTF8.GetString($v) } else { "$v" } }

# info hash of a .torrent (SHA1 of the bencoded info dictionary, re-encoded = same bytes for canonical files)
function Get-TorrentInfoHash([byte[]]$torrent) {
  $t = ConvertFrom-Bencode $torrent
  $sha = [Security.Cryptography.SHA1]::Create()
  ([BitConverter]::ToString($sha.ComputeHash((ConvertTo-Bencode $t['info'])))).Replace('-', '').ToLower()
}

# the same torrent with another tracker (each branch announces to the hub address IT can reach). The info dictionary - and so
# the info hash - stays the same; if the re-encoded info would not hash to $InfoHash, the original bytes come back unchanged.
function Set-TorrentAnnounce([byte[]]$Torrent, [string]$Announce, [string]$InfoHash = '') {
  try {
    $t = ConvertFrom-Bencode $Torrent
    if ("$(Get-BStr $t['announce'])" -eq $Announce -and -not $t.Contains('announce-list')) { return , $Torrent }
    $n = [ordered]@{}; foreach ($k in $t.Keys) { if ($k -ne 'announce-list') { $n[$k] = $t[$k] } }
    $n['announce'] = $Announce
    $b = ConvertTo-Bencode $n
    $want = if ($InfoHash) { $InfoHash.ToLower() } else { Get-TorrentInfoHash $Torrent }
    if ((Get-TorrentInfoHash $b) -ne $want) { return , $Torrent }
    , $b
  } catch { , $Torrent }
}

function New-GameTorrent([string]$Folder, [string]$Announce, [int]$PieceLength = 0, [scriptblock]$Progress = $null) {
  $Folder = $Folder.TrimEnd('\')
  $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force -ErrorAction Stop | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
  $rel = @($files | ForEach-Object { [pscustomobject]@{ F = $_; R = $_.FullName.Substring($Folder.Length + 1) } } | Sort-Object -Property R -CaseSensitive)
  $total = [int64]0; foreach ($x in $rel) { $total += $x.F.Length }
  if ($total -le 0) { throw "no data in $Folder" }
  if (-not $PieceLength) {
    # ~1000-2000 pieces: 256 KB .. 16 MB
    $PieceLength = 256KB; while ($PieceLength -lt 16MB -and ($total / $PieceLength) -gt 2000) { $PieceLength *= 2 }
  }
  $sha = [Security.Cryptography.SHA1]::Create()
  $pieces = New-Object IO.MemoryStream
  $buf = New-Object byte[] $PieceLength
  $fill = 0; $done = [int64]0
  $readBuf = New-Object byte[] (1MB)
  foreach ($x in $rel) {
    $fs = [IO.File]::Open($x.F.FullName, 'Open', 'Read', 'ReadWrite')
    try {
      while ($true) {
        $want = [Math]::Min($readBuf.Length, $PieceLength - $fill)
        $n = $fs.Read($buf, $fill, $want)
        if ($n -le 0) { break }
        $fill += $n; $done += $n
        if ($fill -eq $PieceLength) { $h = $sha.ComputeHash($buf, 0, $fill); $pieces.Write($h, 0, 20); $fill = 0; if ($Progress) { & $Progress $done $total } }
      }
    } finally { $fs.Dispose() }
  }
  if ($fill -gt 0) { $h = $sha.ComputeHash($buf, 0, $fill); $pieces.Write($h, 0, 20) }
  $flist = New-Object System.Collections.Generic.List[object]
  foreach ($x in $rel) { $flist.Add([ordered]@{ length = [int64]$x.F.Length; path = @($x.R -split '\\') }) }
  $info = [ordered]@{ files = $flist.ToArray(); name = (Split-Path -Leaf $Folder); 'piece length' = [int64]$PieceLength; pieces = $pieces.ToArray(); private = 1 }
  $t = [ordered]@{ announce = $Announce; 'created by' = 'OSYNC online library'; 'creation date' = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); info = $info }
  $bytes = ConvertTo-Bencode $t
  $ih = ([BitConverter]::ToString($sha.ComputeHash((ConvertTo-Bencode $info)))).Replace('-', '').ToLower()
  @{ Bytes = $bytes; InfoHash = $ih; Size = $total; Files = $rel.Count; PieceLength = $PieceLength; Name = $info.name }
}

# check a downloaded folder against a .torrent (every piece SHA1) -> @{ ok; bad (pieces); missing (files) }
function Test-TorrentData([byte[]]$Torrent, [string]$Folder) {
  $t = ConvertFrom-Bencode $Torrent
  $info = $t['info']; $pl = [int64]$info['piece length']; $pieces = [byte[]]$info['pieces']
  $sha = [Security.Cryptography.SHA1]::Create()
  $buf = New-Object byte[] $pl; $fill = 0; $idx = 0; $bad = 0; $missing = @()
  foreach ($f in $info['files']) {
    $path = Join-Path $Folder ((@($f['path'] | ForEach-Object { Get-BStr $_ })) -join '\')
    $len = [int64]$f['length']
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -ne $len) { $missing += $path; $stream = $null } else { $stream = [IO.File]::OpenRead($path) }
    try {
      $left = $len
      while ($left -gt 0) {
        $want = [int][Math]::Min($pl - $fill, $left)
        if ($stream) { $n = $stream.Read($buf, $fill, $want) } else { [Array]::Clear($buf, $fill, $want); $n = $want }
        if ($n -le 0) { break }
        $fill += $n; $left -= $n
        if ($fill -eq $pl) { $h = $sha.ComputeHash($buf, 0, $fill); for ($k = 0; $k -lt 20; $k++) { if ($h[$k] -ne $pieces[$idx * 20 + $k]) { $bad++; break } }; $idx++; $fill = 0 }
      }
    } finally { if ($stream) { $stream.Dispose() } }
  }
  if ($fill -gt 0) { $h = $sha.ComputeHash($buf, 0, $fill); for ($k = 0; $k -lt 20; $k++) { if ($h[$k] -ne $pieces[$idx * 20 + $k]) { $bad++; break } }; $idx++ }
  @{ ok = ($bad -eq 0 -and $missing.Count -eq 0 -and $idx * 20 -eq $pieces.Length); bad = $bad; missing = $missing; pieces = $idx }
}
