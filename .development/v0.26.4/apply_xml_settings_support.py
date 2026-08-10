from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorSettings.ps1';text=path.read_text(encoding='utf-8-sig')
functions=r'''
function Get-HcXmlNodePath {
    param([Xml.XmlNode]$Node)
    if($null -eq $Node -or $Node.NodeType -eq [Xml.XmlNodeType]::Document){return ''}
    $parent=$Node.ParentNode;$segment=$Node.Name
    if($null -ne $parent){$same=@($parent.ChildNodes|Where-Object{$_.NodeType -eq [Xml.XmlNodeType]::Element -and $_.Name -eq $Node.Name});if($same.Count -gt 1){$index=1;foreach($candidate in $same){if([object]::ReferenceEquals($candidate,$Node)){break};$index++};$segment+="[$index]"}}
    $base=Get-HcXmlNodePath $parent
    return $(if($base){$base+'/'+$segment}else{'/'+$segment})
}
function Add-HcXmlSettingRecords {
    param([Xml.XmlNode]$Node,[string]$FilePath,[string]$AdapterId,[Collections.ArrayList]$Result)
    if($null -eq $Node){return}
    if($Node.NodeType -eq [Xml.XmlNodeType]::Element){
        $nodePath=Get-HcXmlNodePath $Node
        foreach($attribute in @($Node.Attributes)){[void]$Result.Add((New-HcEmulatorSettingRecord -Format 'xml' -FilePath $FilePath -Section $nodePath -Key ('@'+$attribute.Name) -Value ([string]$attribute.Value) -LineIndex -1 -AdapterId $AdapterId))}
        $elementChildren=@($Node.ChildNodes|Where-Object{$_.NodeType -eq [Xml.XmlNodeType]::Element})
        if($elementChildren.Count -eq 0){$value=[string]$Node.InnerText;[void]$Result.Add((New-HcEmulatorSettingRecord -Format 'xml' -FilePath $FilePath -Section $nodePath -Key '#text' -Value $value -LineIndex -1 -AdapterId $AdapterId))}
    }
    foreach($child in @($Node.ChildNodes)){if($child.NodeType -eq [Xml.XmlNodeType]::Element){Add-HcXmlSettingRecords -Node $child -FilePath $FilePath -AdapterId $AdapterId -Result $Result}}
}
function Get-HcXmlSettings {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]@()}
    try{$doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($Path)}catch{Write-Log "Could not parse XML emulator config ${Path}: $($_.Exception.Message)" 'WARN';return [object[]]@()}
    $result=New-Object Collections.ArrayList;Add-HcXmlSettingRecords -Node $doc.DocumentElement -FilePath $Path -AdapterId $AdapterId -Result $result;return [object[]]$result.ToArray()
}
function Set-HcXmlSetting {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Section,[Parameter(Mandatory=$true)][string]$Key,[AllowEmptyString()][string]$Value,[string]$AdapterId='')
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "XML emulator config file was not found: $Path"};[void](Backup-HcEmulatorConfigFile -Path $Path -AdapterId $AdapterId)
    $doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($Path);$node=$doc.SelectSingleNode($Section);if($null -eq $node){throw "XML setting path no longer exists: $Section"}
    if($Key -eq '#text'){$node.InnerText=$Value}elseif($Key.StartsWith('@')){$name=$Key.Substring(1);$attribute=$node.Attributes[$name];if($null -eq $attribute){throw "XML attribute no longer exists: $Key"};$attribute.Value=$Value}else{throw "Unsupported XML setting key: $Key"}
    $encoding=Get-HcSettingsFileEncoding $Path;$settings=New-Object Xml.XmlWriterSettings;$settings.Indent=$false;$settings.OmitXmlDeclaration=$false;$settings.Encoding=$encoding;$writer=[Xml.XmlWriter]::Create($Path,$settings);try{$doc.Save($writer)}finally{$writer.Close()}
}

'''
if 'function Get-HcXmlSettings {' not in text:
    anchor='function Get-HcTomlScalarSettings {'
    if text.count(anchor)!=1:raise SystemExit('XML function insertion anchor missing')
    text=text.replace(anchor,functions+anchor,1)
text=text.replace("elseif($ext -eq '.toml'){$Format='toml'}elseif($ext -eq '.bml')", "elseif($ext -eq '.toml'){$Format='toml'}elseif($ext -eq '.xml'){$Format='xml'}elseif($ext -eq '.bml')")
if "'xml' { return [object[]](Get-HcXmlSettings" not in text:text=text.replace("        'toml' { return [object[]](Get-HcTomlScalarSettings -Path $Path -AdapterId $AdapterId) }\n", "        'toml' { return [object[]](Get-HcTomlScalarSettings -Path $Path -AdapterId $AdapterId) }\n        'xml' { return [object[]](Get-HcXmlSettings -Path $Path -AdapterId $AdapterId) }\n",1)
if "'xml' { Set-HcXmlSetting" not in text:text=text.replace("        'toml' { Set-HcTomlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }\n", "        'toml' { Set-HcTomlScalarSetting -Path $path -LineIndex $line -Key $key -Value $Value -AdapterId $adapter }\n        'xml' { Set-HcXmlSetting -Path $path -Section $section -Key $key -Value $Value -AdapterId $adapter }\n",1)
path.write_text(text,encoding='utf-8');print('materialized unknown-node-preserving XML emulator settings support')
