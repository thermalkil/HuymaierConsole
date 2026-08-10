from pathlib import Path

# Builder constructs and statically validates the release-shaped payload. All
# installer execution belongs to the dedicated failure-injection harness so a
# failed install always produces its transaction diagnostics.
p=Path('.build/Build-HuymaierReleaseCandidate.ps1')
t=p.read_text(encoding='utf-8-sig')
start=t.find('# Isolated installer tests.')
end=t.find('# Final release-shaped asset and provenance record.', start)
if start < 0 or end < 0 or end <= start:
    raise SystemExit('candidate builder inline-test block bounds were not found')
t=t[:start] + '# Installer execution and failure injection are performed by .build/Test-HuymaierCandidate.ps1.\n\n' + t[end:]
p.write_text(t,encoding='utf-8-sig',newline='\n')

# Add closed-package negative tests to the one authoritative harness.
p=Path('.build/Test-HuymaierCandidate.ps1')
t=p.read_text(encoding='utf-8-sig')
anchor="""    # Static conflict gates for Windows/Game Bar ownership and dead paths.
"""
insert="""    # Tampered and extra/unchecksummed packages must fail before any installed
    # managed byte is mutated. Use fresh fake install roots so rollback state from
    # one negative test cannot influence another.
    $tamperRoot=Join-Path $env:RUNNER_TEMP ('hc-tamper-'+[guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $StageRoot -Destination $tamperRoot -Recurse -Force
    Add-Content -LiteralPath (Join-Path $tamperRoot 'manifest.json') -Value 'tamper'
    $tamperLocal=Join-Path $env:RUNNER_TEMP ('hc-tamper-local-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $tamperLocal 'Huymaier Console')|Out-Null
    Set-Content -LiteralPath (Join-Path $tamperLocal 'Huymaier Console\\gameinput-redist.version') -Value '3.5.262' -Encoding ASCII
    try{
        if((Invoke-Installer -Root $tamperRoot -FakeLocal $tamperLocal) -eq 0){throw 'Tampered package was incorrectly accepted.'}
        if(Test-Path -LiteralPath (Join-Path $tamperLocal 'Huymaier Console\\HuymaierConsole.exe')){throw 'Tampered package mutated the install root before rejection.'}
    }finally{Remove-Item -LiteralPath $tamperRoot,$tamperLocal -Recurse -Force -ErrorAction SilentlyContinue}

    $extraRoot=Join-Path $env:RUNNER_TEMP ('hc-extra-'+[guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $StageRoot -Destination $extraRoot -Recurse -Force
    Set-Content -LiteralPath (Join-Path $extraRoot 'unexpected.bin') -Value 'unexpected' -Encoding ASCII
    $extraLocal=Join-Path $env:RUNNER_TEMP ('hc-extra-local-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $extraLocal 'Huymaier Console')|Out-Null
    Set-Content -LiteralPath (Join-Path $extraLocal 'Huymaier Console\\gameinput-redist.version') -Value '3.5.262' -Encoding ASCII
    try{
        if((Invoke-Installer -Root $extraRoot -FakeLocal $extraLocal) -eq 0){throw 'Unchecksummed extra payload was incorrectly accepted.'}
        if(Test-Path -LiteralPath (Join-Path $extraLocal 'Huymaier Console\\HuymaierConsole.exe')){throw 'Unchecksummed package mutated the install root before rejection.'}
    }finally{Remove-Item -LiteralPath $extraRoot,$extraLocal -Recurse -Force -ErrorAction SilentlyContinue}

"""
if 'Tampered package was incorrectly accepted.' not in t:
    if anchor not in t: raise SystemExit('candidate test insertion anchor not found')
    t=t.replace(anchor,insert+anchor,1)
p.write_text(t,encoding='utf-8-sig',newline='\n')

print('v0.26.1 candidate test consolidation completed')
