Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8NoBom=New-Object Text.UTF8Encoding($false)
$agent='agent/v0265-uv-alias-recomps'

function Read-HcText([string]$Path){return ([IO.File]::ReadAllText($Path)).Replace("`r`n","`n")}
function Write-HcText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`r`n","`n"),$utf8NoBom)}

$workflowNames=@(
    'validate-v0265-platform-models.yml',
    'validate-v0265-unified-cursor.yml',
    'validate-v0265-performance.yml',
    'validate-v0265-download-refresh.yml',
    'validate-v0265-gamecube.yml'
)
foreach($name in $workflowNames){
    $path=Join-Path $root ('.github\workflows\'+$name)
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Normal validation workflow missing: $name"}
    $text=Read-HcText $path
    if(-not $text.Contains(('      - '+$agent))){
        $anchor='      - feature/v0.26.5-performance-and-downloads'+"`n"
        if(-not $text.Contains($anchor)){throw "Normal workflow branch anchor missing: $name"}
        $text=$text.Replace($anchor,$anchor+'      - '+$agent+"`n")
    }
    if($name -eq 'validate-v0265-platform-models.yml'){
        $cached="            & '.\.development\v0.26.5\Test-v0265-D3D11CachedModelRender.ps1'`n"
        $uv="            & '.\.development\v0.26.5\Test-v0265-D3D11UvAddressing.ps1'`n"
        $v7="            & '.\.development\v0.26.5\Test-v0265-GpuPlatformShelvesV7.ps1'`n"
        $canonical="            & '.\.development\v0.26.5\Test-v0265-CanonicalRecomps.ps1'`n"
        if(-not $text.Contains($uv)){
            if(-not $text.Contains($cached)){throw 'Platform Models cached-render test anchor missing.'}
            $text=$text.Replace($cached,$cached+$uv)
        }
        if(-not $text.Contains($canonical)){
            if(-not $text.Contains($v7)){throw 'Platform Models V7 test anchor missing.'}
            $text=$text.Replace($v7,$v7+$canonical)
        }
    }
    Write-HcText $path $text
}

# The source transformation is now materialized in normal project files. Remove
# one-off patching machinery before the exact five-workflow source freeze.
$temporary=@(
    '.development\v0.26.5\Apply-v0265-UvAliasesRecomps.ps1',
    '.development\v0.26.5\Apply-v0265-UvAliasesRecompsV2.ps1',
    '.development\v0.26.5\Apply-v0265-UvAliasesRecompsV3.ps1',
    '.development\v0.26.5\Apply-v0265-UvAliasesRecompsV4.ps1',
    '.development\v0.26.5\Finalize-v0265-AgentNormalWorkflowValidation.ps1',
    '.github\workflows\validate-agent-v0265-uv-alias-recomps.yml'
)
foreach($relative in $temporary){
    $path=Join-Path $root $relative
    if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path -Force}
}

Write-Host 'normalWorkflowAgentBranchGate: success'
Write-Host 'normalWorkflowUvPixelGateIntegrated: success'
Write-Host 'normalWorkflowCanonicalRecompsGateIntegrated: success'
Write-Host 'temporaryUvAliasPatchMachineryPrunedGate: success'
