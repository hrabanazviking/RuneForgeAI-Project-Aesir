import subprocess,sys
from pathlib import Path
for name in ('build-final','verify-final'):
 p=subprocess.run([sys.executable,f'../q8-source-development/{name}.py'],stdout=sys.stdout,stderr=sys.stderr)
 print(name,p.returncode,flush=True)
 if p.returncode:raise SystemExit(p.returncode)
