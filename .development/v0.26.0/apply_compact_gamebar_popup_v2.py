from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source_path = ROOT / '.development' / 'v0.26.0' / 'apply_compact_gamebar_popup.py'
code = source_path.read_text(encoding='utf-8-sig')
old = '''s = replace_once(
    s,
    "$script:HcChoiceSelected=0\\n$script:HcChoiceSetting=''",
    "$script:HcChoiceSelected=0\\n$script:HcChoiceSetting=''\\n$script:HcChoicePreviousFocus=$null",
    "choice popup focus state",
)'''
new = '''s = replace_once(
    s,
    "$script:HcChoiceOptions=@()\\n$script:HcChoiceSelected=0\\n$script:HcChoiceSetting=''",
    "$script:HcChoiceOptions=@()\\n$script:HcChoiceSelected=0\\n$script:HcChoiceSetting=''\\n$script:HcChoicePreviousFocus=$null",
    "choice popup focus state",
)'''
count = code.count(old)
if count != 1:
    raise RuntimeError(f'popup transformer correction: expected one match, found {count}')
code = code.replace(old, new, 1)
exec(compile(code, str(source_path), 'exec'), {'__name__': '__main__', '__file__': str(source_path)})
