param(
    [Parameter(Mandatory=$true)][string]$CustomizationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $CustomizationPath -PathType Leaf)){throw "Customization source missing: $CustomizationPath"}
$text=[IO.File]::ReadAllText($CustomizationPath,[Text.Encoding]::UTF8)
if($text.Contains('HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1')){Write-Host 'v0.30.2 console brightness transform already applied.';return}

function Replace-ExactlyOnce([string]$Old,[string]$New,[string]$Label){
    $count=([regex]::Matches($script:text,[regex]::Escape($Old))).Count
    if($count -ne 1){throw "Expected exactly one $Label marker, found $count."}
    $script:text=$script:text.Replace($Old,$New)
}

$old=@'
$script:HcCustomizationBaseMainMenuVisuals=$(if(Get-Command Update-HcMainMenuVisuals -ErrorAction SilentlyContinue){${function:Update-HcMainMenuVisuals}}else{$null})
'@
$new=$old+@'
$script:HcBrightnessOverlay=$null
# HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1
'@
Replace-ExactlyOnce $old $new 'customization state anchor'

$old=@'
    Add-HcCustomizationConfigProperty 'UiSoundVolume' 62
    try{$script:Config.UiSoundVolume=[math]::Max(0,[math]::Min(100,[int]$script:Config.UiSoundVolume))}catch{$script:Config.UiSoundVolume=62}
    if([string]::IsNullOrWhiteSpace([string]$script:Config.ConsoleName)){$script:Config.ConsoleName='Huymaier Console'}
}
'@
$new=@'
    Add-HcCustomizationConfigProperty 'UiSoundVolume' 62
    if($null -eq $script:Config.PSObject.Properties['ConsoleBrightness']){
        $persistedBrightness=$null
        try{
            if(Test-Path -LiteralPath $script:ConfigPath -PathType Leaf){
                $persistedConfig=Get-Content -Raw -LiteralPath $script:ConfigPath -Encoding UTF8|ConvertFrom-Json
                if($null -ne $persistedConfig.PSObject.Properties['ConsoleBrightness']){$persistedBrightness=[int]$persistedConfig.ConsoleBrightness}
            }
        }catch{}
        Add-HcCustomizationConfigProperty 'ConsoleBrightness' $(if($null -eq $persistedBrightness){100}else{$persistedBrightness})
    }
    try{$script:Config.UiSoundVolume=[math]::Max(0,[math]::Min(100,[int]$script:Config.UiSoundVolume))}catch{$script:Config.UiSoundVolume=62}
    try{$script:Config.ConsoleBrightness=[math]::Max(0,[math]::Min(200,([int]([math]::Round(([int]$script:Config.ConsoleBrightness)/10.0)*10))))}catch{$script:Config.ConsoleBrightness=100}
    if([string]::IsNullOrWhiteSpace([string]$script:Config.ConsoleName)){$script:Config.ConsoleName='Huymaier Console'}
}
'@
Replace-ExactlyOnce $old $new 'customization config anchor'

$old="function Set-HcGameBarBranding {`n"
$new=@'
function Get-HcConsoleBrightness {
    Initialize-HcCustomizationConfig
    return [int](Get-EntryProperty $script:Config 'ConsoleBrightness' 100)
}
function Apply-HcConsoleBrightness {
    Initialize-HcCustomizationConfig
    if($null -eq $script:RootGrid){return}
    try{
        if($null -eq $script:HcBrightnessOverlay){
            $overlay=New-Object System.Windows.Controls.Border
            $overlay.Name='HcConsoleBrightnessOverlay'
            $overlay.IsHitTestVisible=$false
            $overlay.Focusable=$false
            $overlay.HorizontalAlignment='Stretch';$overlay.VerticalAlignment='Stretch'
            [System.Windows.Controls.Panel]::SetZIndex($overlay,2147483647)
            [void]$script:RootGrid.Children.Add($overlay)
            $script:HcBrightnessOverlay=$overlay
        }
        $value=Get-HcConsoleBrightness
        if($value -eq 100){$script:HcBrightnessOverlay.Visibility='Collapsed';return}
        $script:HcBrightnessOverlay.Visibility='Visible'
        if($value -lt 100){
            $alpha=(100-$value)/100.0
            $script:HcBrightnessOverlay.Background=New-HcSolidBrush '#000000'
            $script:HcBrightnessOverlay.Opacity=[math]::Max(0.0,[math]::Min(1.0,$alpha))
        }else{
            # WPF has no compositor-level multiply-brightness primitive. A bounded
            # white lift preserves readable highlights while making the whole shell
            # visibly brighter without touching system/display brightness.
            $alpha=(($value-100)/100.0)*0.50
            $script:HcBrightnessOverlay.Background=New-HcSolidBrush '#FFFFFF'
            $script:HcBrightnessOverlay.Opacity=[math]::Max(0.0,[math]::Min(0.50,$alpha))
        }
    }catch{Write-Log "Console brightness refresh recovered: $($_.Exception.Message)" 'WARN'}
}

function Set-HcGameBarBranding {
'@
Replace-ExactlyOnce $old $new 'brightness helper insertion anchor'

Replace-ExactlyOnce "        Set-HcGameBarBranding`n" "        Set-HcGameBarBranding`n        Apply-HcConsoleBrightness`n" 'customization visual application anchor'

$old="                (New-Action 'customization-shell-base' 'Interface base color' 'Open the controller color wheel.'),`n"
$new=$old+"                (New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness' ([int](Get-EntryProperty `$script:Config 'ConsoleBrightness' 100)) 'Adjust the entire Huymaier Console interface from 0% to 200% in 10% steps.' 0 200),`n"
Replace-ExactlyOnce $old $new 'customization brightness slider anchor'

$old="        'customization-shell-base' {Show-HcColorPicker 'ShellBaseColor' 'Interface base color' (Get-HcColor 'ShellBaseColor' '#09111E');return}`n"
$new=$old+"        'console-brightness-slider' {Adjust-SelectedSlider 10;return}`n"
Replace-ExactlyOnce $old $new 'brightness action anchor'

$old="    if(`$null -ne `$action -and [string](Get-EntryProperty `$action 'Id' '') -eq 'ui-sound-volume-slider'){`n"
$new=@'
    if($null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'console-brightness-slider'){
        $direction=$(if($Delta -lt 0){-10}elseif($Delta -gt 0){10}else{0})
        $current=[int](Get-EntryProperty $script:Config 'ConsoleBrightness' 100)
        $current=[int]([math]::Round($current/10.0)*10)
        $value=[math]::Max(0,[math]::Min(200,$current+$direction));$script:Config.ConsoleBrightness=$value;Save-Config
        Apply-HcConsoleBrightness
        try{$action.Value=$value}catch{};try{$control=$script:SliderControls['console-brightness-slider'];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
        Invoke-UiFeedback 'Navigate';return $true
    }
    if($null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'ui-sound-volume-slider'){
'@
Replace-ExactlyOnce $old $new 'brightness slider handler anchor'

Replace-ExactlyOnce "Title='Customization';Subtitle='Console identity, interface colors, dynamic theme, music, and navigation sounds.';" "Title='Customization';Subtitle='Console identity, overall brightness, interface colors, dynamic theme, music, and navigation sounds.';" 'customization subtitle'
Replace-ExactlyOnce "'Console name, colors, dynamic theme, music, navigation sounds, and keyboard appearance.'" "'Console name, overall brightness, colors, dynamic theme, music, navigation sounds, and keyboard appearance.'" 'customization settings description'

[IO.File]::WriteAllText($CustomizationPath,$text,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Applied v0.30.2 overall Huymaier Console brightness control (0-200%, 10% steps).'