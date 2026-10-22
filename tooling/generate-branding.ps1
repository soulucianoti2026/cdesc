$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent

function Save-BrandImage([string]$RelativePath, [int]$Width, [int]$Height, [bool]$Symbol = $true) {
    $target = Join-Path $projectRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Width, $Height)
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, [System.Drawing.Color]::White, [System.Drawing.Color]::White, 45.0)
    $blend = [System.Drawing.Drawing2D.ColorBlend]::new(5)
    $blend.Colors = @('#087443', '#68B58A', '#FFFFFF', '#F5C7CB', '#CE3045') | ForEach-Object { [System.Drawing.ColorTranslator]::FromHtml($_) }
    $blend.Positions = [single[]]@(0, .28, .53, .76, 1)
    $brush.InterpolationColors = $blend
    $graphics.FillRectangle($brush, $rect)
    if ($Symbol) {
        $scale = [single]([Math]::Min($Width, $Height) / 1024)
        $graphics.TranslateTransform(($Width - 1024 * $scale) / 2, ($Height - 1024 * $scale) / 2)
        $graphics.ScaleTransform($scale, $scale)
        $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $green = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#087443'), 36)
        $green.StartCap = 'Round'; $green.EndCap = 'Round'; $green.LineJoin = 'Round'
        $graphics.FillEllipse($white, 202, 202, 620, 620)
        $graphics.DrawRectangle($green, 342, 482, 340, 192)
        $graphics.DrawLine($green, 342, 482, 397, 424)
        $graphics.DrawLine($green, 682, 482, 627, 424)
        $graphics.DrawLine($green, 397, 424, 627, 424)
        $graphics.FillRectangle($white, 432, 334, 160, 138)
        $graphics.DrawLine($green, 450, 370, 498, 411)
        $graphics.DrawLine($green, 498, 411, 579, 321)
        $red = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#CE3045'), 22)
        $red.StartCap = 'Round'; $red.EndCap = 'Round'
        $graphics.DrawLine($red, 465, 580, 559, 580)
        $red.Dispose(); $green.Dispose(); $white.Dispose()
    }
    $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}

Save-BrandImage 'assets/branding/app_icon.png' 1024 1024
Save-BrandImage 'assets/branding/splash_background.png' 1080 1920 $false
$densities = @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}
foreach ($density in $densities.Keys) {
    Save-BrandImage "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density] $densities[$density]
}
$catalog = Get-Content (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($entry in $catalog.images) {
    $size = [int]([double]($entry.size -split 'x')[0] * [double]($entry.scale -replace 'x', ''))
    Save-BrandImage "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" $size $size
}
foreach ($scale in 1..3) {
    $suffix = if ($scale -eq 1) { '' } else { "@${scale}x" }
    Save-BrandImage "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png" (144 * $scale) (144 * $scale)
}
$backgroundSet = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/SplashBackground.imageset'
[System.IO.Directory]::CreateDirectory($backgroundSet) | Out-Null
Copy-Item (Join-Path $projectRoot 'assets/branding/splash_background.png') (Join-Path $backgroundSet 'background.png')
'{"images":[{"filename":"background.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}' | Set-Content (Join-Path $backgroundSet 'Contents.json')
