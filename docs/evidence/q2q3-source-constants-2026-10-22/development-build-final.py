from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,subprocess
repo=Path.cwd();out=Path('../q2q3-native-final');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo'))};assert len(source)==646
(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
for p in source:
 dst=out/'source-snapshot'/p;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(Path(p).read_bytes())
inputs={str(p):sha(p) for p in sorted(Path('tests').glob('test_hailo*.py'))};assert len(inputs)==65
for p in Path('../q2q3-native-development').glob('*.py'):inputs[str(p)]=sha(p)
for p in ('tests/hailo_q2q3_layout_oracle.cpp','../classic32-source-audit-review/audit-traces.py','../q8-source-audit-review/audit-q8-traces.py','../dynamic-graph-development/audit-traces.py','../dynamic-graph-development/mutations.json','../lcu-action-final/old-oracle','../lcu-action-final/oracle','../ggml-format-study/build/src/libggml-base.so.0.27.0','../q2q3-source-study/layout-oracle','../ggml-format-study/source/src/ggml-common.h','../ggml-format-study/LICENSE','../ggml-format-study/build/CMakeCache.txt'):inputs[p]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
old=json.loads(Path('../q2q3-native-baseline/source-hashes.json').read_text());assert [p for p,h in old.items() if source[p]!=h]==['aesir_engine/loader/packed_gguf.mojo']
for p,h in json.loads(Path('../q2q3-native-baseline/test-input-hashes.json').read_text()).items():assert sha(p)==h,p
controls=json.loads(Path('../q2q3-native-baseline/controls.json').read_text())
for x in controls:assert sha(x['binary'])==x['sha256']
pairs=[(x['source'],Path(x['binary']).name) for x in controls]+[('smidr/tools/source_q2q3_constants.mojo','q2q3-constants'),('tests/hailo_source_q2q3_api.mojo','q2q3-api')]
# Conservative additional host-only import closure; excluded engine/historical
# forward tests are listed in inventory and never executed.
inv=json.loads(Path('../q2q3-native-baseline/consumer-inventory.json').read_text())
extra=[p for p in inv['affected_entrypoints_without_control'] if p.startswith(('smidr/','tests/hailo_'))]
for p in extra:pairs.append((p,'closure-'+Path(p).stem))
assert len(pairs)==len({n for _,n in pairs})
(out/'closure-jobs.json').write_text(json.dumps({'current':pairs,'extra_snapshot_baselines':extra,'scope':'Conservative original metadata/compiler closure only; no host LLM, hardware, historical or master-suite execution.'},indent=2)+'\n')
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
 for x in controls:assert sha(x['binary'])==x['sha256']
stable()
oldroot=(repo/'../q2q3-native-baseline/source-snapshot').resolve()
jobs=[('current',repo,src,name) for src,name in pairs]+[('snapshot',oldroot,p,'snapshot-'+Path(p).stem) for p in extra]
def build(job):
 side,cwd,src,name=job;dest=(repo/out/name).resolve();log=out/(name+'-build.txt')
 with log.open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(dest)],cwd=cwd,stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,MODULAR_CACHE_DIR=str((repo/'../mojo-cache').resolve())),timeout=600)
 row={'side':side,'source':src,'cwd':str(cwd),'source_sha256':sha(cwd/src),'binary':str(dest),'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(dest) if r.returncode==0 else None}
 (out/(name+'-result.json')).write_text(json.dumps(row,indent=2)+'\n');print(side,name,r.returncode,row['diagnostic_bytes'],flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');stable()
for p,h in old.items():assert sha(oldroot/p)==h,p
assert all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
print('All',len(rows),'builds clean;',len(pairs),'current;',len(extra),'snapshot controls',flush=True)
