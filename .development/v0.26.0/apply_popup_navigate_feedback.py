from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'HuymaierShellRedesign.ps1'
text = PATH.read_text(encoding='utf-8-sig')

old = "function Move-HcChoicePopup {param([int]$Delta);$count=@($script:HcChoiceOptions).Count;if((-not (Test-HcChoicePopupVisible)) -or $count -eq 0){return};$script:HcChoiceSelected=($script:HcChoiceSelected+$Delta+$count)%$count;Invoke-UiFeedback 'Move';Update-HcChoicePopupVisuals}"
new = """function Move-HcChoicePopup {
    param([int]$Delta)
    $count=@($script:HcChoiceOptions).Count
    if((-not (Test-HcChoicePopupVisible)) -or $count -eq 0){return}
    $script:HcChoiceSelected=($script:HcChoiceSelected+$Delta+$count)%$count
    # Use the same validated navigation feedback token as the rest of the shell.
    # A feedback/audio failure must never abort selection movement or repaint.
    try{Invoke-UiFeedback 'Navigate'}catch{Write-Log \"Choice popup navigation feedback recovered: $($_.Exception.Message)\" 'WARN'}
    try{Update-HcChoicePopupVisuals}catch{Write-Log \"Choice popup visual refresh recovered: $($_.Exception.Message)\" 'WARN'}
}"""

count = text.count(old)
if count != 1:
    raise RuntimeError(f'Move-HcChoicePopup match count: {count}')
text = text.replace(old, new, 1)

# This regression should never survive another popup refactor.
if "Invoke-UiFeedback 'Move'" in text:
    raise RuntimeError("Invalid Invoke-UiFeedback 'Move' call still exists after patch")

PATH.write_text(text, encoding='utf-8')
print('Popup navigation now uses validated Navigate feedback and cannot be aborted by feedback/visual exceptions.')
