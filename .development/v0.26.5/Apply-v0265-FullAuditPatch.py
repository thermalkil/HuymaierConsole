from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def replace(path, old, new, count=1):
    p=ROOT/path
    text=p.read_text(encoding='utf-8-sig')
    actual=text.count(old)
    if actual!=count:
        raise RuntimeError(f'{path}: expected {count} occurrence(s), found {actual}: {old[:100]!r}')
    text=text.replace(old,new)
    p.write_text(text,encoding='utf-8')

# Generated provider/console stand-ins are authored with their front details on
# +Z, while the shared shelf camera begins on -Z. Rotate the generated root once
# so branded/material faces (for example GOG purple) actually face the user.
replace(Path('Native/HuymaierBuiltInModelGenerator.cs'),
        '\\"nodes\\":[{\\"mesh\\":0,\\"name\\":\\""+name+"\\"}],\\"meshes\\":[{',
        '\\"nodes\\":[{\\"mesh\\":0,\\"name\\":\\""+name+"\\",\\"rotation\\":[0,1,0,0]}],\\"meshes\\":[{')

# Visible platform names are presentation only. Internal platform strings stay
# untouched so emulator routing/selection behavior does not change.
user=Path('HuymaierUser3DModels.ps1')
p=ROOT/user
text=p.read_text(encoding='utf-8-sig')
anchor="function Get-HcPlatformVisualStyle {Initialize-HcPlatformPresentationConfig;return [string]$script:Config.PlatformVisualStyle}\n"
if anchor not in text: raise RuntimeError('display-name helper anchor missing')
helper=r'''

$script:HcPlatformDisplayLabelMap=$null
function Initialize-HcPlatformDisplayLabelMap {
    if($null-ne$script:HcPlatformDisplayLabelMap){return}
    $map=@{}
    try{
        $registryPath=Join-Path $script:BaseDir 'EmulatorPlatforms\platform-registry.json'
        if(Test-Path -LiteralPath $registryPath -PathType Leaf){
            $registry=Get-Content -Raw -LiteralPath $registryPath -Encoding UTF8|ConvertFrom-Json
            foreach($platform in @($registry.platforms)){
                if($null-eq$platform){continue}
                $display=[string](Get-EntryProperty $platform 'displayName' '')
                if([string]::IsNullOrWhiteSpace($display)){$display=[string](Get-EntryProperty $platform 'name' '')}
                if([string]::IsNullOrWhiteSpace($display)){continue}
                $keys=New-Object System.Collections.ArrayList
                foreach($field in @('name','menuName','displayName')){$value=[string](Get-EntryProperty $platform $field '');if(-not[string]::IsNullOrWhiteSpace($value)){[void]$keys.Add($value)}}
                foreach($alias in @((Get-EntryProperty $platform 'aliases' @()))){if(-not[string]::IsNullOrWhiteSpace([string]$alias)){[void]$keys.Add([string]$alias)}}
                foreach($key in @($keys)){$normalized=([string]$key).Trim().ToLowerInvariant();if($normalized-and-not$map.ContainsKey($normalized)){$map[$normalized]=$display}}
            }
        }
    }catch{try{Write-Log ('Platform display-name map failed: '+$_.Exception.Message) 'WARN'}catch{}}
    $script:HcPlatformDisplayLabelMap=$map
}
function Get-HcPlatformDisplayLabel {
    param([string]$Platform,[string]$Group='')
    if([string]::IsNullOrWhiteSpace($Platform)){return $Platform}
    if([string]::Equals($Group,'Providers',[StringComparison]::OrdinalIgnoreCase)){
        switch($Platform.Trim().ToLowerInvariant()){
            'steam' {return 'Steam'}
            'epic' {return 'Epic Games'}
            'epic games' {return 'Epic Games'}
            'gog' {return 'GOG'}
            'ea' {return 'EA'}
            'ea app' {return 'EA'}
            'ubisoft' {return 'Ubisoft Connect'}
            'ubisoft connect' {return 'Ubisoft Connect'}
            'xbox' {return 'Xbox PC'}
            'xbox app' {return 'Xbox PC'}
            'microsoft gaming app' {return 'Xbox PC'}
            'battle.net' {return 'Battle.net'}
            'battlenet' {return 'Battle.net'}
            'rockstar' {return 'Rockstar Games'}
            'rockstar games' {return 'Rockstar Games'}
            'amazon' {return 'Amazon Games'}
            'amazon games' {return 'Amazon Games'}
            'recomps' {return 'Recomps'}
        }
    }
    Initialize-HcPlatformDisplayLabelMap
    $key=$Platform.Trim().ToLowerInvariant()
    if($script:HcPlatformDisplayLabelMap.ContainsKey($key)){return [string]$script:HcPlatformDisplayLabelMap[$key]}
    return $Platform
}
'''
text=text.replace(anchor,anchor+helper,1)
# V6 card/header/action visible labels.
old="$label.Text=$Platform;$label.FontSize=11;$label.FontWeight='SemiBold';$label.Foreground='White'"
new="$displayName=Get-HcPlatformDisplayLabel $Platform $Group`r`n    $label.Text=$displayName;$label.FontSize=11;$label.FontWeight='SemiBold';$label.Foreground='White'"
if text.count(old)!=1: raise RuntimeError('V6 label anchor mismatch')
text=text.replace(old,new,1)
old="Platform=$Platform;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count"
new="Platform=$Platform;DisplayName=$displayName;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count"
if text.count(old)!=1: raise RuntimeError('V6 card property anchor mismatch')
text=text.replace(old,new,1)
old="$group.Header.Text=$(if($null-ne$selectedCard){$group.Title+'   •   '+$selectedCard.Platform}else{$group.Title})"
new="$group.Header.Text=$(if($null-ne$selectedCard){$group.Title+'   •   '+$selectedCard.DisplayName}else{$group.Title})"
if text.count(old)!=1: raise RuntimeError('V6 header anchor mismatch')
text=text.replace(old,new,1)
old="$script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) $platform)"
new="$script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) ([string]$card.DisplayName))"
if text.count(old)!=1: raise RuntimeError('V6 action label anchor mismatch')
text=text.replace(old,new,1)
p.write_text(text,encoding='utf-8')

# V7 uses the same presentation helper while retaining internal platform names.
v7=ROOT/'HuymaierGpuPlatformShelves.ps1'
text=v7.read_text(encoding='utf-8-sig')
if text.count("if($reader.ReadInt32()-ne2){return $false}")!=1: raise RuntimeError('V7 cache-version anchor mismatch')
text=text.replace("if($reader.ReadInt32()-ne2){return $false}","if($reader.ReadInt32()-ne3){return $false}",1)
old="$label=New-Object System.Windows.Controls.TextBlock;$label.Text=$Platform;$label.FontSize=13;"
new="$displayName=Get-HcPlatformDisplayLabel $Platform $Group`r`n    $label=New-Object System.Windows.Controls.TextBlock;$label.Text=$displayName;$label.FontSize=13;"
if text.count(old)!=1: raise RuntimeError('V7 label anchor mismatch')
text=text.replace(old,new,1)
old="Platform=$Platform;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count;Path=$path;"
new="Platform=$Platform;DisplayName=$displayName;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count;Path=$path;"
if text.count(old)!=1: raise RuntimeError('V7 card property anchor mismatch')
text=text.replace(old,new,1)
old="$Group.Header.Text=$(if($selectedCard){$Group.Title+'   •   '+$selectedCard.Platform}else{$Group.Title})"
new="$Group.Header.Text=$(if($selectedCard){$Group.Title+'   •   '+$selectedCard.DisplayName}else{$Group.Title})"
if text.count(old)!=1: raise RuntimeError('V7 header anchor mismatch')
text=text.replace(old,new,1)
old="$script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) $platform)"
new="$script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) ([string]$card.DisplayName))"
if text.count(old)!=1: raise RuntimeError('V7 action label anchor mismatch')
text=text.replace(old,new,1)
v7.write_text(text,encoding='utf-8')

# Full-screen WPF fallback: use glTF-spec metallic/roughness defaults and apply
# baseColorFactor/alpha to textured pixels rather than silently discarding tint.
preview=ROOT/'Native/HuymaierModelPreviewWorker.cs'
text=preview.read_text(encoding='utf-8-sig')
text=text.replace('double metallic = JsonUtil.Double(pbr, "metallicFactor", 0.0);','double metallic = JsonUtil.Double(pbr, "metallicFactor", 1.0);',1)
text=text.replace('double roughness = JsonUtil.Double(pbr, "roughnessFactor", 0.70);','double roughness = JsonUtil.Double(pbr, "roughnessFactor", 1.0);',1)
create_anchor='''        private static double AverageFactor(object[] values, double fallback)\n        {\n'''
if create_anchor not in text: raise RuntimeError('preview tint helper anchor missing')
tint=r'''        private static BitmapSource ApplyBaseColor(BitmapSource bitmap, Color factor, string alphaMode, double cutoff)
        {
            if (bitmap == null) return null;
            BitmapSource source = bitmap.Format == PixelFormats.Bgra32 ? bitmap : new FormatConvertedBitmap(bitmap, PixelFormats.Bgra32, null, 0);
            int width=source.PixelWidth,height=source.PixelHeight,stride=width*4;
            byte[] pixels=new byte[stride*height]; source.CopyPixels(pixels,stride,0);
            bool blend=String.Equals(alphaMode,"BLEND",StringComparison.OrdinalIgnoreCase);
            bool mask=String.Equals(alphaMode,"MASK",StringComparison.OrdinalIgnoreCase);
            int cutoffByte=(int)Math.Max(0,Math.Min(255,cutoff*255.0));
            for(int i=0;i<pixels.Length;i+=4)
            {
                pixels[i]=(byte)((pixels[i]*factor.B+127)/255);
                pixels[i+1]=(byte)((pixels[i+1]*factor.G+127)/255);
                pixels[i+2]=(byte)((pixels[i+2]*factor.R+127)/255);
                int alpha=(pixels[i+3]*factor.A+127)/255;
                pixels[i+3]=(byte)(mask?(alpha>=cutoffByte?255:0):(blend?alpha:255));
            }
            BitmapSource result=BitmapSource.Create(width,height,source.DpiX,source.DpiY,PixelFormats.Bgra32,null,pixels,stride);
            if(result.CanFreeze)result.Freeze();return result;
        }

'''
text=text.replace(create_anchor,tint+create_anchor,1)
old='''            string alphaMode = Convert.ToString(JsonUtil.Get(material, "alphaMode"), CultureInfo.InvariantCulture) ?? "OPAQUE";\n            bool transparent = String.Equals(alphaMode, "BLEND", StringComparison.OrdinalIgnoreCase) ||\n                               String.Equals(alphaMode, "MASK", StringComparison.OrdinalIgnoreCase);\n            double materialOpacity = transparent ? color.A / 255.0 : 1.0;\n'''
new='''            string alphaMode = Convert.ToString(JsonUtil.Get(material, "alphaMode"), CultureInfo.InvariantCulture) ?? "OPAQUE";\n            bool blend = String.Equals(alphaMode, "BLEND", StringComparison.OrdinalIgnoreCase);\n            bool mask = String.Equals(alphaMode, "MASK", StringComparison.OrdinalIgnoreCase);\n            double alphaCutoff = JsonUtil.Double(material, "alphaCutoff", 0.5);\n            double materialOpacity = blend ? color.A / 255.0 : 1.0;\n'''
if text.count(old)!=1: raise RuntimeError('preview alpha anchor mismatch')
text=text.replace(old,new,1)
old='''            if (baseBitmap != null)\n            {\n                diffuseBrush = CreateImageBrush(baseBitmap, materialOpacity);\n            }\n'''
new='''            if (baseBitmap != null)\n            {\n                baseBitmap = ApplyBaseColor(baseBitmap, color, alphaMode, alphaCutoff);\n                diffuseBrush = CreateImageBrush(baseBitmap, 1.0);\n            }\n'''
if text.count(old)!=1: raise RuntimeError('preview texture color anchor mismatch')
text=text.replace(old,new,1)
old='''            MaterialGroup group = new MaterialGroup();\n            group.Children.Add(new DiffuseMaterial(diffuseBrush));\n\n            Dictionary<string, object> unlit = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_unlit"));\n            if (unlit.Count == 0)\n'''
new='''            MaterialGroup group = new MaterialGroup();\n            Dictionary<string, object> unlit = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_unlit"));\n            if (unlit.Count > 0) group.Children.Add(new EmissiveMaterial(diffuseBrush));\n            else group.Children.Add(new DiffuseMaterial(diffuseBrush));\n\n            if (unlit.Count == 0)\n'''
if text.count(old)!=1: raise RuntimeError('preview unlit anchor mismatch')
text=text.replace(old,new,1)
preview.write_text(text,encoding='utf-8')

# Viewer title should use the same full canonical presentation name.
live=ROOT/'HuymaierLivePlatformModels.ps1'
text=live.read_text(encoding='utf-8-sig')
old="$title.Text=$Platform+' — 3D MODEL';$title.FontSize=30;"
new="$viewerGroup=$(if(Test-HcStorefrontPlatform $Platform){'Providers'}else{'Consoles'})`r`n    $title.Text=(Get-HcPlatformDisplayLabel $Platform $viewerGroup)+' — 3D MODEL';$title.FontSize=30;"
if text.count(old)!=1: raise RuntimeError('viewer title anchor mismatch')
text=text.replace(old,new,1)
live.write_text(text,encoding='utf-8')

print('fullAuditPatchApplied: success')
