# HUYMAIER_USER_3D_MODELS_RUNTIME_V1
# User-owned live platform model library. Large GLB assets are intentionally
# not shipped with Huymaier Console; users place their own models in the
# persistent LocalAppData 3D Models folder using the documented filenames.

Set-StrictMode -Version 2.0

$script:HcUser3DModelsRoot = Join-Path $script:DataDir '3D Models'
$script:HcUser3DModelsGuidePath = Join-Path $script:HcUser3DModelsRoot 'README - Model Names.txt'
$script:HcUserModelsBaseGetPageDefinition = ${function:Get-PageDefinition}
$script:HcUserModelsBaseInvokeAction = ${function:Invoke-Action}

function Get-HcUser3DModelNames {
    return @(
        'Arcade.glb',
        'Atari 2600.glb',
        'Atari Lynx.glb',
        'Epic Games.glb',
        'Neo Geo Pocket Color.glb',
        'Neo Geo.glb',
        'Nintendo 3DS.glb',
        'Nintendo 64.glb',
        'Nintendo DS.glb',
        'Nintendo DSI.glb',
        'Nintendo Entertainment System.glb',
        'Nintendo Game Boy Advance.glb',
        'Nintendo Game Boy Color.glb',
        'Nintendo Game Boy.glb',
        'Nintendo GameCube.glb',
        'Nintendo Switch.glb',
        'Nintendo Wii U.glb',
        'Nintendo Wii.glb',
        'PlayStation 2.glb',
        'PlayStation 3.glb',
        'Playstation 4.glb',
        'Playstation 5.glb',
        'Sega Dreamcast.glb',
        'Sega Genesis.glb',
        'Sega Logo.glb',
        'Sega Master System.glb',
        'Sega Mega Drive.glb',
        'Sega Saturn.glb',
        'Sony Playstation Portable.glb',
        'Sony Playstation Vita.glb',
        'Sony PlayStation.glb',
        'Steam.glb',
        'Super Nintendo Entertainment System.glb',
        'XBOX 360.glb',
        'Xbox One.glb',
        'Xbox.glb'
    )
}

function Initialize-HcUser3DModelsFolder {
    try {
        if(-not(Test-Path -LiteralPath $script:HcUser3DModelsRoot -PathType Container)){
            New-Item -ItemType Directory -Path $script:HcUser3DModelsRoot -Force | Out-Null
        }
        if(-not(Test-Path -LiteralPath $script:HcUser3DModelsGuidePath -PathType Leaf)){
            $lines=New-Object System.Collections.Generic.List[string]
            [void]$lines.Add('HUYMAIER CONSOLE - 3D MODELS')
            [void]$lines.Add('')
            [void]$lines.Add('Place your .glb files in this folder. Huymaier Console does not bundle large model packs.')
            [void]$lines.Add('The names below match the original Huymaier model pack exactly. Windows filename matching is case-insensitive.')
            [void]$lines.Add('Missing models simply use the normal platform/provider icon.')
            [void]$lines.Add('')
            [void]$lines.Add('Supported original filenames:')
            foreach($name in @(Get-HcUser3DModelNames)){[void]$lines.Add('  '+$name)}
            [void]$lines.Add('')
            [void]$lines.Add('You may replace any file with your own GLB while keeping the same filename.')
            [IO.File]::WriteAllLines($script:HcUser3DModelsGuidePath,[string[]]$lines.ToArray(),(New-Object Text.UTF8Encoding($false)))
        }
    } catch {
        try{Write-Log ('3D Models folder could not be prepared: '+$_.Exception.Message) 'WARN'}catch{}
    }
    return $script:HcUser3DModelsRoot
}

function Get-HcUserModelFileName {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    $frame=''
    try{$frame=Get-HcPlatformFrameName $Platform}catch{}
    try {
        $mapped=Get-HcLegacyLiveModelFileName $Platform $frame
        if(-not [string]::IsNullOrWhiteSpace($mapped)){return $mapped}
    } catch {}
    return (($Platform -replace '[\\/:*?"<>|]','_')+'.glb')
}

function Resolve-HcLivePlatformModelPath {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    [void](Initialize-HcUser3DModelsFolder)
    $names=New-Object System.Collections.Generic.List[string]
    $primary=Get-HcUserModelFileName $Platform
    if(-not [string]::IsNullOrWhiteSpace($primary)){[void]$names.Add($primary)}
    $plain=(($Platform -replace '[\\/:*?"<>|]','_')+'.glb')
    if(-not $names.Contains($plain)){[void]$names.Add($plain)}

    # A few UI names intentionally differ from the original pack names.
    switch -Regex ($Platform) {
        '^(?i)PS1|PlayStation|PlayStation 1$' {[void]$names.Add('Sony PlayStation.glb')}
        '^(?i)PS2|PlayStation 2$' {[void]$names.Add('PlayStation 2.glb')}
        '^(?i)PS3|PlayStation 3$' {[void]$names.Add('PlayStation 3.glb')}
        '^(?i)PS4|PlayStation 4$' {[void]$names.Add('Playstation 4.glb')}
        '^(?i)PS5|PlayStation 5$' {[void]$names.Add('Playstation 5.glb')}
        '^(?i)PSP|PlayStation Portable$' {[void]$names.Add('Sony Playstation Portable.glb')}
        '^(?i)Vita|PlayStation Vita$' {[void]$names.Add('Sony Playstation Vita.glb')}
        '^(?i)Original Xbox$' {[void]$names.Add('Xbox.glb')}
        '^(?i)Xbox 360$' {[void]$names.Add('XBOX 360.glb')}
        '^(?i)SNES|Super Nintendo$' {[void]$names.Add('Super Nintendo Entertainment System.glb')}
        '^(?i)GameCube$' {[void]$names.Add('Nintendo GameCube.glb')}
        '^(?i)Switch$' {[void]$names.Add('Nintendo Switch.glb')}
        '^(?i)Epic$' {[void]$names.Add('Epic Games.glb')}
    }

    foreach($name in @($names | Select-Object -Unique)){
        try {
            $candidate=Join-Path $script:HcUser3DModelsRoot $name
            if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Resolve-Path -LiteralPath $candidate).Path}
        } catch {}
    }
    return ''
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)

    # Always start from the real icon card, never the atlas/static-preview card.
    $button=$(if($null -ne $script:HcModelsBaseNewPlatformCard){& $script:HcModelsBaseNewPlatformCard $Platform $Index}else{& $script:HcLiveBaseNewPlatformCard $Platform $Index})
    if($null -eq $button){return $button}

    if((Get-HcPlatformVisualStyle) -eq 'Icons'){
        $scale=[math]::Max(.60,[math]::Min(1.80,([int]$script:Config.PlatformIconScale)/100.0))
        $button.LayoutTransform=New-Object System.Windows.Media.ScaleTransform($scale,$scale)
        return $button
    }

    $path=Resolve-HcLivePlatformModelPath $Platform
    if([string]::IsNullOrWhiteSpace($path)){
        $button.ToolTip='A/Cross Open platform   Add a matching GLB in the 3D Models folder to enable live 3D'
        return $button
    }

    $host=Get-HcPlatformVisualHost $button
    if($null -eq $host){return $button}
    $view=New-HcLiveModelView $path ([int]$script:Config.PlatformModelScale)
    if($null -eq $view){return $button}
    $host.Background='Transparent'
    $host.BorderThickness='0'
    $host.CornerRadius=0
    $host.Width=112
    $host.Height=96
    $host.Child=$view
    $button.ToolTip='A/Cross Open platform   X/Square View 3D model'
    return $button
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcUserModelsBaseGetPageDefinition $Index
    if($null -eq $page -or $Index -ne 7 -or $script:SubPage){return $page}
    $actions=New-Object System.Collections.Generic.List[object]
    $inserted=$false
    foreach($item in @($page.Actions)){
        [void]$actions.Add($item)
        $id=[string](Get-EntryProperty $item 'Id' '')
        if($id -eq 'platform-model-scale-slider'){
            [void]$actions.Add((New-Action 'open-3d-models-folder' 'Open 3D Models Folder' 'Open the persistent user model folder. Put your own .glb files here using the original Huymaier model filenames.'))
            $inserted=$true
        }
    }
    if(-not $inserted){[void]$actions.Add((New-Action 'open-3d-models-folder' 'Open 3D Models Folder' 'Open the persistent user model folder. Put your own .glb files here using the original Huymaier model filenames.'))}
    $page.Actions=[object[]]$actions.ToArray()
    return $page
}

function Invoke-Action {
    param([string]$Id)
    if($Id -eq 'open-3d-models-folder'){
        $path=Initialize-HcUser3DModelsFolder
        try {
            Start-Process explorer.exe -ArgumentList ('"'+$path+'"') | Out-Null
            try{Set-ConsoleNotice '3D Models folder opened.' 'INFO'}catch{}
        } catch {
            try{Set-ConsoleNotice ('Could not open 3D Models folder: '+$_.Exception.Message) 'ERROR'}catch{}
        }
        return
    }
    & $script:HcUserModelsBaseInvokeAction $Id
}

# Prepare the persistent folder once at startup. No large GLB assets are copied
# into the installation or user profile automatically.
[void](Initialize-HcUser3DModelsFolder)
