Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Apply-v0265-NamingRecompsFixes.ps1'
$raw=[IO.File]::ReadAllText($source).Replace("`r`n","`n")
$replacement=@'
$switchNew=@'
    switch($Id){
        'provider-recomps-folder'{
            $root=''
            foreach($entry in @($script:Config.ProviderInstallRoots)){if($null-ne$entry-and[string]::Equals([string](Get-EntryProperty $entry 'Provider' ''),'Recomps',[StringComparison]::OrdinalIgnoreCase)){$root=[string](Get-EntryProperty $entry 'Path' '');break}}
            $args=@{Mode='PickFolder';Store='Recomps';EntryType='ProviderInstall';ReturnTab=1};if($root){$args.StartPath=$root};Start-NativeFilePicker @args;return $true
        }
        'provider-recomps-open-folder'{
            $game=Get-SelectedProviderGame;$path=[string](Get-EntryProperty $game 'InstallPath' (Get-EntryProperty $game 'Path' ''))
            if($path-and(Test-Path -LiteralPath $path -PathType Container)){Start-Process explorer.exe -ArgumentList $path|Out-Null}
            return $true
        }
        'provider-hes-url'{
'@
'@
$rx=New-Object Text.RegularExpressions.Regex('(?m)^\$switchNew=.*$')
if(-not$rx.IsMatch($raw)){throw 'Naming/Recomps V1 switchNew repair anchor missing.'}
$fixed=$rx.Replace($raw,$replacement,1)
$temp=Join-Path $env:TEMP ('hc-naming-recomps-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{[IO.File]::WriteAllText($temp,$fixed,(New-Object Text.UTF8Encoding($false)));& $temp}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
