# Claude Hub Icon Generator
# Usage: powershell -ExecutionPolicy Bypass -File tools/gen-ico.ps1 [outputPath]
# Default output: ..\claude-hub.ico

param(
    [string]$OutputPath = "$PSScriptRoot\..\claude-hub.ico"
)

Add-Type -AssemblyName System.Drawing -ErrorAction Stop

function MakePng($sz) {
    $bmp = [System.Drawing.Bitmap]::new($sz, $sz)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'HighQuality'

    # Dark rounded square background
    $bg = [System.Drawing.Color]::FromArgb(255, 22, 22, 24)
    $corner = $sz * 0.22
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc(0, 0, $corner, $corner, 180, 90)
    $path.AddArc($sz-$corner, 0, $corner, $corner, 270, 90)
    $path.AddArc($sz-$corner, $sz-$corner, $corner, $corner, 0, 90)
    $path.AddArc(0, $sz-$corner, $corner, $corner, 90, 90)
    $path.CloseFigure()
    $g.FillPath([System.Drawing.SolidBrush]::new($bg), $path)
    $path.Dispose()

    $cx = $sz / 2.0; $cy = $sz / 2.0
    $r = $sz * 0.28
    $ir = $r * 0.42

    # Claude-style 4-point star
    $pts = @()
    for ($i = 0; $i -lt 8; $i++) {
        $a = -[Math]::PI/2 + $i * [Math]::PI/4
        $radius = if ($i % 2 -eq 0) { $r } else { $ir }
        $pts += [System.Drawing.PointF]::new($cx + $radius*[Math]::Cos($a), $cy + $radius*[Math]::Sin($a))
    }

    $orange = [System.Drawing.Color]::FromArgb(255, 217, 119, 6)
    $g.FillPolygon([System.Drawing.SolidBrush]::new($orange), $pts)

    $g.Dispose()

    $ms = [System.IO.MemoryStream]::new()
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    $ms.Close(); $bmp.Dispose()
    return ,$bytes
}

Write-Host "Generating Claude Hub icon..." -ForegroundColor Cyan

$pngList = [System.Collections.ArrayList]::new()
foreach ($sz in @(32, 48, 256)) {
    Write-Host "  Rendering ${sz}x${sz}..." -ForegroundColor Gray
    [void]$pngList.Add((MakePng $sz))
}

$ms = [System.IO.MemoryStream]::new()
$bw = [System.IO.BinaryWriter]::new($ms)

# ICO header
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$pngList.Count)

# ICO directory entries
$off = 6 + 16 * $pngList.Count
$offsets = @()
foreach ($p in $pngList) { $offsets += $off; $off += $p.Length }

$szs = @(32, 48, 256)
for ($i = 0; $i -lt $pngList.Count; $i++) {
    $p = $pngList[$i]; $s = $szs[$i]
    $bw.Write([Byte]$(if ($s -ge 256) { 0 } else { $s }))
    $bw.Write([Byte]$(if ($s -ge 256) { 0 } else { $s }))
    $bw.Write([Byte]0)
    $bw.Write([Byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$p.Length)
    $bw.Write([UInt32]$offsets[$i])
}

# PNG image data
foreach ($p in $pngList) { $bw.Write($p) }

$bw.Flush()
[System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())
$bw.Close(); $ms.Close()

Write-Host "[OK] Icon saved to: $OutputPath" -ForegroundColor Green
