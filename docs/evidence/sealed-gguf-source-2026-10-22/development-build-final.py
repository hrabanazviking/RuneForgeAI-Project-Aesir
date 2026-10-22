from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,shutil,subprocess
out=Path('../sealed-gguf-native-final');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
old=json.load(open('../sealed-gguf-native-baseline/source-hashes.json'));inputs=json.load(open('../sealed-gguf-native-baseline/test-input-hashes.json'));controls=json.load(open('../sealed-gguf-native-baseline/controls.json'))
changed={'aesir_engine/loader/gguf.mojo','aesir_engine/loader/packed_gguf.mojo','hailbru/source_sealed_copy.mojo'}
for p,h in old.items():
 if p not in changed:assert sha(p)==h,p
for p,h in inputs.items():assert sha(p)==h,p
for r in controls:assert sha(r['binary'])==r['sha256'],r['source']
sources={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo')) if '.git' not in p.parts}
assert len(sources)==659
for p in sources:
 target=out/'source-snapshot'/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
(out/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n')
# Recompute conservative import closures including package initializers.
roots=[Path('.'),Path('aesir_engine'),Path('tests')]
import re
def resolve(module):
 if module.startswith('std.') or module=='std':return []
 parts=module.split('.')
 for base in roots:
  n=base.joinpath(*parts);p=n.with_suffix('.mojo')
  if not p.is_file():p=n/'__init__.mojo'
  if p.is_file():return [str(p)]+[str(q) for i in range(1,len(parts)) if (q:=base.joinpath(*parts[:i])/'__init__.mojo').is_file()]
 return []
def closure(src,seen=None):
 if seen is None:seen=set()
 if src in seen:return seen
 seen.add(src)
 for module in re.findall(r'^\s*(?:from|import)\s+([A-Za-z_][A-Za-z_0-9.]*)',Path(src).read_text(),re.M):
  for p in resolve(module):closure(p,seen)
 return seen
inventory=[]
for r in controls:
 dep=closure(r['source']);inventory.append({'source':r['source'],'binary':r['binary'],'affected':bool(dep&changed),'shared_dependencies':sorted(dep&changed),'closure':sorted(dep)})
(out/'consumer-inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
assert sum(r['affected'] for r in inventory)==100
# Build all 106 current source/primitive entrypoints conservatively (six unaffected included).
jobs=[(r['source'],f'old-{i:03d}') for i,r in enumerate(controls)]+[('smidr/tools/sealed_gguf_source.mojo','sealed-gguf'),('tests/hailo_sealed_gguf_api.mojo','sealed-gguf-api')]
env=os.environ.copy();env['MODULAR_CACHE_DIR']='../mojo-cache'
def build(job):
 src,name=job;binary=out/name;log=out/(name+'.build.log');cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)]
 with log.open('w') as f:
  try:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600,env=env);rc=r.returncode
  except subprocess.TimeoutExpired:rc=124
 row={'source':src,'binary':str(binary.resolve()),'returncode':rc,'diagnostic_bytes':log.stat().st_size,'sha256':sha(binary) if binary.exists() else None}
 print(name,src,rc,log.stat().st_size,flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
for p,h in sources.items():assert sha(p)==h,p
assert len(rows)==108 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
for src,name in [('tests/sealed_gguf_faults.c','parser-faults.so'),('tests/source_sealed_copy_faults.c','copy-faults.so')]:
 r=subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror','-shared','-fPIC',src,'-ldl','-o',str(out/name)],capture_output=True,text=True)
 (out/(name+'.build.log')).write_text(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout+r.stderr
print('108 stable clean builds; no native tests executed during linking.',flush=True)
