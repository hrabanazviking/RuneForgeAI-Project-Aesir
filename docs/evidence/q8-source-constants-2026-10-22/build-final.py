from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,subprocess
out=Path('../q8-source-final');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo')) if '.git' not in p.parts}
assert len(source)==640,len(source)
(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
for p in source:
 dest=out/'source-snapshot'/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(Path(p).read_bytes())
inputs={str(p):sha(p) for p in sorted(Path('tests').glob('test_hailo*.py'))}
inputs.update({str(p):sha(p) for p in sorted(Path('../q8-source-development').glob('*.py'))})
inputs['../dynamic-graph-development/mutations.json']=sha('../dynamic-graph-development/mutations.json')
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
old=json.loads(Path('../q8-source-baseline/source-hashes.json').read_text())
changed=[p for p,h in old.items() if source[p]!=h];assert set(changed)=={'aesir_engine/loader/packed_gguf.mojo','smidr/source_weight_tiles.mojo'},changed
(out/'changed-prior-sources.json').write_text(json.dumps(changed,indent=2)+'\n')
controls=json.loads(Path('../q8-source-baseline/controls.json').read_text())
for x in controls:assert sha(x['binary'])==x['sha256']
pairs=[(x['source'],Path(x['binary']).name) for x in controls]+[('smidr/tools/source_q8_constants.mojo','q8-constants'),('tests/hailo_source_q8_api.mojo','q8-api')]
assert len(pairs)==76 and len(set(n for _,n in pairs))==76
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
for p,h in json.loads(Path('../q8-source-baseline/test-input-hashes.json').read_text()).items():assert sha(p)==h,p
stable()
def build(pair):
 src,name=pair;log=out/(name+'-build.txt')
 with log.open('w') as f:p=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(out/name)],stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),timeout=600)
 row={'source':src,'binary':str(out/name),'returncode':p.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(out/name) if p.returncode==0 else None}
 (out/(name+'-result.json')).write_text(json.dumps(row,indent=2)+'\n');print(name,p.returncode,row['diagnostic_bytes'],flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n')
stable();assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in results)
for x in controls:assert sha(x['binary'])==x['sha256']
print('Final76 builds clean;640-source snapshot and all frozen inputs/controls unchanged',flush=True)
