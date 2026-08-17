param(
    [Parameter(Mandatory=$true)][string]$ShellRedesignPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $ShellRedesignPath -PathType Leaf)){throw "Shell source missing: $ShellRedesignPath"}
$text=[IO.File]::ReadAllText($ShellRedesignPath,[Text.Encoding]::UTF8).Replace("`r`n","`n").Replace("`r","`n")
if($text.Contains('HUYMAIER_V0303_FSE_UPDATE_HANDOFF_V1')){Write-Host 'v0.30.3 FSE updater handoff already applied.';return}

$old=@'
        $helper='"'+$script:HcSelfUpdaterPath+'"';$pkg='"'+$package.Replace('"','\"')+'"';$install='"'+$script:BaseDir.Replace('"','\"')+'"'
        $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -PackagePath $pkg -ParentProcessId $PID -InstallRoot $install"
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden|Out-Null
        $script:AllowWindowClose=$true;$script:Window.Close()
'@
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
$count=([regex]::Matches($text,[regex]::Escape($old))).Count
if($count -ne 1){throw "Expected exactly one self-update launch block, found $count."}
$text=$text.Replace($old,$new)
[IO.File]::WriteAllText($ShellRedesignPath,$text,(New-Object Text.UTF8Encoding($false)))
Write-Host 'Applied v0.30.3 Windows/Xbox FSE update handoff.'