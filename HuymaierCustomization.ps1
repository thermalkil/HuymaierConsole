# Huymaier Console customization layer.
# Loaded after the shell, emulator platforms, browser, and Game Bar modules so
# personalization can decorate every shared surface without changing product/file
# identity. User-facing console branding is intentionally separate from install
# paths, package identity, update tags, and internal provider IDs.

$script:HcCustomizationBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcCustomizationBaseInvokeAction=${function:Invoke-Action}
$script:HcCustomizationBaseAdjustSelectedSlider=${function:Adjust-SelectedSlider}
$script:HcCustomizationBaseCompleteKeyboard=${function:Complete-NativeKeyboardInput}
$script:HcCustomizationBaseUpdateActionVisuals=${function:Update-ActionVisuals}
$script:HcCustomizationBaseUpdateNavVisuals=${function:Update-NavVisuals}
$script:HcCustomizationBaseGetPlatformCountSummary=${function:Get-PlatformCountSummary}
$script:HcCustomizationBaseInitializeUiFeedback=${function:Initialize-UiFeedback}
$script:HcCustomizationBaseSetConsoleNotice=${function:Set-ConsoleNotice}
$script:HcCustomizationBaseMainMenuVisuals=$(if(Get-Command Update-HcMainMenuVisuals -ErrorAction SilentlyContinue){${function:Update-HcMainMenuVisuals}}else{$null})
$script:HcBrightnessOverlay=$null
# HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1

function Add-HcCustomizationConfigProperty {
    param([string]$Name,$Value)
    if($null -eq $script:Config.PSObject.Properties[$Name]){$script:Config|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force}
}
function Initialize-HcCustomizationConfig {
    Add-HcCustomizationConfigProperty 'ConsoleName' 'Huymaier Console'
    Add-HcCustomizationConfigProperty 'ShellBaseColor' '#09111E'
    Add-HcCustomizationConfigProperty 'AccentColor' '#E7C45E'
    Add-HcCustomizationConfigProperty 'AccentHighlightColor' '#FFF0A0'
    Add-HcCustomizationConfigProperty 'DynamicThemePreset' 'Huymaier'
    Add-HcCustomizationConfigProperty 'DynamicPrimaryColor' '#D6B64F'
    Add-HcCustomizationConfigProperty 'DynamicSecondaryColor' '#4474C2'
    Add-HcCustomizationConfigProperty 'DynamicTertiaryColor' '#315F9D'
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

function Get-HcConsoleName {
    $name=[string](Get-EntryProperty $script:Config 'ConsoleName' 'Huymaier Console')
    $name=([regex]::Replace($name,'[\x00-\x1F\x7F]',' ')).Trim()
    if($name.Length -gt 48){$name=$name.Substring(0,48).Trim()}
    if(-not $name){$name='Huymaier Console'}
    return $name
}
function Test-HcHexColor { param([string]$Value); return ([string]$Value -match '^#[0-9A-Fa-f]{6}$') }
function Get-HcColor { param([string]$Name,[string]$Fallback);$value=[string](Get-EntryProperty $script:Config $Name $Fallback);if(Test-HcHexColor $value){return $value.ToUpperInvariant()};return $Fallback }
function Get-HcAccentColor { return Get-HcColor 'AccentColor' '#E7C45E' }
function Get-HcHighlightColor { return Get-HcColor 'AccentHighlightColor' '#FFF0A0' }
function New-HcSolidBrush { param([string]$Color);return (New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($Color)) ) }
function Get-HcAlphaColor { param([string]$Color,[string]$Alpha);if(-not(Test-HcHexColor $Color)){return '#00000000'};return ('#'+$Alpha+$Color.Substring(1)) }
function New-HcRadialThemeBrush {
    param([string]$Color,[string]$CenterAlpha='78',[string]$MidAlpha='30')
    $brush=New-Object System.Windows.Media.RadialGradientBrush
    $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $Color $CenterAlpha))),0.0))
    $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $Color $MidAlpha))),0.52))
    $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $Color '00'))),1.0))
    return $brush
}
function Convert-HcDisplayBrandText {
    param([string]$Value)
    if([string]::IsNullOrEmpty($Value)){return $Value}
    $name=Get-HcConsoleName
    if([string]::Equals($name,'Huymaier Console',[StringComparison]::OrdinalIgnoreCase)){return $Value}
    return ([regex]::Replace($Value,'Huymaier Console',[System.Text.RegularExpressions.MatchEvaluator]{param($m)$name},[System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

function Set-ConsoleNotice {
    param([string]$Message,[string]$Level='INFO')
    & $script:HcCustomizationBaseSetConsoleNotice (Convert-HcDisplayBrandText $Message) $Level
}

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
            $alpha=(($value-100)/100.0)*0.50
            $script:HcBrightnessOverlay.Background=New-HcSolidBrush '#FFFFFF'
            $script:HcBrightnessOverlay.Opacity=[math]::Max(0.0,[math]::Min(0.50,$alpha))
        }
    }catch{Write-Log "Console brightness refresh recovered: $($_.Exception.Message)" 'WARN'}
}

function Set-HcGameBarBranding {
    try{
        if('HuymaierConsole.NativeApp.HuymaierGameBarHost' -as [type]){
            [HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetDisplayName((Get-HcConsoleName))
            [HuymaierConsole.NativeApp.HuymaierGameBarHost]::SetAccentColor((Get-HcAccentColor))
        }
    }catch{Write-Log "Game Bar branding refresh recovered: $($_.Exception.Message)" 'WARN'}
}

function Apply-HcCustomizationVisuals {
    Initialize-HcCustomizationConfig
    try{
        $name=Get-HcConsoleName;$accent=Get-HcAccentColor
        if($null -ne $script:Window){$script:Window.Title=$name}
        if($null -ne $script:ConsoleBrandText){$script:ConsoleBrandText.Text=$name.ToUpperInvariant()}
        if($null -ne $script:ConsoleBrandGlyph){$script:ConsoleBrandGlyph.Text=$name.Substring(0,1).ToUpperInvariant();$script:ConsoleBrandGlyph.Foreground=New-HcSolidBrush $accent}
        if($null -ne $script:ConsoleBrandBadge){$script:ConsoleBrandBadge.BorderBrush=New-HcSolidBrush $accent}
        if($null -ne $script:ProductFooterText){$script:ProductFooterText.Text=("$name FSE  v$script:AppVersion").ToUpperInvariant()}
        if($null -ne $script:FpsText){$script:FpsText.Foreground=New-HcSolidBrush $accent}

        $base=Get-HcColor 'ShellBaseColor' '#09111E'
        if($null -ne $script:RootGrid){
            $rootBrush=New-Object System.Windows.Media.RadialGradientBrush;$rootBrush.Center='0.18,0.15';$rootBrush.GradientOrigin='0.18,0.15';$rootBrush.RadiusX=1.1;$rootBrush.RadiusY=1.1
            $rootBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($base)),0.0))
            $rootBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#05080E')),1.0))
            $script:RootGrid.Background=$rootBrush
        }

        $primary=Get-HcColor 'DynamicPrimaryColor' '#D6B64F';$secondary=Get-HcColor 'DynamicSecondaryColor' '#4474C2';$tertiary=Get-HcColor 'DynamicTertiaryColor' '#315F9D'
        if($null -ne $script:DynamicBase){$baseBrush=New-Object System.Windows.Media.LinearGradientBrush;$baseBrush.StartPoint='0,0';$baseBrush.EndPoint='1,1';$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '38'))),0.0));$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00131D2D')),0.46));$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $secondary '2C'))),1.0));$script:DynamicBase.Fill=$baseBrush}
        if($null -ne $script:DynamicGlowOne){$script:DynamicGlowOne.Fill=New-HcRadialThemeBrush $primary '70' '28'}
        if($null -ne $script:DynamicGlowTwo){$script:DynamicGlowTwo.Fill=New-HcRadialThemeBrush $secondary '69' '24'}
        if($null -ne $script:DynamicRibbonOne){$ribbon=New-Object System.Windows.Media.LinearGradientBrush;$ribbon.StartPoint='0,0';$ribbon.EndPoint='1,0';$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary '00'))),0.0));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary 'B8'))),0.42));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '26'))),1.0));$script:DynamicRibbonOne.Stroke=$ribbon}
        if($null -ne $script:DynamicRibbonTwo){$ribbon=New-Object System.Windows.Media.LinearGradientBrush;$ribbon.StartPoint='0,0';$ribbon.EndPoint='1,0';$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '00'))),0.0));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $secondary 'A0'))),0.54));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary '22'))),1.0));$script:DynamicRibbonTwo.Stroke=$ribbon}
        if($null -ne $script:DynamicRibbonThree){$script:DynamicRibbonThree.Stroke=New-HcSolidBrush (Get-HcAlphaColor $tertiary '50')}
        foreach($star in @($script:StarOne,$script:StarThree,$script:StarFive,$script:StarSeven)){if($null -ne $star){$star.Fill=New-HcSolidBrush $primary}}
        foreach($star in @($script:StarTwo,$script:StarFour,$script:StarSix,$script:StarEight)){if($null -ne $star){$star.Fill=New-HcSolidBrush $secondary}}
        Set-HcGameBarBranding
        Apply-HcConsoleBrightness
    }catch{Write-Log "Customization visual refresh recovered: $($_.Exception.Message)" 'WARN'}
}

function Set-HcDynamicThemePreset {
    param([string]$Preset)
    Initialize-HcCustomizationConfig
    $palette=switch($Preset){
        'Xbox' {@('#07150A','#72D54A','#107C10','#063B1B','#72D54A','#B7FF9F')}
        'PlayStation' {@('#06142A','#55B5FF','#006FCD','#031E55','#55B5FF','#B9E2FF')}
        'Purple' {@('#160B2A','#D06BFF','#8A4FFF','#271A57','#C983FF','#EBC9FF')}
        'Crimson' {@('#24090D','#FF7A59','#E53E3E','#51101A','#FF7A59','#FFC0B0')}
        'Cyan' {@('#061D25','#52E5FF','#00C2D8','#073B4C','#52E5FF','#C0F8FF')}
        default {@('#09111E','#D6B64F','#4474C2','#315F9D','#E7C45E','#FFF0A0')}
    }
    $script:Config.DynamicThemePreset=$Preset
    $script:Config.ShellBaseColor=$palette[0];$script:Config.DynamicPrimaryColor=$palette[1];$script:Config.DynamicSecondaryColor=$palette[2];$script:Config.DynamicTertiaryColor=$palette[3];$script:Config.AccentColor=$palette[4];$script:Config.AccentHighlightColor=$palette[5]
    Save-Config;Apply-HcCustomizationVisuals;Render-Page
}
function Cycle-HcDynamicThemePreset {
    $values=@('Huymaier','Xbox','PlayStation','Purple','Crimson','Cyan')
    $current=[string](Get-EntryProperty $script:Config 'DynamicThemePreset' 'Huymaier')
    $index=[array]::IndexOf($values,$current);if($index -lt 0){$index=0}
    Set-HcDynamicThemePreset $values[($index+1)%$values.Count]
}
function Open-HcCustomizationKeyboard { param([string]$Field,[string]$Title,[string]$Initial);Show-NativeKeyboard -Title $Title -InitialText $Initial -Mode 'CustomizationText' -Context ([pscustomobject]@{Field=$Field}) }

function Update-HcPageDisplayBrand {
    param($Page)
    if($null -eq $Page){return $Page}
    foreach($field in @('Title','Subtitle','Hero','HeroText')){try{if($Page.PSObject.Properties[$field]){$Page.$field=Convert-HcDisplayBrandText ([string]$Page.$field)}}catch{}}
    foreach($action in @($Page.Actions)){if($null -eq $action){continue};foreach($field in @('Title','Description')){try{if($action.PSObject.Properties[$field]){$action.$field=Convert-HcDisplayBrandText ([string]$action.$field)}}catch{}}}
    return $Page
}

function Get-PageDefinition {
    param([int]$Index)
    if($Index -eq 7 -and $script:SubPage -eq 'Customization'){
        Initialize-HcCustomizationConfig
        $name=Get-HcConsoleName;$preset=[string](Get-EntryProperty $script:Config 'DynamicThemePreset' 'Huymaier')
        return (Update-HcPageDisplayBrand ([pscustomobject]@{
            Title='Customization';Subtitle='Console identity, overall brightness, interface colors, dynamic theme, music, and navigation sounds.';Hero=$name.ToUpperInvariant();HeroText="Color preset: $preset  |  Controller color wheel available";Actions=@(
                (New-Action 'customization-console-name' "Console name: $name" 'Changes the display name throughout the shell and Game Bar. Product files and update identity stay Huymaier Console.'),
                (New-Action 'customization-preset' "Color preset: $preset" 'Cycles coordinated interface and dynamic-theme palettes.'),
                (New-Action 'customization-shell-base' 'Interface base color' 'Open the controller color wheel.'),
                (New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness' ([int](Get-EntryProperty $script:Config 'ConsoleBrightness' 100)) 'Adjust the entire Huymaier Console interface from 0% to 200% in 10% steps.' 0 200),
                (New-Action 'customization-accent' 'Accent color' 'Open the controller color wheel.'),
                (New-Action 'customization-highlight' 'Focus highlight color' 'Open the controller color wheel.'),
                (New-Action 'background-toggle' $(if($script:Config.DynamicBackground){'Dynamic background: On'}else{'Dynamic background: Off'})),
                (New-Action 'customization-dynamic-primary' 'Dynamic primary color' 'Open the controller color wheel.'),
                (New-Action 'customization-dynamic-secondary' 'Dynamic secondary color' 'Open the controller color wheel.'),
                (New-Action 'customization-dynamic-tertiary' 'Dynamic tertiary color' 'Open the controller color wheel.'),
                (New-Action 'music-toggle' $(if($script:Config.MusicEnabled){'Console music: On'}else{'Console music: Off'})),
                (New-Action 'music-theme' "Music theme: $($script:Config.MusicTheme)"),
                (New-Action 'music-import' 'Import background music'),
                (New-SliderAction 'music-volume-slider' 'Music volume' ([int]$script:Config.MusicVolume) 'Use Left/Right to adjust.'),
                (New-Action 'ui-sounds-toggle' $(if($script:Config.UiSoundsEnabled){'Navigation & interface sounds: On'}else{'Navigation & interface sounds: Off'})),
                (New-SliderAction 'ui-sound-volume-slider' 'Navigation sound volume' ([int](Get-EntryProperty $script:Config 'UiSoundVolume' 62)) 'Use Left/Right to adjust.'),
                (New-Action 'keyboard-theme' "Keyboard theme: $($script:Config.KeyboardTheme)"),
                (New-Action 'keyboard-preview' 'Preview native keyboard'),
                (New-Action 'subpage-back' 'Back to Settings')
            )
        }))
    }
    $page=& $script:HcCustomizationBaseGetPageDefinition $Index
    if($Index -eq 7 -and -not $script:SubPage -and $null -ne $page){
        $filtered=New-Object System.Collections.ArrayList
        [void]$filtered.Add((New-Action 'customization-settings' 'Customization' 'Console name, overall brightness, colors, dynamic theme, music, navigation sounds, and keyboard appearance.'))
        $moved=@('background-toggle','music-toggle','music-theme','music-import','music-volume-slider','ui-sounds-toggle','keyboard-theme','keyboard-preview')
        foreach($action in @($page.Actions)){if($null -ne $action -and ([string](Get-EntryProperty $action 'Id' '')) -notin $moved){[void]$filtered.Add($action)}}
        $page.Actions=[object[]]$filtered.ToArray()
    }
    return (Update-HcPageDisplayBrand $page)
}

function Invoke-Action {
    param([string]$Id)
    switch($Id){
        'customization-settings' {$script:SubPage='Customization';$script:SelectedAction=0;Render-Page;return}
        'customization-console-name' {Open-HcCustomizationKeyboard 'ConsoleName' 'Console name' (Get-HcConsoleName);return}
        'customization-preset' {Cycle-HcDynamicThemePreset;return}
        'customization-shell-base' {Show-HcColorPicker 'ShellBaseColor' 'Interface base color' (Get-HcColor 'ShellBaseColor' '#09111E');return}
        'console-brightness-slider' {Adjust-SelectedSlider 10;return}
        'customization-accent' {Show-HcColorPicker 'AccentColor' 'Accent color' (Get-HcAccentColor);return}
        'customization-highlight' {Show-HcColorPicker 'AccentHighlightColor' 'Focus highlight color' (Get-HcHighlightColor);return}
        'customization-dynamic-primary' {Show-HcColorPicker 'DynamicPrimaryColor' 'Dynamic primary color' (Get-HcColor 'DynamicPrimaryColor' '#D6B64F');return}
        'customization-dynamic-secondary' {Show-HcColorPicker 'DynamicSecondaryColor' 'Dynamic secondary color' (Get-HcColor 'DynamicSecondaryColor' '#4474C2');return}
        'customization-dynamic-tertiary' {Show-HcColorPicker 'DynamicTertiaryColor' 'Dynamic tertiary color' (Get-HcColor 'DynamicTertiaryColor' '#315F9D');return}
    }
    & $script:HcCustomizationBaseInvokeAction $Id
}

function Complete-NativeKeyboardInput {
    param([string]$Mode,[string]$Value,$Context)
    if($Mode -eq 'CustomizationText'){
        Initialize-HcCustomizationConfig
        $field=[string](Get-EntryProperty $Context 'Field' '')
        if($field -eq 'ConsoleName'){
            $name=([regex]::Replace(([string]$Value),'[\x00-\x1F\x7F]',' ')).Trim()
            if($name.Length -gt 48){$name=$name.Substring(0,48).Trim()}
            if(-not $name){Set-ConsoleNotice 'Console name cannot be blank.' 'WARN';Render-Page;return}
            $script:Config.ConsoleName=$name
        }elseif($field -in @('ShellBaseColor','AccentColor','AccentHighlightColor','DynamicPrimaryColor','DynamicSecondaryColor','DynamicTertiaryColor')){
            $color=([string]$Value).Trim().ToUpperInvariant();if(-not(Test-HcHexColor $color)){Set-ConsoleNotice 'Enter a color in #RRGGBB format, for example #52E5FF.' 'WARN';Render-Page;return}
            $script:Config.$field=$color;$script:Config.DynamicThemePreset='Custom'
        }else{Set-ConsoleNotice 'Unknown customization field.' 'WARN';Render-Page;return}
        Save-Config;Apply-HcCustomizationVisuals;Render-Page;return
    }
    & $script:HcCustomizationBaseCompleteKeyboard $Mode $Value $Context
}

function Adjust-SelectedSlider {
    param([int]$Delta)
    $action=Get-SelectedActionObject
    if($null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'console-brightness-slider'){
        $direction=$(if($Delta -lt 0){-10}elseif($Delta -gt 0){10}else{0})
        $current=[int](Get-EntryProperty $script:Config 'ConsoleBrightness' 100)
        $current=[int]([math]::Round($current/10.0)*10)
        $value=[math]::Max(0,[math]::Min(200,$current+$direction));$script:Config.ConsoleBrightness=$value;Save-Config
        Apply-HcConsoleBrightness
        try{$action.Value=$value}catch{}
        try{$control=$script:SliderControls['console-brightness-slider'];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
        Invoke-UiFeedback 'Navigate';return $true
    }
    if($null -ne $action -and [string](Get-EntryProperty $action 'Id' '') -eq 'ui-sound-volume-slider'){
        $value=[math]::Max(0,[math]::Min(100,([int](Get-EntryProperty $script:Config 'UiSoundVolume' 62))+$Delta));$script:Config.UiSoundVolume=$value;Save-Config
        foreach($player in @($script:SfxPlayers.Values)){try{$player.Volume=$value/100.0}catch{}}
        try{$action.Value=$value}catch{};try{$control=$script:SliderControls['ui-sound-volume-slider'];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
        Invoke-UiFeedback 'Navigate';return $true
    }
    return (& $script:HcCustomizationBaseAdjustSelectedSlider $Delta)
}

function Initialize-UiFeedback {
    & $script:HcCustomizationBaseInitializeUiFeedback
    $volume=[math]::Max(0.0,[math]::Min(1.0,([int](Get-EntryProperty $script:Config 'UiSoundVolume' 62)/100.0)))
    foreach($player in @($script:SfxPlayers.Values)){try{$player.Volume=$volume}catch{}}
}

function Get-PlatformCountSummary {
    param([string]$Platform)
    # Display/menu identity is authoritative. In particular, storefront Xbox must
    # never be interpreted as the Original Xbox emulator merely because its
    # backend ID is also "xbox".
    if((Get-Command Test-HcStorefrontPlatform -ErrorAction SilentlyContinue) -and (Test-HcStorefrontPlatform $Platform)){
        $installed=@(Get-PlatformGames $Platform).Count;$owned=@(Get-PlatformLibraryGames $Platform).Count
        return [pscustomobject]@{Installed=$installed;Owned=$owned;Pending=$false}
    }
    return (& $script:HcCustomizationBaseGetPlatformCountSummary $Platform)
}

function Update-ActionVisuals {
    & $script:HcCustomizationBaseUpdateActionVisuals
    if($script:ActionButtons.Count -eq 0){return}
    $accent=Get-HcAccentColor;$highlight=Get-HcHighlightColor
    for($i=0;$i -lt $script:ActionButtons.Count;$i++){
        $button=$script:ActionButtons[$i]
        try{$button.FocusVisualStyle=$null}catch{}
        if($i -eq $script:SelectedAction -and $script:NavigationLayer -eq 'Content'){
            try{$button.BorderBrush=New-HcSolidBrush $accent;$button.BorderThickness='3';$button.Opacity=1.0}catch{}
            # Scaling normal list cards caused selected text/borders to be clipped
            # by their parent ScrollViewer. Keep the cinematic shelf zoom only.
            try{$scale=$(if($script:SubPage -eq 'PlatformShelf'){1.05}else{1.0});$button.RenderTransform=(New-Object System.Windows.Media.ScaleTransform -ArgumentList $scale,$scale)}catch{}
        }
    }
}

function Update-NavVisuals {
    & $script:HcCustomizationBaseUpdateNavVisuals
    $accent=Get-HcAccentColor;$highlight=Get-HcHighlightColor
    for($i=0;$i -lt $script:NavButtons.Count;$i++){
        $button=$script:NavButtons[$i];try{$button.FocusVisualStyle=$null}catch{}
        if($i -eq $script:SelectedTab){try{$button.Background=New-HcSolidBrush $accent;$button.BorderBrush=New-HcSolidBrush $(if($script:NavigationLayer -eq 'Navigation'){$highlight}else{$accent})}catch{}}
    }
}

if($null -ne $script:HcCustomizationBaseMainMenuVisuals){
    function Update-HcMainMenuVisuals {
        & $script:HcCustomizationBaseMainMenuVisuals
        $accent=Get-HcAccentColor;$highlight=Get-HcHighlightColor
        for($i=0;$i -lt @($script:HcMainMenuButtons).Count;$i++){
            $button=$script:HcMainMenuButtons[$i];try{$button.FocusVisualStyle=$null}catch{}
            if($i -eq $script:HcMainMenuSelected){try{$button.Background=New-HcSolidBrush $accent;$button.BorderBrush=New-HcSolidBrush $highlight}catch{}}
        }
    }
}

$script:HcColorPickerModulePath=Join-Path $script:BaseDir 'HuymaierColorPicker.ps1'
if(Test-Path -LiteralPath $script:HcColorPickerModulePath -PathType Leaf){. $script:HcColorPickerModulePath}

function Initialize-HcCustomization {
    Initialize-HcCustomizationConfig
    Apply-HcCustomizationVisuals
    try{Initialize-UiFeedback}catch{}
}

Initialize-HcCustomizationConfig

# Manual Recomps owns the final provider/file-picker behavior so the user can
# add multiple native recomp games explicitly, one executable at a time.
$script:HcManualRecompsModulePath=Join-Path $script:BaseDir 'HuymaierRecompsManual.ps1'
if(Test-Path -LiteralPath $script:HcManualRecompsModulePath -PathType Leaf){. $script:HcManualRecompsModulePath}
