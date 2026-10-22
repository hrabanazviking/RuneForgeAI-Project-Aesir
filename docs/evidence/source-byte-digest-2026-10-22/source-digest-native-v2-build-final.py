from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,shutil,subprocess
out=Path('../source-digest-native-final-v2');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
old=json.load(open('../source-digest-native-baseline/source-hashes.json'));inputs=json.load(open('../source-digest-native-baseline/test-input-hashes.json'));controls=json.load(open('../source-digest-native-baseline/controls.json'))
for p,h in {**old,**inputs}.items():assert sha(p)==h,p
for r in controls:assert sha(r['binary'])==r['sha256']
sources={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo')) if '.git' not in p.parts};assert len(sources)==653
for p in sources:
 dest=out/'source-snapshot'/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
extra=['tests/test_hailo_source_digest.py','tests/source_digest_io_faults.c','../source-digest-native-v2/build-final.py','../source-digest-native-development/import-boundary.json']
inputs.update({p:sha(p) for p in extra})
(out/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n');(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
selected=json.load(open('../source-digest-native-development/selected-controls.json'))
jobs=[(r['source'],Path(r['binary']).name) for r in selected]+[('smidr/tools/source_byte_digest.mojo','source-byte-digest'),('tests/hailo_source_digest_api.mojo','source-digest-api')]
env=os.environ.copy();env['MODULAR_CACHE_DIR']='../mojo-cache'
def build(job):
 src,name=job;binary=out/name;log=out/(name+'.build.log')
 cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)]
 with log.open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600,env=env)
 row={'source':src,'binary':str(binary.resolve()),'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(binary) if binary.exists() else None}
 print(name,r.returncode,log.stat().st_size,flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
assert len(rows)==8 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
r=subprocess.run(['cc','-shared','-fPIC','-Wall','-Wextra','-Werror','tests/source_digest_io_faults.c','-ldl','-o',str(out/'io-faults.so')],capture_output=True,text=True)
(out/'fault-build.log').write_text(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout+r.stderr
(out/'fault-library.json').write_text(json.dumps({'binary':str((out/'io-faults.so').resolve()),'sha256':sha(out/'io-faults.so')},indent=2)+'\n')
print('8 stable builds and test fault library clean; no native tests run during linking',flush=True)
