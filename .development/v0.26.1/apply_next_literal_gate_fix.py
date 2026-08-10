from pathlib import Path

p=Path('.build/Test-HuymaierCandidate.ps1')
t=p.read_text(encoding='utf-8-sig')
replacements={
    '$subPageIndex=$shell.IndexOf("$script:SubPage=\'FilePicker\'",$pickerStart)': "$subPageIndex=$shell.IndexOf('$script:SubPage=''FilePicker''',$pickerStart)",
    '$consoleSettingsStart=$shellRedesign.IndexOf("if($script:SubPage -eq \'ConsoleSettings\')")': "$consoleSettingsStart=$shellRedesign.IndexOf('if($script:SubPage -eq ''ConsoleSettings'')')",
    '$updatesStart=$shellRedesign.IndexOf("if($script:SubPage -eq \'UpdatesHub\')",$consoleSettingsStart)': "$updatesStart=$shellRedesign.IndexOf('if($script:SubPage -eq ''UpdatesHub'')',$consoleSettingsStart)",
}
for old,new in replacements.items():
    if t.count(old)!=1:
        raise SystemExit(f'expected one literal-gate target, found {t.count(old)}: {old}')
    t=t.replace(old,new,1)
p.write_text(t,encoding='utf-8-sig',newline='\n')
print('Converted candidate source-search strings to non-interpolating PowerShell literals.')
