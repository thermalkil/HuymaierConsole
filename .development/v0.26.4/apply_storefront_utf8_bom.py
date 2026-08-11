from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierStorefronts.ps1'
raw=path.read_bytes()
bom=b'\xef\xbb\xbf'
if not raw.startswith(bom):
    # Validate the current source is UTF-8 before changing only its encoding marker.
    raw.decode('utf-8')
    path.write_bytes(bom+raw)
    print('added UTF-8 BOM to HuymaierStorefronts.ps1 for Windows PowerShell 5.1')
else:
    print('HuymaierStorefronts.ps1 already has UTF-8 BOM')
