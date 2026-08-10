#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierColorPicker.ps1'
text=path.read_text(encoding='utf-8-sig')

def once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    text=text.replace(old,new,1)

once("$script:HcColorPickerApplied=$false\n", "$script:HcColorPickerApplied=$false\n$script:HcColorPickerSwatchIndex=0\n", 'swatch state declaration')
once("    $swatchIndex=0\n    for($i=0;$i -lt $swatches.Count;$i++){if([string]::Equals($swatches[$i],$InitialColor,[StringComparison]::OrdinalIgnoreCase)){$swatchIndex=$i;break}}\n", "    $script:HcColorPickerSwatchIndex=0\n    for($i=0;$i -lt $swatches.Count;$i++){if([string]::Equals($swatches[$i],$InitialColor,[StringComparison]::OrdinalIgnoreCase)){$script:HcColorPickerSwatchIndex=$i;break}}\n", 'swatch initialization')
once("    $jumpSwatch={param([int]$delta)\n        $swatchIndex=($swatchIndex+$delta+$swatches.Count)%$swatches.Count\n        Set-HcColorPickerVectorFromHex $swatches[$swatchIndex]\n        & $refresh\n    }\n", "    $jumpSwatch={param([int]$delta)\n        $script:HcColorPickerSwatchIndex=($script:HcColorPickerSwatchIndex+$delta+$swatches.Count)%$swatches.Count\n        Set-HcColorPickerVectorFromHex $swatches[$script:HcColorPickerSwatchIndex]\n        & $refresh\n    }\n", 'swatch navigation')
once("    $window.Content=$root\n\n    $swatches=", "    $window.Content=$root\n    $window.Add_Activated({try{$window.Focus()}catch{}})\n\n    $swatches=", 'picker activation focus')
path.write_text(text,encoding='utf-8-sig',newline='\n')
print('Hardened v0.26.2 controller color wheel state and focus.')
