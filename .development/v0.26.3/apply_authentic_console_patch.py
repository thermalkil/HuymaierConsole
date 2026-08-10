from pathlib import Path
import base64
import gzip
import hashlib
import subprocess

ROOT = Path('.development/v0.26.3/authentic_patch')
EXPECTED_PARTS = [ROOT / f'{index:02d}.b64part' for index in range(4)]
EXPECTED_SHA256 = 'ef8afe2f599ee4d407eed2d2aca6d48506bb12f15993d649ce7f444d49d549bb'

for part in EXPECTED_PARTS:
    if not part.is_file():
        raise SystemExit(f'Missing authentic-console patch part: {part}')

encoded = ''.join(part.read_text(encoding='utf-8').strip() for part in EXPECTED_PARTS)
try:
    patch = gzip.decompress(base64.b64decode(encoded, validate=True))
except Exception as exc:
    raise SystemExit(f'Could not decode authentic-console patch payload: {exc}')

actual = hashlib.sha256(patch).hexdigest()
if actual != EXPECTED_SHA256:
    raise SystemExit(f'Authentic-console patch SHA-256 mismatch: expected {EXPECTED_SHA256}, got {actual}')

subprocess.run(['git', 'apply', '--check', '--whitespace=nowarn', '-'], input=patch, check=True)
subprocess.run(['git', 'apply', '--whitespace=nowarn', '-'], input=patch, check=True)
print(f'Applied checksum-verified authentic-console patch: {actual}')
