from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / '.github' / 'workflows' / 'build-v026-test.yml'
text = path.read_text(encoding='utf-8-sig')
old = """          $status=[ordered]@{\n            candidate='v0.26.0-test'\n            result=$env:BUILD_RESULT\n            commit=$env:GITHUB_SHA\n            recordedAtUtc=[DateTime]::UtcNow.ToString('o')\n          }\n"""
new = """          $status=[ordered]@{\n            candidate='v0.26.0-test'\n            result=$env:BUILD_RESULT\n            runId=$env:GITHUB_RUN_ID\n            runAttempt=$env:GITHUB_RUN_ATTEMPT\n            commit=$env:GITHUB_SHA\n            recordedAtUtc=[DateTime]::UtcNow.ToString('o')\n          }\n"""
count = text.count(old)
if count != 1:
    raise RuntimeError(f'build status block: expected one match, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('v0.26.0 test-package status now records workflow run ID and attempt.')
