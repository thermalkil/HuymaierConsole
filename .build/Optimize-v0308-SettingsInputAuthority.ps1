param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_SETTINGS_INPUT_AUTHORITY_TRANSFORM_V1
$root=Split-Path -Parent $PSScriptRoot
$lf="`n"
function Read-Normalized([string]$Path){([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)).Replace("`r`n","`n")}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not$Text.Contains($Old)){throw "v0.30.8 settings-input transform anchor missing: $Label"};$Text.Replace($Old,$New)}
function Replace-Range([string]$Text,[string]$Start,[string]$End,[string]$Replacement,[string]$Label){$a=$Text.IndexOf($Start,[StringComparison]::Ordinal);if($a-lt0){throw "Range start missing ($Label): $Start"};$b=$Text.IndexOf($End,$a+$Start.Length,[StringComparison]::Ordinal);if($b-lt0){throw "Range end missing ($Label): $End"};$Text.Remove($a,$b-$a).Insert($a,$Replacement.TrimEnd()+$lf+$lf)}

# The storefront/native-keyboard layer owns the one global keyboard completion
# dispatcher. Secure API tokens stay in the secure buffer for typing and paste.
$storefrontPath=Join-Path $root 'HuymaierStorefronts.ps1';$storefront=Read-Normalized $storefrontPath
if($storefront-notmatch'HUYMAIER_V0308_SECURE_KEYBOARD_INPUT_V1'){
    $anchor="    `$stack.Children.Add(`$inputBox)|Out-Null"
    $paste=@'
    $stack.Children.Add($inputBox)|Out-Null
    # WPF handles Ctrl+V/Shift+Insert as an edit command rather than text input.
    # In secure mode that used to change only the visible TextBox while the
    # separate secure buffer stayed empty, so an apparently entered API token
    # was saved as blank. Intercept paste before WPF can bypass the buffer.
    $inputBox.Add_PreviewKeyDown({
        param($sender,$eventArgs)
        if(-not $script:KeyboardActive -or -not $script:KeyboardSecure){return}
        $mods=[System.Windows.Input.Keyboard]::Modifiers
        $paste=(($eventArgs.Key -eq 'V') -and (($mods -band [System.Windows.Input.ModifierKeys]::Control) -ne 0)) -or (($eventArgs.Key -eq 'Insert') -and (($mods -band [System.Windows.Input.ModifierKeys]::Shift) -ne 0))
        if(-not $paste){return}
        try{
            if([System.Windows.Clipboard]::ContainsText()){
                Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[System.Windows.Clipboard]::GetText())
                $script:KeyboardTextBox.CaretIndex=$script:KeyboardTextBox.Text.Length
            }
        }catch{try{Write-Log ('Secure keyboard paste failed: '+$_.Exception.Message) 'WARN'}catch{}}
        $eventArgs.Handled=$true
    })
'@
    $storefront=Replace-Required $storefront $anchor $paste.TrimEnd() 'secure paste interception'
    $storefront=Replace-Required $storefront "    `$script:KeyboardSecure=([string]`$Mode -in @('BrowserInputSecure','SteamGridDbApiKey'))" "    # Both artwork API keys use the masked secure buffer.`n    `$script:KeyboardSecure=([string]`$Mode -in @('BrowserInputSecure','SteamGridDbApiKey','TheGamesDbApiKey'))" 'secure API key modes'
    $storefront=Replace-Required $storefront "    `$script:KeyboardSecureBuffer=`$(if(`$script:KeyboardSecure){[string]`$InitialText}else{''})" "    `$script:KeyboardSecureBuffer=`$(if(`$script:KeyboardSecure){[string]`$InitialText}else{''})`n    `$script:KeyboardSecureReplacePending=(`$script:KeyboardSecure -and -not [string]::IsNullOrEmpty([string]`$InitialText)) # HUYMAIER_V0308_SECURE_KEYBOARD_INPUT_V1" 'secure replacement state'
    $storefront=Replace-Required $storefront "    `$script:KeyboardSecure=`$false;`$script:KeyboardSecureBuffer=''" "    `$script:KeyboardSecure=`$false;`$script:KeyboardSecureBuffer='';`$script:KeyboardSecureReplacePending=`$false" 'secure state reset'
    $dispatcher='function Complete-NativeKeyboardInput {'
    $helper=@'
function Set-HcApiKeyFromKeyboard {
    param([string]$Name,[string]$Value,[string]$Label)
    $key=([string]$Value).Trim()
    $saved=$false
    if(Get-Command Set-HcPersistedConfigValue -ErrorAction SilentlyContinue){
        $saved=[bool](Set-HcPersistedConfigValue -Path $script:ConfigPath -Config $script:Config -Name $Name -Value $key -Depth 16)
    }else{
        try{
            if($null -eq $script:Config.PSObject.Properties[$Name]){$script:Config|Add-Member -NotePropertyName $Name -NotePropertyValue $key -Force}else{$script:Config.$Name=$key}
            Save-Config
            if(Test-Path -LiteralPath $script:ConfigPath -PathType Leaf){
                $verify=Get-Content -Raw -LiteralPath $script:ConfigPath -Encoding UTF8|ConvertFrom-Json
                $saved=($null -ne $verify.PSObject.Properties[$Name] -and [string]$verify.$Name -ceq $key)
            }
        }catch{$saved=$false}
    }
    if($saved){
        Set-ConsoleNotice $(if($key){"$Label API key saved and verified."}else{"$Label API key cleared and verified."}) 'INFO'
    }else{
        Set-ConsoleNotice "$Label API key could not be verified on disk. The previous value may still be active; check the log before closing Huymaier Console." 'ERROR'
        try{Write-Log "$Label API key persistence verification failed." 'ERROR'}catch{}
    }
    Render-Page
}

function Complete-NativeKeyboardInput {
'@
    $storefront=Replace-Required $storefront $dispatcher $helper.TrimEnd() 'single keyboard dispatcher helper'
    $new=@'
        'SteamGridDbApiKey' {
            Set-HcApiKeyFromKeyboard 'SteamGridDbApiKey' $Value 'SteamGridDB'
        }
        'TheGamesDbApiKey' {
            Set-HcApiKeyFromKeyboard 'TheGamesDbApiKey' $Value 'TheGamesDB'
        }
        'CustomizationText' {
            if(Get-Command Complete-HcCustomizationKeyboardInput -ErrorAction SilentlyContinue){Complete-HcCustomizationKeyboardInput $Value $Context}
            else{Set-ConsoleNotice 'Customization input handler is unavailable.' 'ERROR';Render-Page}
        }
'@
    $storefront=Replace-Range $storefront "        'SteamGridDbApiKey' {" "        'CreateFolder' {" $new 'API key and customization dispatch cases'
    $old=@'
function Get-NativeKeyboardBuffer {
    if($script:KeyboardSecure){return [string]$script:KeyboardSecureBuffer}
    return [string]$script:KeyboardTextBox.Text
}
'@
    $new=@'
function Get-NativeKeyboardBuffer {
    if($script:KeyboardSecure){
        # The first real edit replaces an existing masked secret. Close/OK reads
        # the secure buffer directly, so opening a token and accepting it keeps it.
        if($script:KeyboardSecureReplacePending){
            $script:KeyboardSecureReplacePending=$false
            $script:KeyboardSecureBuffer=''
            try{$script:KeyboardTextBox.Text=''}catch{}
        }
        return [string]$script:KeyboardSecureBuffer
    }
    return [string]$script:KeyboardTextBox.Text
}
'@
    $storefront=Replace-Required $storefront $old.TrimEnd() $new.TrimEnd() 'secure first-edit replacement'
}
Write-Normalized $storefrontPath $storefront

# Customization owns only its domain-specific handler; it no longer replaces the
# global keyboard completion function and no longer chains an older implementation.
$customPath=Join-Path $root 'HuymaierCustomization.ps1';$custom=Read-Normalized $customPath
if($custom-match'HcCustomizationBaseCompleteKeyboard'){$custom=$custom.Replace('$script:HcCustomizationBaseCompleteKeyboard=${function:Complete-NativeKeyboardInput}'+$lf,'')}
if($custom-match'function Complete-NativeKeyboardInput \{'){
    $replacement=@'
function Complete-HcCustomizationKeyboardInput {
    param([string]$Value,$Context)
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
    Save-Config;Apply-HcCustomizationVisuals;Render-Page
}
'@
    $custom=Replace-Range $custom 'function Complete-NativeKeyboardInput {' 'function Adjust-SelectedSlider {' $replacement 'customization keyboard domain handler'
}
Write-Normalized $customPath $custom

# Background tasks must not be a keyboard/settings persistence layer. Remove the
# late global wrapper that could silently supersede the actual input owner.
$tasksPath=Join-Path $root 'HuymaierBackgroundTasks.ps1';$tasks=Read-Normalized $tasksPath
$legacy='# Guarantee that both displayed API-key controls persist the value they accepted.'
$idx=$tasks.IndexOf($legacy,[StringComparison]::Ordinal)
if($idx-ge0){$tasks=$tasks.Substring(0,$idx).TrimEnd()+$lf}
Write-Normalized $tasksPath $tasks

# Production/runtime metadata cleanup. Historical comments and intentional
# compatibility mappings are left intact; only active User-Agent/version/default
# values and stale user-facing installer guidance are normalized.
foreach($relative in @('HuymaierGameProviderWorker.ps1','HuymaierArtworkWorker.ps1','HuymaierSteamOwnership.ps1','HuymaierLibraryWorker.ps1','HuymaierSteamWorker.ps1','HuymaierEmulatorInstaller.ps1')){
    $path=Join-Path $root $relative;$text=Read-Normalized $path
    $text=[regex]::Replace($text,'HuymaierConsole/0\.(?:\d+)(?:\.\d+)?','HuymaierConsole/0.30.8')
    $text=[regex]::Replace($text,'Huymaier-Console/0\.(?:\d+)(?:\.\d+)?','Huymaier-Console/0.30.8')
    Write-Normalized $path $text
}
$path=Join-Path $root 'Native/HuymaierConsole.ConsolePlatforms.cs';$text=Read-Normalized $path;$text=[regex]::Replace($text,'HuymaierConsole/0\.(?:\d+)(?:\.\d+)?','HuymaierConsole/0.30.8');Write-Normalized $path $text
$path=Join-Path $root 'HuymaierConsoleUpdateWorker.ps1';$text=Read-Normalized $path;$text=Replace-Required $text "    [string]`$CurrentVersion='0.26.1'," "    [string]`$CurrentVersion='0.30.8', # HUYMAIER_V0308_RUNTIME_METADATA_V1" 'updater current-version default';Write-Normalized $path $text
$path=Join-Path $root 'Native/HuymaierConsole.NativeApp.cs';$text=Read-Normalized $path;$text=Replace-Required $text 'public string Version { get { return "0.26.4"; } }' 'public string Version { get { return "0.30.8"; } }' 'native bridge runtime version';Write-Normalized $path $text
$path=Join-Path $root 'HuymaierEmulatorPlatforms.ps1';$text=Read-Normalized $path;$text=Replace-Required $text 'Close Huymaier Console and run the v0.25.6 installer once.' 'Close Huymaier Console and rerun the current Huymaier Console installer.' 'stale emulator installer guidance';Write-Normalized $path $text

Write-Host 'Applied v0.30.8 secure API-key persistence, single keyboard authority, and active runtime metadata cleanup.'
