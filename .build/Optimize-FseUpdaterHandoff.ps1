param(
    [Parameter(Mandatory=$true)][string]$ShellRedesignPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $ShellRedesignPath -PathType Leaf)){throw "Shell source missing: $ShellRedesignPath"}
$text=[IO.File]::ReadAllText($ShellRedesignPath,[Text.Encoding]::UTF8).Replace("`r`n","`n").Replace("`r","`n")
if($text.Contains('HUYMAIER_V0303_FSE_UPDATE_HANDOFF_V1')){Write-Host 'v0.30.3 FSE updater handoff already applied.';return}

# Match only the self-update helper-launch block, independent of the exact quote
# escaping used by the surrounding source. Both boundary lines are unique inside
# Start-HcConsoleSelfUpdate.
$pattern='(?ms)^        \$helper=.*?^        \$script:AllowWindowClose=\$true;\$script:Window\.Close\(\)'
$matches=[regex]::Matches($text,$pattern)
if($matches.Count -ne 1){throw "Expected exactly one self-update launch block, found $($matches.Count)."}

$new=@'
        # HUYMAIER_V0303_FSE_UPDATE_HANDOFF_V1
        $helper='"'+$script:HcSelfUpdaterPath+'"';$pkg='"'+$package.Replace('"','\"')+'"';$install='"'+$script:BaseDir.Replace('"','\"')+'"'
        $fseManaged=[string]::Equals([Environment]::GetEnvironmentVariable('HUYMAIER_FSE_HOST'),'1',[StringComparison]::Ordinal)
        $handoff=''
        if($fseManaged){
            $handoff=Join-Path $env:LOCALAPPDATA 'HuymaierConsoleFseUpdate.lock'
            [IO.File]::WriteAllText($handoff,($PID.ToString()+'|'+[DateTime]::UtcNow.ToString('o')),(New-Object Text.UTF8Encoding($false)))
        }
        $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -PackagePath $pkg -ParentProcessId $PID -InstallRoot $install"
        if($fseManaged){$arguments+=' -FseManaged -HandoffPath "'+$handoff.Replace('"','\"')+'"'}
        try{
            Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden|Out-Null
        }catch{
            if($fseManaged -and $handoff){Remove-Item -LiteralPath $handoff -Force -ErrorAction SilentlyContinue}
            throw
        }
        $script:AllowWindowClose=$true;$script:Window.Close()
'@
$text=$text.Substring(0,$matches[0].Index)+$new+$text.Substring($matches[0].Index+$matches[0].Length)
[IO.File]::WriteAllText($ShellRedesignPath,$text,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Applied v0.30.3 Windows/Xbox FSE update handoff.'