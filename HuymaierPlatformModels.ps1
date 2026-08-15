# HUYMAIER_PLATFORM_PRESENTATION_BASE_V2
# Stable presentation-base contract for Games platform/provider cards.
#
# This module intentionally does NOT render models, inject settings, or wrap the
# Games rail. It captures the proven shell functions before any 3D presentation
# helpers load. HuymaierUser3DModels V4 is the sole final presentation owner.

Set-StrictMode -Version 2.0

$script:HcModelsBaseNewPlatformCard=${function:New-PlatformCard}
$script:HcModelsBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcModelsBaseInvokeAction=${function:Invoke-Action}
$script:HcModelsBaseAddPlatformRail=${function:Add-PlatformRail}
$script:HcModelsBaseUpdateActionVisuals=${function:Update-ActionVisuals}

function Initialize-HcPlatformModelConfig {
    if($null -eq $script:Config.PSObject.Properties['PlatformVisualStyle']){$script:Config|Add-Member -NotePropertyName 'PlatformVisualStyle' -NotePropertyValue 'Icons' -Force}
    if($null -eq $script:Config.PSObject.Properties['PlatformIconScale']){$script:Config|Add-Member -NotePropertyName 'PlatformIconScale' -NotePropertyValue 100 -Force}
    if($null -eq $script:Config.PSObject.Properties['PlatformModelScale']){$script:Config|Add-Member -NotePropertyName 'PlatformModelScale' -NotePropertyValue 100 -Force}
    if([string]$script:Config.PlatformVisualStyle -notin @('Icons','3D Models')){$script:Config.PlatformVisualStyle='Icons'}
    try{$script:Config.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$script:Config.PlatformIconScale))}catch{$script:Config.PlatformIconScale=100}
    try{$script:Config.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))}catch{$script:Config.PlatformModelScale=100}
}

function Get-HcPlatformVisualStyle {
    Initialize-HcPlatformModelConfig
    return [string]$script:Config.PlatformVisualStyle
}

Initialize-HcPlatformModelConfig
