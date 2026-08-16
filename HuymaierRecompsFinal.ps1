# Huymaier Console final Recomps ownership layer.
# Loaded after the V7 GPU shelf runtime in release-shaped builds. The main
# manual module is loaded earlier by customization; this file only reclaims the
# three functions V7 historically wrapped for the obsolete root-folder scanner.
Set-StrictMode -Version 2.0

if(-not(Get-Command Get-HcManualRecompGames -ErrorAction SilentlyContinue)){throw 'Manual Recomps runtime was not loaded before final ownership.'}
if(-not(Get-Variable HcManualRecompsBaseGetPageDefinition -Scope Script -ErrorAction SilentlyContinue)){throw 'Manual Recomps page base is unavailable.'}
if(-not(Get-Variable HcManualRecompsBaseInvokeAction -Scope Script -ErrorAction SilentlyContinue)){throw 'Manual Recomps action base is unavailable.'}

# V7 Get-AllGameHubEntries resolves this function dynamically. Re-establishing
# it here makes the explicit persisted list authoritative after V7 loads.
function Get-HcRecompGames {
    return [object[]]@(Get-HcManualRecompGames)
}

# V7's only page wrapper added the retired Recomps root-folder setting. Use the
# pre-V7 customization page contract instead and keep that obsolete setting out.
function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcManualRecompsBaseGetPageDefinition $Index
    if($Index -eq 7 -and $null-ne$page -and $null-ne$page.PSObject.Properties['Actions']){
        $filtered=New-Object System.Collections.ArrayList
        foreach($action in @($page.Actions)){
            if($null-eq$action){continue}
            if([string]::Equals([string](Get-EntryProperty $action 'Id' ''),'recomps-root',[StringComparison]::OrdinalIgnoreCase)){continue}
            [void]$filtered.Add($action)
        }
        $page.Actions=[object[]]$filtered.ToArray()
    }
    return $page
}

# Keep a stale/legacy recomps-root action safe if it is ever invoked by old
# navigation state, but otherwise use the pre-V7 customization action contract.
function Invoke-Action {
    param([string]$Id)
    if([string]::Equals($Id,'recomps-root',[StringComparison]::OrdinalIgnoreCase)){
        Start-HcManualRecompPicker
        return
    }
    & $script:HcManualRecompsBaseInvokeAction $Id
}

$script:HcManualRecompsFinalOwner='HuymaierRecompsFinal'
