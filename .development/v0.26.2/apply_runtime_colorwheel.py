#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_text(path: Path) -> str:
    return path.read_text(encoding='utf-8-sig')


def write_ps(path: Path, text: str) -> None:
    path.write_text(text, encoding='utf-8-sig', newline='\n')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Game Bar ownership: main shell Guide => Quick Access; any other Huymaier
# foreground HWND/window => Game Bar. External foreground remains Game Bar.
# ---------------------------------------------------------------------------
gamebar_path = ROOT / 'HuymaierGameBar.ps1'
gamebar = read_text(gamebar_path)
gamebar = gamebar.replace(
    '# Huymaier Console v0.26.1 external game/app overlay and process-wide Guide arbiter.',
    '# Huymaier Console v0.26.2 external/native-surface overlay and process-wide Guide arbiter.',
    1,
)
old_owner = """                # Win32 foreground HWND ownership is authoritative. WPF IsActive
                # can be false while an owned/native Huymaier interface is active.
                if(Test-HcForegroundOwnedByConsole){
                    if($guideEdge){Invoke-HcInternalGuide -ActiveWindow (Get-HcActiveConsoleWindow)}
                    return
                }

                # An external process owns foreground focus. Only Guide/Home may
                # wake the Huymaier Game Bar; all other controller input remains
                # entirely with the foreground game/application.
                if($guideEdge){
                    [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                    Write-Log 'Huymaier Game Bar opened over the foreground game/app.'
                }
"""
new_owner = """                # Win32 foreground process ownership is authoritative, but the main
                # shell and Huymaier-native console surfaces intentionally have different
                # Guide behavior. Main shell => Quick Access. PS3/PS2/PS1/Original Xbox/
                # Xbox 360/etc. modal/native surface => Game Bar above that surface.
                if(Test-HcForegroundOwnedByConsole){
                    if($guideEdge){
                        $activeWindow=Get-HcActiveConsoleWindow
                        $mainShellActive=$false
                        try{
                            $mainShellActive=($null -ne $activeWindow -and $null -ne $script:Window -and [object]::ReferenceEquals($activeWindow,$script:Window)) -or [bool]$script:Window.IsActive
                        }catch{}
                        if($mainShellActive){
                            Invoke-HcInternalGuide -ActiveWindow $script:Window
                        }else{
                            [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                            Write-Log 'Huymaier Game Bar opened over a Huymaier-native console surface.'
                        }
                    }
                    return
                }

                # An external process owns foreground focus. Only Guide/Home may
                # wake the Huymaier Game Bar; all other controller input remains
                # entirely with the foreground game/application.
                if($guideEdge){
                    [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                    Write-Log 'Huymaier Game Bar opened over the foreground game/app.'
                }
"""
gamebar = replace_once(gamebar, old_owner, new_owner, 'Game Bar foreground ownership block')
write_ps(gamebar_path, gamebar)


# ---------------------------------------------------------------------------
# Controller-first visual color wheel module. Hex remains read-only reference;
# no typing is required. D-pad moves the selector, LB/RB changes brightness,
# A applies, B cancels, X/Y cycle quick swatches.
# ---------------------------------------------------------------------------
color_picker = r'''# Huymaier Console v0.26.2 controller-first visual color picker.
# Normal use requires no text/hex entry. The displayed hex value is reference-only.

$script:HcColorPickerWindow=$null
$script:HcColorPickerTimer=$null
$script:HcColorPickerField=''
$script:HcColorPickerVectorX=0.0
$script:HcColorPickerVectorY=0.0
$script:HcColorPickerValue=1.0
$script:HcColorPickerApplied=$false

function Convert-HcHsvToHex {
    param([double]$Hue,[double]$Saturation,[double]$Value)
    $h=(($Hue%360.0)+360.0)%360.0
    $s=[math]::Max(0.0,[math]::Min(1.0,$Saturation))
    $v=[math]::Max(0.0,[math]::Min(1.0,$Value))
    $c=$v*$s
    $sector=$h/60.0
    $x=$c*(1.0-[math]::Abs(($sector%2.0)-1.0))
    $r=0.0;$g=0.0;$b=0.0
    if($sector -lt 1){$r=$c;$g=$x}
    elseif($sector -lt 2){$r=$x;$g=$c}
    elseif($sector -lt 3){$g=$c;$b=$x}
    elseif($sector -lt 4){$g=$x;$b=$c}
    elseif($sector -lt 5){$r=$x;$b=$c}
    else{$r=$c;$b=$x}
    $m=$v-$c
    $ri=[int][math]::Round(($r+$m)*255.0)
    $gi=[int][math]::Round(($g+$m)*255.0)
    $bi=[int][math]::Round(($b+$m)*255.0)
    return ('#{0:X2}{1:X2}{2:X2}' -f $ri,$gi,$bi)
}

function Convert-HcHexToHsv {
    param([string]$Color)
    try{$c=[System.Windows.Media.ColorConverter]::ConvertFromString($Color)}catch{$c=[System.Windows.Media.ColorConverter]::ConvertFromString('#E7C45E')}
    $r=$c.R/255.0;$g=$c.G/255.0;$b=$c.B/255.0
    $max=[math]::Max($r,[math]::Max($g,$b));$min=[math]::Min($r,[math]::Min($g,$b));$d=$max-$min
    $h=0.0
    if($d -gt 0.000001){
        if($max -eq $r){$h=60.0*((($g-$b)/$d)%6.0)}
        elseif($max -eq $g){$h=60.0*((($b-$r)/$d)+2.0)}
        else{$h=60.0*((($r-$g)/$d)+4.0)}
    }
    if($h -lt 0){$h+=360.0}
    $s=$(if($max -le 0.000001){0.0}else{$d/$max})
    return [pscustomobject]@{Hue=$h;Saturation=$s;Value=$max}
}

function Get-HcColorPickerHex {
    $sat=[math]::Min(1.0,[math]::Sqrt(($script:HcColorPickerVectorX*$script:HcColorPickerVectorX)+($script:HcColorPickerVectorY*$script:HcColorPickerVectorY)))
    $hue=([math]::Atan2($script:HcColorPickerVectorY,$script:HcColorPickerVectorX)*180.0/[math]::PI)
    if($hue -lt 0){$hue+=360.0}
    return Convert-HcHsvToHex $hue $sat $script:HcColorPickerValue
}

function Set-HcColorPickerVectorFromHex {
    param([string]$Color)
    $hsv=Convert-HcHexToHsv $Color
    $rad=[double]$hsv.Hue*[math]::PI/180.0
    $script:HcColorPickerVectorX=[math]::Cos($rad)*[double]$hsv.Saturation
    $script:HcColorPickerVectorY=[math]::Sin($rad)*[double]$hsv.Saturation
    $script:HcColorPickerValue=[double]$hsv.Value
}

function Move-HcColorPickerVector {
    param([double]$Dx,[double]$Dy)
    $x=$script:HcColorPickerVectorX+$Dx;$y=$script:HcColorPickerVectorY+$Dy
    $len=[math]::Sqrt(($x*$x)+($y*$y))
    if($len -gt 1.0){$x/=$len;$y/=$len}
    $script:HcColorPickerVectorX=$x;$script:HcColorPickerVectorY=$y
}

function New-HcColorWheelCanvas {
    param([double]$Size)
    $canvas=New-Object System.Windows.Controls.Canvas
    $canvas.Width=$Size;$canvas.Height=$Size
    $radius=$Size/2.0;$cx=$radius;$cy=$radius
    for($i=0;$i -lt 72;$i++){
        $a1=($i*5.0-0.4)*[math]::PI/180.0;$a2=(($i+1)*5.0+0.4)*[math]::PI/180.0
        $hue=$i*5.0+2.5
        $poly=New-Object System.Windows.Shapes.Polygon
        $points=New-Object System.Windows.Media.PointCollection
        $points.Add((New-Object System.Windows.Point -ArgumentList $cx,$cy))
        $points.Add((New-Object System.Windows.Point -ArgumentList ($cx+[math]::Cos($a1)*$radius),($cy+[math]::Sin($a1)*$radius)))
        $points.Add((New-Object System.Windows.Point -ArgumentList ($cx+[math]::Cos($a2)*$radius),($cy+[math]::Sin($a2)*$radius)))
        $poly.Points=$points
        $poly.Fill=New-HcSolidBrush (Convert-HcHsvToHex $hue 1.0 1.0)
        $poly.IsHitTestVisible=$false
        $canvas.Children.Add($poly)|Out-Null
    }
    $satOverlay=New-Object System.Windows.Shapes.Ellipse
    $satOverlay.Width=$Size;$satOverlay.Height=$Size;$satOverlay.IsHitTestVisible=$false
    $satBrush=New-Object System.Windows.Media.RadialGradientBrush
    $satBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(255,255,255,255)),0.0))
    $satBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0,255,255,255)),1.0))
    $satOverlay.Fill=$satBrush;$canvas.Children.Add($satOverlay)|Out-Null
    $shade=New-Object System.Windows.Shapes.Ellipse
    $shade.Name='ValueShade';$shade.Width=$Size;$shade.Height=$Size;$shade.Fill='Black';$shade.IsHitTestVisible=$false
    $canvas.Children.Add($shade)|Out-Null
    $marker=New-Object System.Windows.Shapes.Ellipse
    $marker.Name='ColorMarker';$marker.Width=22;$marker.Height=22;$marker.Fill='#20000000';$marker.Stroke='White';$marker.StrokeThickness=3;$marker.IsHitTestVisible=$false
    $canvas.Children.Add($marker)|Out-Null
    return [pscustomobject]@{Canvas=$canvas;Marker=$marker;Shade=$shade;Radius=$radius}
}

function Update-HcColorPickerVisuals {
    param($Wheel,$Preview,$HexText,$BrightnessText)
    try{
        $r=[double]$Wheel.Radius
        $px=$r+($script:HcColorPickerVectorX*$r)-($Wheel.Marker.Width/2.0)
        $py=$r+($script:HcColorPickerVectorY*$r)-($Wheel.Marker.Height/2.0)
        [System.Windows.Controls.Canvas]::SetLeft($Wheel.Marker,$px)
        [System.Windows.Controls.Canvas]::SetTop($Wheel.Marker,$py)
        $Wheel.Shade.Opacity=1.0-$script:HcColorPickerValue
        $hex=Get-HcColorPickerHex
        $Preview.Background=New-HcSolidBrush $hex
        $HexText.Text="HEX  $hex  (reference)"
        $BrightnessText.Text=('Brightness  {0}%' -f [int][math]::Round($script:HcColorPickerValue*100.0))
    }catch{}
}

function Show-HcColorPicker {
    param([string]$Field,[string]$Title,[string]$InitialColor)
    if($script:HcColorPickerWindow){return}
    if(-not(Test-HcHexColor $InitialColor)){$InitialColor='#E7C45E'}
    Set-HcColorPickerVectorFromHex $InitialColor
    $script:HcColorPickerField=$Field;$script:HcColorPickerApplied=$false

    $window=New-Object System.Windows.Window
    $script:HcColorPickerWindow=$window
    $window.Title="$Title - $(Get-HcConsoleName)"
    $window.Width=930;$window.Height=650;$window.ResizeMode='NoResize';$window.WindowStyle='None'
    $window.Background='#FF0B111B';$window.ShowInTaskbar=$false;$window.Topmost=$true
    if($null -ne $script:Window -and $script:Window.IsLoaded){$window.Owner=$script:Window;$window.WindowStartupLocation='CenterOwner'}else{$window.WindowStartupLocation='CenterScreen'}

    $root=New-Object System.Windows.Controls.Grid;$root.Margin='28'
    $root.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='430'}))
    $root.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))
    $root.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $root.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $root.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))

    $header=New-Object System.Windows.Controls.StackPanel;$header.Margin='0,0,0,18';[System.Windows.Controls.Grid]::SetColumnSpan($header,2)
    $h1=New-Object System.Windows.Controls.TextBlock;$h1.Text=$Title;$h1.FontSize=31;$h1.FontWeight='Bold';$h1.Foreground='White';$header.Children.Add($h1)|Out-Null
    $h2=New-Object System.Windows.Controls.TextBlock;$h2.Text='Move around the wheel with the D-pad or left stick. No color code typing required.';$h2.FontSize=14;$h2.Foreground='#AFC0D6';$h2.Margin='0,6,0,0';$header.Children.Add($h2)|Out-Null
    $root.Children.Add($header)|Out-Null

    $wheel=New-HcColorWheelCanvas 390
    $wheelBorder=New-Object System.Windows.Controls.Border;$wheelBorder.Width=402;$wheelBorder.Height=402;$wheelBorder.CornerRadius=201;$wheelBorder.BorderBrush=(New-HcSolidBrush (Get-HcAccentColor));$wheelBorder.BorderThickness=3;$wheelBorder.Child=$wheel.Canvas;$wheelBorder.HorizontalAlignment='Left';$wheelBorder.VerticalAlignment='Center';[System.Windows.Controls.Grid]::SetRow($wheelBorder,1)
    $root.Children.Add($wheelBorder)|Out-Null

    $side=New-Object System.Windows.Controls.StackPanel;$side.Margin='28,18,0,0';[System.Windows.Controls.Grid]::SetColumn($side,1);[System.Windows.Controls.Grid]::SetRow($side,1)
    $preview=New-Object System.Windows.Controls.Border;$preview.Height=126;$preview.CornerRadius=18;$preview.BorderBrush='#70FFFFFF';$preview.BorderThickness=2;$preview.Margin='0,0,0,20';$side.Children.Add($preview)|Out-Null
    $brightness=New-Object System.Windows.Controls.TextBlock;$brightness.FontSize=22;$brightness.FontWeight='SemiBold';$brightness.Foreground='White';$brightness.Margin='0,0,0,8';$side.Children.Add($brightness)|Out-Null
    $brightnessHint=New-Object System.Windows.Controls.TextBlock;$brightnessHint.Text='LB / RB   Decrease / increase brightness';$brightnessHint.FontSize=14;$brightnessHint.Foreground='#AFC0D6';$brightnessHint.Margin='0,0,0,18';$side.Children.Add($brightnessHint)|Out-Null
    $hex=New-Object System.Windows.Controls.TextBlock;$hex.FontSize=16;$hex.FontFamily='Consolas';$hex.Foreground='#D7E0EC';$hex.Margin='0,0,0,24';$side.Children.Add($hex)|Out-Null
    $swatchTitle=New-Object System.Windows.Controls.TextBlock;$swatchTitle.Text='Quick swatches';$swatchTitle.FontSize=17;$swatchTitle.FontWeight='SemiBold';$swatchTitle.Foreground='White';$side.Children.Add($swatchTitle)|Out-Null
    $swatchHint=New-Object System.Windows.Controls.TextBlock;$swatchHint.Text='X / Y   Previous / next';$swatchHint.FontSize=13;$swatchHint.Foreground='#AFC0D6';$swatchHint.Margin='0,5,0,0';$side.Children.Add($swatchHint)|Out-Null
    $root.Children.Add($side)|Out-Null

    $footer=New-Object System.Windows.Controls.TextBlock;$footer.Text='D-PAD / LEFT STICK  Move      LB / RB  Brightness      A / ENTER  Apply      B / ESC  Cancel';$footer.FontSize=14;$footer.FontWeight='SemiBold';$footer.Foreground='#F0F4FA';$footer.Margin='0,18,0,0';[System.Windows.Controls.Grid]::SetRow($footer,2);[System.Windows.Controls.Grid]::SetColumnSpan($footer,2);$root.Children.Add($footer)|Out-Null
    $window.Content=$root

    $swatches=@('#E7C45E','#FFFFFF','#72D54A','#55B5FF','#8A4FFF','#D06BFF','#FF7A59','#E53E3E','#52E5FF','#00C2D8','#FFB84D','#F45B9C')
    $swatchIndex=0
    for($i=0;$i -lt $swatches.Count;$i++){if([string]::Equals($swatches[$i],$InitialColor,[StringComparison]::OrdinalIgnoreCase)){$swatchIndex=$i;break}}

    $refresh={Update-HcColorPickerVisuals $wheel $preview $hex $brightness}
    & $refresh
    $apply={
        $chosen=Get-HcColorPickerHex
        $script:Config.$Field=$chosen
        $script:Config.DynamicThemePreset='Custom'
        Save-Config
        Apply-HcCustomizationVisuals
        $script:HcColorPickerApplied=$true
        $window.Close()
    }
    $cancel={$window.Close()}
    $jumpSwatch={param([int]$delta)
        $swatchIndex=($swatchIndex+$delta+$swatches.Count)%$swatches.Count
        Set-HcColorPickerVectorFromHex $swatches[$swatchIndex]
        & $refresh
    }
    $commandHandler={param([string]$command)
        switch($command){
            'Left' {Move-HcColorPickerVector -0.065 0;& $refresh}
            'Right' {Move-HcColorPickerVector 0.065 0;& $refresh}
            'Up' {Move-HcColorPickerVector 0 -0.065;& $refresh}
            'Down' {Move-HcColorPickerVector 0 0.065;& $refresh}
            'LeftShoulder' {$script:HcColorPickerValue=[math]::Max(0.05,$script:HcColorPickerValue-0.05);& $refresh}
            'RightShoulder' {$script:HcColorPickerValue=[math]::Min(1.0,$script:HcColorPickerValue+0.05);& $refresh}
            'Secondary' {& $jumpSwatch -1}
            'Tertiary' {& $jumpSwatch 1}
            'Confirm' {& $apply}
            'Back' {& $cancel}
        }
    }

    $window.Add_KeyDown({param($sender,$e)
        switch($e.Key){
            'Left' {& $commandHandler 'Left';$e.Handled=$true}
            'Right' {& $commandHandler 'Right';$e.Handled=$true}
            'Up' {& $commandHandler 'Up';$e.Handled=$true}
            'Down' {& $commandHandler 'Down';$e.Handled=$true}
            'PageDown' {& $commandHandler 'LeftShoulder';$e.Handled=$true}
            'PageUp' {& $commandHandler 'RightShoulder';$e.Handled=$true}
            'Enter' {& $commandHandler 'Confirm';$e.Handled=$true}
            'Escape' {& $commandHandler 'Back';$e.Handled=$true}
        }
    })

    try{[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}catch{}
    $timer=New-Object System.Windows.Threading.DispatcherTimer
    $script:HcColorPickerTimer=$timer;$timer.Interval=[TimeSpan]::FromMilliseconds(28)
    $timer.Add_Tick({
        try{
            if(-not $window.IsVisible){return}
            $native=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()
            $cmd=[string]$native.Command
            if($cmd){& $commandHandler $cmd}
        }catch{}
    })
    $timer.Start()
    try{[void]$window.ShowDialog()}finally{
        try{$timer.Stop()}catch{};$script:HcColorPickerTimer=$null;$script:HcColorPickerWindow=$null
        try{[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}catch{}
        if($script:HcColorPickerApplied){Render-Page;Update-NavVisuals}
    }
}
'''
write_ps(ROOT / 'HuymaierColorPicker.ps1', color_picker)


# ---------------------------------------------------------------------------
# Customization page: color actions open the visual wheel. Hex values no longer
# appear as the primary control; they remain visible inside the picker only.
# ---------------------------------------------------------------------------
custom_path = ROOT / 'HuymaierCustomization.ps1'
custom = read_text(custom_path)
custom = replace_once(
    custom,
    'HeroText="Accent: $(Get-HcAccentColor)  |  Dynamic palette: $preset";',
    'HeroText="Color preset: $preset  |  Controller color wheel available";',
    'Customization hero color text',
)
replacements = {
    '(New-Action \'customization-shell-base\' "Interface base: $(Get-HcColor \'ShellBaseColor\' \'#09111E\')" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-shell-base\' \'Interface base color\' \'Open the controller color wheel.\')',
    '(New-Action \'customization-accent\' "Accent color: $(Get-HcAccentColor)" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-accent\' \'Accent color\' \'Open the controller color wheel.\')',
    '(New-Action \'customization-highlight\' "Focus highlight: $(Get-HcHighlightColor)" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-highlight\' \'Focus highlight color\' \'Open the controller color wheel.\')',
    '(New-Action \'customization-dynamic-primary\' "Dynamic primary: $(Get-HcColor \'DynamicPrimaryColor\' \'#D6B64F\')" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-dynamic-primary\' \'Dynamic primary color\' \'Open the controller color wheel.\')',
    '(New-Action \'customization-dynamic-secondary\' "Dynamic secondary: $(Get-HcColor \'DynamicSecondaryColor\' \'#4474C2\')" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-dynamic-secondary\' \'Dynamic secondary color\' \'Open the controller color wheel.\')',
    '(New-Action \'customization-dynamic-tertiary\' "Dynamic tertiary: $(Get-HcColor \'DynamicTertiaryColor\' \'#315F9D\')" \'Enter a #RRGGBB color.\')': '(New-Action \'customization-dynamic-tertiary\' \'Dynamic tertiary color\' \'Open the controller color wheel.\')',
    "'customization-shell-base' {Open-HcCustomizationKeyboard 'ShellBaseColor' 'Interface base color — #RRGGBB' (Get-HcColor 'ShellBaseColor' '#09111E');return}": "'customization-shell-base' {Show-HcColorPicker 'ShellBaseColor' 'Interface base color' (Get-HcColor 'ShellBaseColor' '#09111E');return}",
    "'customization-accent' {Open-HcCustomizationKeyboard 'AccentColor' 'Accent color — #RRGGBB' (Get-HcAccentColor);return}": "'customization-accent' {Show-HcColorPicker 'AccentColor' 'Accent color' (Get-HcAccentColor);return}",
    "'customization-highlight' {Open-HcCustomizationKeyboard 'AccentHighlightColor' 'Focus highlight — #RRGGBB' (Get-HcHighlightColor);return}": "'customization-highlight' {Show-HcColorPicker 'AccentHighlightColor' 'Focus highlight color' (Get-HcHighlightColor);return}",
    "'customization-dynamic-primary' {Open-HcCustomizationKeyboard 'DynamicPrimaryColor' 'Dynamic primary — #RRGGBB' (Get-HcColor 'DynamicPrimaryColor' '#D6B64F');return}": "'customization-dynamic-primary' {Show-HcColorPicker 'DynamicPrimaryColor' 'Dynamic primary color' (Get-HcColor 'DynamicPrimaryColor' '#D6B64F');return}",
    "'customization-dynamic-secondary' {Open-HcCustomizationKeyboard 'DynamicSecondaryColor' 'Dynamic secondary — #RRGGBB' (Get-HcColor 'DynamicSecondaryColor' '#4474C2');return}": "'customization-dynamic-secondary' {Show-HcColorPicker 'DynamicSecondaryColor' 'Dynamic secondary color' (Get-HcColor 'DynamicSecondaryColor' '#4474C2');return}",
    "'customization-dynamic-tertiary' {Open-HcCustomizationKeyboard 'DynamicTertiaryColor' 'Dynamic tertiary — #RRGGBB' (Get-HcColor 'DynamicTertiaryColor' '#315F9D');return}": "'customization-dynamic-tertiary' {Show-HcColorPicker 'DynamicTertiaryColor' 'Dynamic tertiary color' (Get-HcColor 'DynamicTertiaryColor' '#315F9D');return}",
}
for old, new in replacements.items():
    custom = replace_once(custom, old, new, 'Customization color-wheel replacement')

load_marker = "function Initialize-HcCustomization {\n"
if "$script:HcColorPickerModulePath" not in custom:
    loader = """$script:HcColorPickerModulePath=Join-Path $script:BaseDir 'HuymaierColorPicker.ps1'
if(Test-Path -LiteralPath $script:HcColorPickerModulePath -PathType Leaf){. $script:HcColorPickerModulePath}

"""
    custom = replace_once(custom, load_marker, loader + load_marker, 'Color picker module loader')
write_ps(custom_path, custom)

print('Applied v0.26.2 Game Bar native-surface routing and controller color wheel.')
