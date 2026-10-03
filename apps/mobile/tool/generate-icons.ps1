# Rasterize the same geometric W mark for native launcher icon sizes.
# No fonts or external image tools are required. Run from apps/mobile.
Add-Type -AssemblyName System.Drawing
$mobileRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$points = @(
    @(17, 25), @(28, 25), @(34, 62), @(43, 36), @(53, 36),
    @(62, 62), @(68, 25), @(79, 25), @(69, 77), @(58, 77),
    @(48, 51), @(38, 77), @(27, 77)
)
function Write-WagzIcon([string]$relativePath, [int]$size) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(23, 26, 23))
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::FromArgb(223, 255, 0))
        $scaled = [System.Drawing.PointF[]]@($points | ForEach-Object {
            [System.Drawing.PointF]::new([single]($_[0] * $size / 100), [single]($_[1] * $size / 100))
        })
        $graphics.FillPolygon($brush, $scaled)
        $graphics.FillEllipse($brush, [single]($size * .81), [single]($size * .2), [single]($size * .09), [single]($size * .09))
        $bitmap.Save((Join-Path $mobileRoot $relativePath), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $brush.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
@{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }.GetEnumerator() | ForEach-Object {
    Write-WagzIcon "android/app/src/main/res/mipmap-$($_.Key)/ic_launcher.png" $_.Value
}
$catalog = Get-Content -LiteralPath (Join-Path $mobileRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
$catalog.images | ForEach-Object {
    $size = [double]($_.size.Split('x')[0]) * [int]($_.scale.Replace('x', ''))
    Write-WagzIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($_.filename)" ([int]$size)
}
