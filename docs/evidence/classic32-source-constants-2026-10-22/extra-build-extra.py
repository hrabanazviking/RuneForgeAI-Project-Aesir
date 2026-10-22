from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,subprocess
repo=Path.cwd();root=repo.parent/'classic32-source-extra';out=root/'build';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source=json.loads(Path('../classic32-source-final/source-hashes.json').read_text());inputs=json.loads(Path('../classic32-source-final/input-hashes.json').read_text())
oldsource=json.loads(Path('../classic32-source-baseline/source-hashes.json').read_text());oldroot=(repo/'../q8-source-final/source-snapshot').resolve()
for p,h in oldsource.items():assert sha(oldroot/p)==h,p
for p,h in {**source,**inputs}.items():assert sha(p)==h,p
jobs=[]
for side,cwd in [('current',repo),('old',oldroot)]:
 for src,name in [('smidr/tools/source_storage.mojo','source-storage'),('tests/hailo_source_storage_api.mojo','source-storage-api'),('smidr/tools/safetensors_inventory.mojo','safe-inventory')]:jobs.append((side,cwd,src,name))
def build(job):
 side,cwd,src,name=job;dest=out/(side+'-'+name);log=out/(side+'-'+name+'-build.txt')
 with log.open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(dest)],cwd=cwd,env=dict(os.environ,MODULAR_CACHE_DIR=str((repo/'../mojo-cache').resolve())),stdout=f,stderr=subprocess.STDOUT,timeout=600)
 row={'side':side,'cwd':str(cwd),'source':src,'source_sha256':sha(cwd/src),'binary':str(dest),'sha256':sha(dest) if r.returncode==0 else None,'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size}
 (out/(side+'-'+name+'-result.json')).write_text(json.dumps(row,indent=2)+'\n');print(side,name,r.returncode,row['diagnostic_bytes'],flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
for p,h in {**source,**inputs}.items():assert sha(p)==h,p
for p,h in oldsource.items():assert sha(oldroot/p)==h,p
print('Three current and three frozen-source baseline builds clean;643current/640baseline source contents unchanged',flush=True)
