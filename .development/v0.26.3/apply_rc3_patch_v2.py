from pathlib import Path
import base64
import gzip
import hashlib
import subprocess

ROOT = Path('.development/v0.26.3/authentic_patch_v2')
PART_COUNT = 7
EXPECTED_PATCH_SHA256 = 'f6ca760aade9136b9c830b61d7eec34473e50a24a64c245e450d0be1e5b9a98c'

parts = [ROOT / f'{index:02d}.b64part' for index in range(PART_COUNT)]
for part in parts:
    if not part.is_file():
        raise SystemExit(f'Missing RC3 patch transport part: {part}')

encoded = ''.join(part.read_text(encoding='utf-8').strip() for part in parts)
try:
    compressed = base64.b64decode(encoded, validate=True)
    patch = gzip.decompress(compressed)
except Exception as exc:
    raise SystemExit(f'Could not decode RC3 patch transport: {exc}')

actual = hashlib.sha256(patch).hexdigest()
if actual != EXPECTED_PATCH_SHA256:
    raise SystemExit(f'RC3 production patch SHA-256 mismatch: expected {EXPECTED_PATCH_SHA256}, got {actual}')

subprocess.run(['git', 'apply', '--check', '--whitespace=nowarn', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '--whitespace=nowarn', '-'], input=patch, check=True)
print(f'Applied checksum-verified RC3 production patch: {actual}')
