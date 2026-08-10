param(
    [Parameter(Mandatory=$true)][int]$ParentProcessId,
    [Parameter(Mandatory=$true)][string]$RestorePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'

# This helper owns no Huymaier state. It simply waits for the exact Console
# process that started it to exit, then asks the idempotent restore helper to
# recover any controller-to-Xbox-Game-Bar setting left suppressed by an
# abnormal exit. Normal shutdown restores first, so this becomes a no-op.
while($true){
    try{
        [void](Get-Process -Id $ParentProcessId -ErrorAction Stop)
    }catch{
        break
    }
    Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 200
if(Test-Path -LiteralPath $RestorePath -PathType Leaf){
    try{& $RestorePath -Quiet}catch{}
}
exit 0
