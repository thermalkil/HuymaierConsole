param([string]$StageRoot='.')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $StageRoot).Path
function Need([bool]$Condition,[string]$Message){if(-not $Condition){throw "v0.30.8 settings-input authority validation failed: $Message"}}
function Read-Hc([string]$Relative){$path=Join-Path $root $Relative;Need (Test-Path -LiteralPath $path -PathType Leaf) "missing $Relative";[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)}
function Parse-Hc([string]$Relative){$path=Join-Path $root $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw (($errors|ForEach-Object{"${Relative}:$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber) $($_.Message)"})-join"`n")}}

foreach($file in @('HuymaierStorefronts.ps1','HuymaierCustomization.ps1','HuymaierBackgroundTasks.ps1','HuymaierSettingsStore.ps1')){Parse-Hc $file}
$storefront=Read-Hc 'HuymaierStorefronts.ps1'
$custom=Read-Hc 'HuymaierCustomization.ps1'
$tasks=Read-Hc 'HuymaierBackgroundTasks.ps1'
$store=Read-Hc 'HuymaierSettingsStore.ps1'

Need ($storefront.Contains('HUYMAIER_V0308_SECURE_KEYBOARD_INPUT_V1')) 'secure keyboard marker missing'
Need ($storefront.Contains("@('BrowserInputSecure','SteamGridDbApiKey','TheGamesDbApiKey')")) 'both artwork API keys are not secure keyboard modes'
Need ($storefront.Contains('$inputBox.Add_PreviewKeyDown({')) 'secure paste PreviewKeyDown interception missing'
Need ($storefront.Contains('[System.Windows.Input.ModifierKeys]::Control')) 'Ctrl+V interception missing'
Need ($storefront.Contains('[System.Windows.Input.ModifierKeys]::Shift')) 'Shift+Insert interception missing'
Need ($storefront.Contains('Set-NativeKeyboardBuffer ((Get-NativeKeyboardBuffer)+[System.Windows.Clipboard]::GetText())')) 'clipboard paste does not update the authoritative secure buffer'
Need ($storefront.Contains('KeyboardSecureReplacePending')) 'existing masked token first-edit replacement state missing'
Need ($storefront.Contains("Set-HcApiKeyFromKeyboard 'SteamGridDbApiKey' `$Value 'SteamGridDB'")) 'SteamGridDB key is not routed through verified persistence'
Need ($storefront.Contains("Set-HcApiKeyFromKeyboard 'TheGamesDbApiKey' `$Value 'TheGamesDB'")) 'TheGamesDB key is not routed through verified persistence'
Need ($storefront.Contains("'CustomizationText'")) 'global dispatcher does not route customization text'
Need ($storefront.Contains('Complete-HcCustomizationKeyboardInput $Value $Context')) 'customization domain handler is not delegated from the single dispatcher'
Need ($storefront.Contains('Set-HcPersistedConfigValue -Path $script:ConfigPath')) 'API key save does not use verified settings persistence'
Need ($store.Contains('HUYMAIER_V0308_SETTINGS_VERIFIED_VALUE_V1')) 'verified settings-value persistence marker missing'
Need ($store.Contains('function Set-HcPersistedConfigValue')) 'verified settings-value persistence helper missing'
Need ($custom.Contains('function Complete-HcCustomizationKeyboardInput')) 'customization domain keyboard handler missing'
Need (-not $custom.Contains('function Complete-NativeKeyboardInput')) 'customization still overrides the global keyboard completion dispatcher'
Need (-not $custom.Contains('HcCustomizationBaseCompleteKeyboard')) 'customization still captures/chains a previous keyboard dispatcher'
Need (-not $tasks.Contains('function Complete-NativeKeyboardInput')) 'background task module still overrides the global keyboard completion dispatcher'
Need (-not $tasks.Contains('HcBackgroundBaseCompleteKeyboard')) 'background task module still captures/chains a previous keyboard dispatcher'

$owners=New-Object System.Collections.ArrayList
foreach($file in @(Get-ChildItem -LiteralPath $root -File -Filter '*.ps1' -ErrorAction Stop)){
    $text=[IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8)
    if([regex]::IsMatch($text,'(?m)^\s*function\s+Complete-NativeKeyboardInput\s*\{')){[void]$owners.Add($file.Name)}
}
Need ($owners.Count -eq 1) ('global keyboard completion must have exactly one production owner; found '+($owners -join ', '))
Need ([string]$owners[0] -eq 'HuymaierStorefronts.ps1') ('global keyboard completion owner must be HuymaierStorefronts.ps1, found '+[string]$owners[0])

# Execute the actual settings-store helper so CI validates the same write/readback
# contract used by the API-key UI, not merely JSON serialization in isolation.
. (Join-Path $root 'HuymaierSettingsStore.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-input-authority-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $path=Join-Path $temp 'config.json'
    $config=[pscustomobject]@{SteamGridDbApiKey='';TheGamesDbApiKey='';Sentinel='keep'}
    Need (Set-HcPersistedConfigValue -Path $path -Config $config -Name 'SteamGridDbApiKey' -Value 'sgdb-ui-test-token' -Depth 16) 'SteamGridDB verified write failed'
    Need (Set-HcPersistedConfigValue -Path $path -Config $config -Name 'TheGamesDbApiKey' -Value 'tgdb-ui-test-token' -Depth 16) 'TheGamesDB verified write failed'
    $roundTrip=Read-HcPersistedConfig -Path $path
    Need ([string]$roundTrip.SteamGridDbApiKey -ceq 'sgdb-ui-test-token') 'SteamGridDB key did not survive verified readback'
    Need ([string]$roundTrip.TheGamesDbApiKey -ceq 'tgdb-ui-test-token') 'TheGamesDB key did not survive verified readback'
    Need ([string]$roundTrip.Sentinel -ceq 'keep') 'verified key write damaged unrelated settings'

    $backup=$path+'.replace-backup'
    Copy-Item -LiteralPath $path -Destination $backup -Force
    [IO.File]::WriteAllText($path,'{broken json',(New-Object Text.UTF8Encoding($true)))
    Repair-HcSettingsStoreArtifacts -Path $path
    $recovered=Read-HcPersistedConfig -Path $path
    Need ([string]$recovered.SteamGridDbApiKey -ceq 'sgdb-ui-test-token') 'settings backup recovery lost SteamGridDB key'
    Need ([string]$recovered.TheGamesDbApiKey -ceq 'tgdb-ui-test-token') 'settings backup recovery lost TheGamesDB key'
    Need (-not(Test-Path -LiteralPath $backup -PathType Leaf)) 'verified settings backup was not cleaned after recovery'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host 'v0.30.8 settings-input authority, secure paste, and verified API-key persistence validation passed.'
