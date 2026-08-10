from pathlib import Path

p=Path('.build/Test-HuymaierCandidate.ps1')
t=p.read_text(encoding='utf-8-sig')
old='''    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8\n    if($shell -notmatch "(?s)else\\\\s*\\\\{\\\\s*\\\\`$script:SelectedTab=6\\\\s*\\\\`$script:SubPage='FilePicker'"){throw 'Native non-Browse file picker does not enter the File Explorer tab.'}\n'''
# Some previous PowerShell escaping produced a slightly different literal in the
# repository. Replace by locating the two-line gate rather than trusting Python's
# view of the escape count.
if old not in t:
    start=t.find("    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8\n", t.find('# RC13:'))
    if start<0:
        raise SystemExit('file-picker shell gate start not found')
    end=t.find("\n\n    # Combined next-build gates:",start)
    if end<0:
        raise SystemExit('file-picker shell gate end not found')
    old=t[start:end]
new='''    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8\n    $pickerStart=$shell.IndexOf('function Start-NativeFilePicker')\n    $pickerEnd=$shell.IndexOf('function Complete-NativeFolderSelection',$pickerStart)\n    $tabIndex=$shell.IndexOf('$script:SelectedTab=6',$pickerStart)\n    $subPageIndex=$shell.IndexOf(\"$script:SubPage='FilePicker'\",$pickerStart)\n    if($pickerStart -lt 0 -or $pickerEnd -lt 0 -or $tabIndex -lt $pickerStart -or $tabIndex -ge $pickerEnd -or $subPageIndex -lt $tabIndex -or $subPageIndex -ge $pickerEnd){throw 'Native non-Browse file picker does not enter the File Explorer tab before rendering FilePicker.'}\n'''
t=t.replace(old,new,1)
p.write_text(t,encoding='utf-8-sig',newline='\n')
print('Replaced fragile native file-picker regex gate with deterministic source-order checks.')
