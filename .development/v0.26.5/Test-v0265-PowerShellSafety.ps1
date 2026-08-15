Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceList=Join-Path $root '.source\source-files.txt'
if(-not(Test-Path -LiteralPath $sourceList -PathType Leaf)){throw 'Release source list is missing.'}

# These automatic variables are runtime-owned and must never be repurposed as
# parameters, loop variables, assignment targets, or Set/New/Clear/Remove-Variable
# targets. PowerShell is case-insensitive: $host collides with read-only $Host.
$protected=@('Host','PID','PSVersionTable','PSScriptRoot','PSCommandPath','MyInvocation')
$protectedLookup=@{}
foreach($name in $protected){$protectedLookup[$name.ToLowerInvariant()]=$true}

function Get-HcVariableBaseName {
    param($VariableExpression)
    if($null -eq $VariableExpression){return ''}
    $name=[string]$VariableExpression.VariablePath.UserPath
    if([string]::IsNullOrWhiteSpace($name)){return ''}
    $colon=$name.LastIndexOf(':')
    if($colon -ge 0 -and $colon -lt ($name.Length-1)){$name=$name.Substring($colon+1)}
    return $name
}
function Assert-HcSafeVariableTarget {
    param([string]$Relative,[string]$Kind,$VariableExpression)
    $name=Get-HcVariableBaseName $VariableExpression
    if(-not $name){return}
    if($protectedLookup.ContainsKey($name.ToLowerInvariant())){
        $line=0;try{$line=[int]$VariableExpression.Extent.StartLineNumber}catch{}
        throw "$Relative line $line uses protected automatic variable `$${name} as a $Kind target. Rename it; PowerShell variable names are case-insensitive."
    }
}

$files=New-Object System.Collections.Generic.List[string]
foreach($line in @(Get-Content -LiteralPath $sourceList -Encoding UTF8)){
    $relative=[string]$line
    if([string]::IsNullOrWhiteSpace($relative)-or-not$relative.EndsWith('.ps1',[StringComparison]::OrdinalIgnoreCase)){continue}
    [void]$files.Add($relative)
}
if($files.Count -lt 20){throw "PowerShell safety audit found only $($files.Count) shipped scripts; source-list coverage is unexpectedly small."}

foreach($relative in $files){
    $path=Join-Path $root $relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Shipped PowerShell runtime is missing: $relative"}
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$relative failed PowerShell 5.1 parse during safety audit: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}

    foreach($parameter in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.ParameterAst]},$true))){
        Assert-HcSafeVariableTarget $relative 'parameter' $parameter.Name
    }
    foreach($assignment in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.AssignmentStatementAst]},$true))){
        foreach($variable in @($assignment.Left.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true))){
            Assert-HcSafeVariableTarget $relative 'assignment' $variable
        }
    }
    foreach($loop in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.ForEachStatementAst]},$true))){
        Assert-HcSafeVariableTarget $relative 'foreach loop variable' $loop.Variable
    }

    # Catch dynamic variable mutation that does not appear as an assignment AST.
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($name in $protected){
        $escaped=[regex]::Escape($name)
        $patterns=@(
            "(?im)\b(?:Set|New|Clear|Remove)-Variable\b[^\r\n]*(?:-Name\s+)?['\"]?(?:global:|script:|local:)?$escaped\b",
            "(?im)\bSet-Item\s+(?:-Path\s+)?['\"]?Variable:(?:global:|script:|local:)?$escaped\b"
        )
        foreach($pattern in $patterns){if([regex]::IsMatch($raw,$pattern)){throw "$relative dynamically mutates protected automatic variable `$${name}."}}
    }
}

Write-Host ('powerShellSafetyFilesAudited: '+$files.Count)
Write-Host 'powerShellProtectedAutomaticVariableGate: success'
Write-Host 'powerShellParseSafetyGate: success'
