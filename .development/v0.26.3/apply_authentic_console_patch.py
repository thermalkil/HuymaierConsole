from pathlib import Path
import runpy

wrapper = Path(__file__).with_name('run_padded_authentic_integration.py')
if not wrapper.is_file():
    raise SystemExit(f'Padded authentic-integration wrapper is missing: {wrapper}')
runpy.run_path(str(wrapper), run_name='__main__')
print('Applied reviewed RC3 authentic-console production payload through padded per-file decoder.')
