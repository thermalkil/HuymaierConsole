from pathlib import Path
import base64
import runpy

ORIGINAL_B64DECODE = base64.b64decode


def padded_b64decode(value, altchars=None, validate=False):
    if isinstance(value, str):
        value = value + ('=' * (-len(value) % 4))
    else:
        value = value + (b'=' * (-len(value) % 4))
    return ORIGINAL_B64DECODE(value, altchars=altchars, validate=validate)


base64.b64decode = padded_b64decode
payload = Path(__file__).with_name('apply_authentic_console_integration.py')
if not payload.is_file():
    raise SystemExit(f'Reviewed authentic integration payload is missing: {payload}')
runpy.run_path(str(payload), run_name='__main__')
