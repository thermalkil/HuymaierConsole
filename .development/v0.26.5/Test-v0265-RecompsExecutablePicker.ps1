param(
    [string]$CorePath,
    [string]$ManualPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($CorePath)-or[string]::IsNullOrWhiteSpace($ManualPath)){
    $root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    if([string]::IsNullOrWhiteSpace($CorePath)){$CorePath=Join-Path $root 'HuymaierConsole.ps1'}
    if([string]::IsNullOrWhiteSpace($ManualPath)){$ManualPath=Join-Path $root 'HuymaierRecompsManual.ps1'}
}
foreach($p in @($CorePath,$ManualPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Recomps picker regression input missing: $p"}}

function Import-HcFunctionFromFile([string]$Path,[string]$Name){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$Path failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
    $fn=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and [string]::Equals($n.Name,$Name,[StringComparison]::OrdinalIgnoreCase)},$true)|Select-Object -Last 1)
    if($fn.Count-ne1){throw "Could not isolate $Name from $Path"}
    Invoke-Expression $fn[0].Extent.Text
}

# Use the actual core browser implementation instead of a mock. RecompsManual
# captures it and layers its exact-EXE visibility repair over this function.
Import-HcFunctionFromFile $CorePath 'Format-FileSize'
Import-HcFunctionFromFile $CorePath 'Get-FileBrowserItems'
function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p){return $Default};return $p.Value}
function Get-GameProviderDefinitions {return @()}
function Get-ProviderCatalogNode {param([string]$Provider);return $null}
function Add-ProviderControlRail {param([string]$Provider)}
function Render-GameProviderStore {param([string]$Provider)}
function Get-GameProviderPageDefinition {return $null}
function Invoke-GameProviderAction {param([string]$Id);return $false}
function Complete-ProviderConfirmation {param([string]$Action);return $false}
function Complete-NativeFileSelection {param($Entry)}
function Get-PageDefinition {param([int]$Index);return $null}
function Invoke-Action {param([string]$Id)}
function Write-Log {param([string]$Message,[string]$Level='INFO')}

. $ManualPath
$manual=Get-Content -Raw -LiteralPath $ManualPath -Encoding UTF8
foreach($needle in @('HUYMAIER_RECOMPS_EXE_PICKER_VISIBILITY_V2','HcManualRecompsBaseGetFileBrowserItems','Get-ChildItem -LiteralPath $script:FileBrowserPath -Force -File -Filter ''*.exe''')){if($manual.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Recomps EXE picker visibility contract missing: $needle"}}

$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-recomps-picker-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $visible=Join-Path $temp 'VisibleGame.exe';$hidden=Join-Path $temp 'HiddenGame.exe';$txt=Join-Path $temp 'Readme.txt';$lnk=Join-Path $temp 'WrongShortcut.lnk'
    [IO.File]::WriteAllBytes($visible,[byte[]](0x4D,0x5A,0x00,0x00))
    [IO.File]::WriteAllBytes($hidden,[byte[]](0x4D,0x5A,0x00,0x00))
    [IO.File]::WriteAllText($txt,'not a game executable')
    [IO.File]::WriteAllText($lnk,'not accepted for Recomps')
    [IO.File]::SetAttributes($hidden,[IO.FileAttributes]::Hidden)

    $script:FileBrowserPath=$temp
    $script:FileBrowserMode='PickExecutable'
    $script:FileBrowserEntryType='RecompGame'
    $items=[object[]]@(Get-FileBrowserItems)
    $names=@($items|Where-Object{[string](Get-EntryProperty $_ 'Type' '')-eq'File'}|ForEach-Object{[string](Get-EntryProperty $_ 'Name' '')})
    foreach($required in @('VisibleGame.exe','HiddenGame.exe')){if($names-notcontains$required){throw "Recomps native browser did not expose required executable: $required. Files: $($names -join ', ')"}}
    foreach($forbidden in @('Readme.txt','WrongShortcut.lnk')){if($names-contains$forbidden){throw "Recomps native browser exposed non-EXE selection: $forbidden"}}
    if(@($names|Where-Object{$_-match'(?i)\.exe$'}).Count-ne2){throw "Recomps picker returned an unexpected EXE set: $($names -join ', ')"}

    Write-Host 'recompsNativeBrowserVisibleExeGate: success'
    Write-Host 'recompsNativeBrowserHiddenExeGate: success'
    Write-Host 'recompsNativeBrowserExeOnlyGate: success'
}finally{
    try{[IO.File]::SetAttributes($hidden,[IO.FileAttributes]::Normal)}catch{}
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
