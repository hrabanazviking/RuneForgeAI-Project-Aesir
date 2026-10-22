from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,subprocess
out=Path('../classic32-source-final');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo')) if '.git' not in p.parts}
assert len(source)==643,len(source)
(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
for p in source:
 dest=out/'source-snapshot'/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(Path(p).read_bytes())
inputs={str(p):sha(p) for p in sorted(Path('tests').glob('test_hailo*.py'))}
inputs.update({str(p):sha(p) for p in sorted(Path('../classic32-source-development').glob('*.py'))})
for p in ('../dynamic-graph-development/mutations.json','../q8-source-audit-review/audit-q8-traces.py','../lcu-action-final/old-oracle','../lcu-action-final/oracle','../ggml-format-study/build/src/libggml-base.so.0.27.0','tests/hailo_classic32_layout_oracle.cpp','../classic32-source-development/layout-oracle','../ggml-format-study/source/src/ggml-common.h','../ggml-format-study/LICENSE','../ggml-format-study/build/CMakeCache.txt'):
 inputs[p]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
old=json.loads(Path('../classic32-source-baseline/source-hashes.json').read_text())
changed=[p for p,h in old.items() if source[p]!=h];assert set(changed)=={'aesir_engine/loader/packed_gguf.mojo','smidr/source_weight_tiles.mojo'},changed
(out/'changed-prior-sources.json').write_text(json.dumps(changed,indent=2)+'\n')
oldpy=json.loads(Path('../classic32-source-baseline/test-input-hashes.json').read_text())
assert [p for p,h in oldpy.items() if sha(p)!=h]==['tests/test_hailo_source_storage.py']
assert Path('tests/test_hailo_source_storage.py').read_bytes()==Path('../classic32-source-baseline/python-snapshot/tests/test_hailo_source_storage.py').read_bytes().replace(b'("gguf",2,[256])',b'("gguf",9,[256])')
controls=json.loads(Path('../classic32-source-baseline/controls.json').read_text())
for x in controls:assert sha(x['binary'])==x['sha256']
pairs=[(x['source'],Path(x['binary']).name) for x in controls]+[('smidr/tools/source_classic32_constants.mojo','classic32-constants'),('tests/hailo_source_classic32_api.mojo','classic32-api')]
assert len(pairs)==78 and len(set(n for _,n in pairs))==78
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
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
print('Final78 builds clean;643-source snapshot and all frozen inputs/controls unchanged',flush=True)
