# Make-Brand.ps1 - turn a picture into the shop logo (round PNG) and the app icon (.ico).
#   Make-Brand.ps1 -Image <jpg/png> [-CenterX 0.53 -CenterY 0.58 -Radius 0.39]   (fractions of the picture size)
# Writes <GCafe>\data\brand\logo.png and app.ico. Then run tools\Build-App.bat so the .exe gets the icon.
param([Parameter(Mandatory = $true)][string]$Image, [double]$CenterX = 0.5, [double]$CenterY = 0.5, [double]$Radius = 0.48,
      [string]$Ring = '#f97316')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$gcafe = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir = Join-Path $gcafe 'data\brand'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
$src = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Image).Path)
$s = [Math]::Min($src.Width, $src.Height)
$cx = $src.Width * $CenterX; $cy = $src.Height * $CenterY; $r = $s * $Radius

function Round([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.CompositingQuality = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath; $path.AddEllipse(0, 0, $size - 1, $size - 1)
  $g.SetClip($path)
  $g.DrawImage($src, (New-Object System.Drawing.RectangleF 0, 0, $size, $size), (New-Object System.Drawing.RectangleF ($cx - $r), ($cy - $r), (2 * $r), (2 * $r)), 'Pixel')
  $g.ResetClip()
  if ($Ring) {
    $w = [Math]::Max(1.0, $size * 0.035)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($Ring)), $w
    $g.DrawEllipse($pen, $w / 2, $w / 2, $size - 1 - $w, $size - 1 - $w)
  }
  $g.Dispose(); $bmp
}
function PngBytes($bmp) { $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); , $ms.ToArray() }

$logo = Round 512; $logo.Save((Join-Path $dir 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
# .ico with PNG images (Windows Vista+)
$sizes = 256, 128, 64, 48, 32, 24, 16
$imgs = @(foreach ($z in $sizes) { , [byte[]](PngBytes (Round $z)) })
$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$off = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $z = $sizes[$i]; $b = if ($z -ge 256) { 0 } else { $z }
  $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$imgs[$i].Length); $w.Write([uint32]$off)
  $off += $imgs[$i].Length
}
foreach ($d in $imgs) { $w.Write([byte[]]$d) }
[IO.File]::WriteAllBytes((Join-Path $dir 'app.ico'), $ms.ToArray())
$src.Dispose()
"logo: $dir\logo.png"; "icon: $dir\app.ico"
