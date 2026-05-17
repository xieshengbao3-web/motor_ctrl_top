
param(
  [string]$MetaPath
)
Add-Type -AssemblyName System.Drawing

function New-FontObj($name, $size, $style = [System.Drawing.FontStyle]::Regular) {
  return New-Object System.Drawing.Font($name, $size, $style)
}

function Draw-Box($g, $x, $y, $w, $h, $text, $fillColor) {
  $rect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
  $fill = New-Object System.Drawing.SolidBrush($fillColor)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,90,120), 2)
  $g.FillRectangle($fill, $rect)
  $g.DrawRectangle($pen, $x, $y, $w, $h)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $font = New-FontObj 'Microsoft YaHei' 12 ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30,30,30))
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $brush.Dispose(); $font.Dispose(); $fmt.Dispose(); $pen.Dispose(); $fill.Dispose()
}

function Draw-Arrow($g, $x1, $y1, $x2, $y2) {
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,95,120), 2)
  $pen.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(5, 5, $true)
  $g.DrawLine($pen, $x1, $y1, $x2, $y2)
  $pen.Dispose()
}

function Add-Title($g, $text, $w) {
  $font = New-FontObj 'Microsoft YaHei' 18 ([System.Drawing.FontStyle]::Bold)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25,25,25))
  $rect = New-Object System.Drawing.RectangleF(20, 12, ($w-40), 34)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Near
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $brush.Dispose(); $font.Dispose(); $fmt.Dispose()
}

function New-Canvas($w, $h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::FromArgb(248,250,252))
  return @($bmp, $g)
}

function Save-Canvas($bmp, $g, $path) {
  $dir = Split-Path -Parent $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
}

function Render-Overview($path) {
  $pair = New-Canvas 1800 1100
  $bmp = $pair[0]; $g = $pair[1]
  Add-Title $g 'FPGA Project Module Diagram' 1800
  Draw-Box $g 700 70 360 90 'fpga_top' ([System.Drawing.Color]::FromArgb(215,232,255))

  Draw-Box $g 120 260 280 90 'clk_rst_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 470 260 280 90 'rgmii_rx_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 820 260 280 90 'rgmii_tx_top' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 1170 260 280 90 'abz_decoder' ([System.Drawing.Color]::FromArgb(227,242,253))
  Draw-Box $g 1520 260 180 90 'sixstep_vf_lut' ([System.Drawing.Color]::FromArgb(227,242,253))

  Draw-Arrow $g 880 160 260 260
  Draw-Arrow $g 880 160 610 260
  Draw-Arrow $g 880 160 960 260
  Draw-Arrow $g 880 160 1310 260
  Draw-Arrow $g 880 160 1610 260

  Draw-Box $g 420 500 280 90 'scp0_comm' ([System.Drawing.Color]::FromArgb(255,243,224))
  Draw-Box $g 1030 500 300 90 'sam_data0_buf' ([System.Drawing.Color]::FromArgb(255,243,224))

  Draw-Arrow $g 610 350 560 500
  Draw-Arrow $g 960 350 1180 500
  Draw-Arrow $g 1310 350 1180 500
  Draw-Arrow $g 560 590 610 350

  $font = New-FontObj 'Microsoft YaHei' 12
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55,55,55))
  $g.DrawString('UDP read/write cmd', $font, $brush, 540, 410)
  $g.DrawString('register reply', $font, $brush, 700, 410)
  $g.DrawString('speed/sample data', $font, $brush, 1210, 410)
  $g.DrawString('buffered sample upload by UDP', $font, $brush, 1040, 620)
  $g.DrawString('6-channel gate drive', $font, $brush, 1535, 370)
  $brush.Dispose(); $font.Dispose()

  Draw-Box $g 190 760 280 80 'RGMII / ARP / IP / UDP / ICMP' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 560 760 280 80 'ABZ / Hall / speed calc' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 930 760 280 80 'dual-port RAM / CDC buf' ([System.Drawing.Color]::FromArgb(237,247,237))
  Draw-Box $g 1300 760 280 80 'six-step / PWM gating' ([System.Drawing.Color]::FromArgb(237,247,237))

  Save-Canvas $bmp $g $path
}

function Render-Module($item) {
  $pair = New-Canvas 1400 900
  $bmp = $pair[0]; $g = $pair[1]
  Add-Title $g ($item.name + ' module diagram') 1400

  Draw-Box $g 500 130 400 110 $item.name ([System.Drawing.Color]::FromArgb(215,232,255))

  if ($item.parents.Count -gt 0) {
    Draw-Box $g 80 160 260 80 'parent modules' ([System.Drawing.Color]::FromArgb(255,243,224))
    Draw-Arrow $g 340 200 500 185
    $font = New-FontObj 'Microsoft YaHei' 11
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,45,45))
    $y = 270
    foreach ($p in $item.parents) {
      $g.DrawString($p, $font, $brush, 95, $y)
      $y += 28
    }
    $brush.Dispose(); $font.Dispose()
  }

  if ($item.children.Count -gt 0) {
    $count = $item.children.Count
    $startX = 80
    $gap = [Math]::Floor((1240 - ($count * 180)) / ([Math]::Max(1, ($count - 1))))
    if ($count -eq 1) { $startX = 610; $gap = 0 }
    for ($i = 0; $i -lt $count; $i++) {
      $x = $startX + $i * (180 + $gap)
      Draw-Box $g $x 520 180 80 $item.children[$i] ([System.Drawing.Color]::FromArgb(227,242,253))
      Draw-Arrow $g 700 240 ($x + 90) 520
    }
    $font = New-FontObj 'Microsoft YaHei' 12
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50,50,50))
    $g.DrawString('child modules', $font, $brush, 630, 455)
    $brush.Dispose(); $font.Dispose()
  } else {
    Draw-Box $g 450 520 500 90 'no child modules instantiated' ([System.Drawing.Color]::FromArgb(237,247,237))
    Draw-Arrow $g 700 240 700 520
  }

  Save-Canvas $bmp $g $item.path
}

$meta = Get-Content $MetaPath -Raw | ConvertFrom-Json
foreach ($item in $meta.items) {
  if ($item.kind -eq 'overview') { Render-Overview $item.path }
  else { Render-Module $item }
}
