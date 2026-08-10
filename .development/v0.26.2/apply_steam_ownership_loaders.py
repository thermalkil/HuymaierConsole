#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(path): return path.read_text(encoding='utf-8-sig')
def write(path,text): path.write_text(text,encoding='utf-8-sig',newline='\n')
def once(path,old,new,label):
    text=read(path);count=text.count(old)
    if count!=1: raise SystemExit(f'{label}: expected one match, found {count}')
    write(path,text.replace(old,new,1))

worker=ROOT/'HuymaierSteamWorker.ps1'
worker_marker="""try{
    $GameId=$GameId -replace '^(?i)Steam:',''
"""
worker_loader="""$script:HcSteamOwnershipModulePath=Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'HuymaierSteamOwnership.ps1'
if(Test-Path -LiteralPath $script:HcSteamOwnershipModulePath -PathType Leaf){. $script:HcSteamOwnershipModulePath}

try{
    $GameId=$GameId -replace '^(?i)Steam:',''
"""
once(worker,worker_marker,worker_loader,'Steam ownership worker loader')

provider=ROOT/'HuymaierV0262ProviderRuntime.ps1'
provider_marker="""$script:HcV0262HardeningPath=Join-Path $script:BaseDir 'HuymaierV0262Hardening.ps1'
if(Test-Path -LiteralPath $script:HcV0262HardeningPath -PathType Leaf){. $script:HcV0262HardeningPath}
"""
provider_loader=provider_marker+"""$script:HcSteamOwnershipRuntimePath=Join-Path $script:BaseDir 'HuymaierSteamOwnershipRuntime.ps1'
if(Test-Path -LiteralPath $script:HcSteamOwnershipRuntimePath -PathType Leaf){. $script:HcSteamOwnershipRuntimePath}
"""
once(provider,provider_marker,provider_loader,'Steam ownership shell loader')

print('Wired Steam owned-library enrichment into worker and shell runtime.')
