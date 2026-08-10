from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path,text,bom=False):
    Path(path).write_text(text,encoding='utf-8-sig' if bom else 'utf-8',newline='\n')


def replace_once(text,old,new,label):
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected one match, found {count}')
    return text.replace(old,new,1)

# ---------------------------------------------------------------------------
# The older ConsoleSettings page is now operational/system-oriented. Personal
# appearance/audio controls live only in Settings -> Customization.
# ---------------------------------------------------------------------------
p='HuymaierShellRedesign.ps1'
t=read(p)
for line in [
    "                (New-Action 'background-toggle' $(if($script:Config.DynamicBackground){'Dynamic backgrounds: On'}else{'Dynamic backgrounds: Off'})),\n",
    "                (New-Action 'music-toggle' $(if($script:Config.MusicEnabled){'Console music: On'}else{'Console music: Off'})),\n",
    "                (New-Action 'music-theme' \"Music theme: $($script:Config.MusicTheme)\"),\n",
    "                (New-Action 'music-import' 'Import background music'),\n",
    "                (New-SliderAction 'music-volume-slider' 'Music volume' ([int]$script:Config.MusicVolume)),\n",
    "                (New-Action 'ui-sounds-toggle' $(if($script:Config.UiSoundsEnabled){'Interface sounds: On'}else{'Interface sounds: Off'})),\n",
    "                (New-Action 'keyboard-theme' \"Keyboard theme: $($script:Config.KeyboardTheme)\"),\n",
]:
    if line in t:
        t=t.replace(line,'',1)
old="            return [pscustomobject]@{Title='Huymaier Console';Subtitle='Customize the full-screen console experience.';Hero='CONSOLE EXPERIENCE';HeroText='Visuals, prompts, sound, startup and Quick Access behavior.';Actions=$actions}\n"
new="            return [pscustomobject]@{Title='Huymaier Console';Subtitle='Operational console, input, startup, artwork, and Quick Access settings.';Hero='CONSOLE SETTINGS';HeroText='System behavior stays here. Appearance, dynamic theme, music, and navigation sounds are under Customization.';Actions=$actions}\n"
if old in t:
    t=replace_once(t,old,new,'ConsoleSettings operational description')
write(p,t,bom=True)

# ---------------------------------------------------------------------------
# Improve the display-name coverage and preserve the dynamic backdrop's original
# gradient/glow character while making its palette fully user-selectable.
# ---------------------------------------------------------------------------
p='HuymaierCustomization.ps1'
t=read(p)

base_anchor="$script:HcCustomizationBaseInitializeUiFeedback=${function:Initialize-UiFeedback}\n"
if '$script:HcCustomizationBaseSetConsoleNotice' not in t:
    t=replace_once(t,base_anchor,base_anchor+"$script:HcCustomizationBaseSetConsoleNotice=${function:Set-ConsoleNotice}\n",'notice wrapper capture')

brush_anchor="function New-HcSolidBrush { param([string]$Color);return (New-Object System.Windows.Media.SolidColorBrush -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($Color)) ) }\n"
brush_helpers=brush_anchor+r'''function Get-HcAlphaColor { param([string]$Color,[string]$Alpha);if(-not(Test-HcHexColor $Color)){return '#00000000'};return ('#'+$Alpha+$Color.Substring(1)) }
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

'''
if 'function New-HcRadialThemeBrush' not in t:
    t=replace_once(t,brush_anchor,brush_helpers,'gradient customization helpers')

# Replace flat dynamic recoloring with palette-preserving gradient brushes.
old_dynamic='''        $primary=Get-HcColor 'DynamicPrimaryColor' '#D6B64F';$secondary=Get-HcColor 'DynamicSecondaryColor' '#4474C2';$tertiary=Get-HcColor 'DynamicTertiaryColor' '#315F9D'\n        if($null -ne $script:DynamicBase){$script:DynamicBase.Fill=New-HcSolidBrush $tertiary}\n        if($null -ne $script:DynamicGlowOne){$script:DynamicGlowOne.Fill=New-HcSolidBrush $primary}\n        if($null -ne $script:DynamicGlowTwo){$script:DynamicGlowTwo.Fill=New-HcSolidBrush $secondary}\n        if($null -ne $script:DynamicRibbonOne){$script:DynamicRibbonOne.Stroke=New-HcSolidBrush $primary}\n        if($null -ne $script:DynamicRibbonTwo){$script:DynamicRibbonTwo.Stroke=New-HcSolidBrush $secondary}\n        if($null -ne $script:DynamicRibbonThree){$script:DynamicRibbonThree.Stroke=New-HcSolidBrush $tertiary}\n'''
new_dynamic='''        $primary=Get-HcColor 'DynamicPrimaryColor' '#D6B64F';$secondary=Get-HcColor 'DynamicSecondaryColor' '#4474C2';$tertiary=Get-HcColor 'DynamicTertiaryColor' '#315F9D'\n        if($null -ne $script:DynamicBase){$baseBrush=New-Object System.Windows.Media.LinearGradientBrush;$baseBrush.StartPoint='0,0';$baseBrush.EndPoint='1,1';$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '38'))),0.0));$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00131D2D')),0.46));$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $secondary '2C'))),1.0));$script:DynamicBase.Fill=$baseBrush}\n        if($null -ne $script:DynamicGlowOne){$script:DynamicGlowOne.Fill=New-HcRadialThemeBrush $primary '70' '28'}\n        if($null -ne $script:DynamicGlowTwo){$script:DynamicGlowTwo.Fill=New-HcRadialThemeBrush $secondary '69' '24'}\n        if($null -ne $script:DynamicRibbonOne){$ribbon=New-Object System.Windows.Media.LinearGradientBrush;$ribbon.StartPoint='0,0';$ribbon.EndPoint='1,0';$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary '00'))),0.0));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary 'B8'))),0.42));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '26'))),1.0));$script:DynamicRibbonOne.Stroke=$ribbon}\n        if($null -ne $script:DynamicRibbonTwo){$ribbon=New-Object System.Windows.Media.LinearGradientBrush;$ribbon.StartPoint='0,0';$ribbon.EndPoint='1,0';$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $tertiary '00'))),0.0));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $secondary 'A0'))),0.54));$ribbon.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-HcAlphaColor $primary '22'))),1.0));$script:DynamicRibbonTwo.Stroke=$ribbon}\n        if($null -ne $script:DynamicRibbonThree){$script:DynamicRibbonThree.Stroke=New-HcSolidBrush (Get-HcAlphaColor $tertiary '50')}\n'''
if old_dynamic in t:
    t=replace_once(t,old_dynamic,new_dynamic,'dynamic palette gradient preservation')

# User-facing notices and generic page/action copy adopt the display alias while
# internal logs, updater IDs, paths, and product manifests retain canonical name.
notice_anchor='''function Set-HcGameBarBranding {\n'''
notice_wrapper=r'''function Set-ConsoleNotice {
    param([string]$Message,[string]$Level='INFO')
    & $script:HcCustomizationBaseSetConsoleNotice (Convert-HcDisplayBrandText $Message) $Level
}

'''
if 'function Set-ConsoleNotice {' not in t:
    t=replace_once(t,notice_anchor,notice_wrapper+notice_anchor,'customized user notice wrapper')

# Insert a page decoration helper immediately before the Get-PageDefinition wrapper.
page_anchor='''function Get-PageDefinition {\n'''
page_helper=r'''function Update-HcPageDisplayBrand {
    param($Page)
    if($null -eq $Page){return $Page}
    foreach($field in @('Title','Subtitle','Hero','HeroText')){try{if($Page.PSObject.Properties[$field]){$Page.$field=Convert-HcDisplayBrandText ([string]$Page.$field)}}catch{}}
    foreach($action in @($Page.Actions)){if($null -eq $action){continue};foreach($field in @('Title','Description')){try{if($action.PSObject.Properties[$field]){$action.$field=Convert-HcDisplayBrandText ([string]$action.$field)}}catch{}}}
    return $Page
}

'''
if 'function Update-HcPageDisplayBrand' not in t:
    t=replace_once(t,page_anchor,page_helper+page_anchor,'page display branding helper')

# Customization page and all wrapped base pages pass through the display decorator.
old_custom_return="        return [pscustomobject]@{\n            Title='Customization';Subtitle='Console identity, interface colors, dynamic theme, music, and navigation sounds.';Hero=$name.ToUpperInvariant();HeroText=\"Accent: $(Get-HcAccentColor)  |  Dynamic palette: $preset\";Actions=@(\n"
new_custom_return="        return (Update-HcPageDisplayBrand ([pscustomobject]@{\n            Title='Customization';Subtitle='Console identity, interface colors, dynamic theme, music, and navigation sounds.';Hero=$name.ToUpperInvariant();HeroText=\"Accent: $(Get-HcAccentColor)  |  Dynamic palette: $preset\";Actions=@(\n"
if old_custom_return in t:
    t=t.replace(old_custom_return,new_custom_return,1)
    marker="                (New-Action 'subpage-back' 'Back to Settings')\n            )\n        }\n    }\n    $page=& $script:HcCustomizationBaseGetPageDefinition $Index\n"
    replacement="                (New-Action 'subpage-back' 'Back to Settings')\n            )\n        }))\n    }\n    $page=& $script:HcCustomizationBaseGetPageDefinition $Index\n"
    t=replace_once(t,marker,replacement,'close decorated customization page')

old_end='''    return $page\n}\n\nfunction Invoke-Action {\n'''
new_end='''    return (Update-HcPageDisplayBrand $page)\n}\n\nfunction Invoke-Action {\n'''
if old_end in t:
    t=replace_once(t,old_end,new_end,'decorate wrapped base page')

write(p,t,bom=True)

# Add candidate assertions so moved settings and gradient theme behavior cannot regress.
p='.build/Test-HuymaierCandidate.ps1'
t=read(p)
anchor="    foreach($required in @(\"SubPage -eq 'Customization'\",'ConsoleName','DynamicPrimaryColor','DynamicSecondaryColor','UiSoundVolume','Test-HcStorefrontPlatform $Platform','Scaling normal list cards caused selected text/borders to be clipped')){if($custom -notmatch [regex]::Escape($required)){throw \"Customization/count/card invariant is missing: $required\"}}\n"
extra=anchor+'''    foreach($required in @('New-HcRadialThemeBrush','Update-HcPageDisplayBrand','Convert-HcDisplayBrandText')){if($custom -notmatch [regex]::Escape($required)){throw "Customization gradient/display-name coverage is missing: $required"}}\n    $shellRedesign=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierShellRedesign.ps1') -Encoding UTF8\n    $consoleSettingsStart=$shellRedesign.IndexOf("if($script:SubPage -eq 'ConsoleSettings')")\n    $updatesStart=$shellRedesign.IndexOf("if($script:SubPage -eq 'UpdatesHub')",$consoleSettingsStart)\n    if($consoleSettingsStart -lt 0 -or $updatesStart -lt 0){throw 'ConsoleSettings test window could not be located.'}\n    $consoleSettings=$shellRedesign.Substring($consoleSettingsStart,$updatesStart-$consoleSettingsStart)\n    foreach($moved in @("'music-toggle'","'music-theme'","'music-import'","'music-volume-slider'","'ui-sounds-toggle'","'background-toggle'","'keyboard-theme'")){if($consoleSettings -match [regex]::Escape($moved)){throw "Personalization setting remains duplicated outside Customization: $moved"}}\n'''
if 'Customization gradient/display-name coverage' not in t:
    t=replace_once(t,anchor,extra,'customization polish candidate gates')
write(p,t,bom=True)

print('Customization hierarchy, display-name coverage, and dynamic-gradient polish applied.')
