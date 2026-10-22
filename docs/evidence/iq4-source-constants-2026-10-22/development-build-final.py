from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,subprocess
out=Path('../iq4-native-final');out.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo'))};assert len(source)==649
(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
for p in source:
 dst=out/'source-snapshot'/p;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(Path(p).read_bytes())
inputs={str(p):sha(p) for p in sorted(Path('tests').glob('test_hailo*.py'))};assert len(inputs)==66
for p in Path('../iq4-native-development').glob('*.py'):inputs[str(p)]=sha(p)
for p in ('tests/hailo_iq4_layout_oracle.cpp','../classic32-source-audit-review/audit-traces.py','../q8-source-audit-review/audit-q8-traces.py','../dynamic-graph-development/audit-traces.py','../dynamic-graph-development/mutations.json','../lcu-action-final/old-oracle','../lcu-action-final/oracle','../ggml-format-study/build/src/libggml-base.so.0.27.0','../iq4-source-study/layout-oracle','../ggml-format-study/source/src/ggml-common.h','../ggml-format-study/LICENSE','../ggml-format-study/build/CMakeCache.txt'):inputs[p]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
old=json.loads(Path('../iq4-native-baseline/source-hashes.json').read_text());assert [p for p,h in old.items() if source[p]!=h]==['aesir_engine/loader/packed_gguf.mojo']
for p,h in json.loads(Path('../iq4-native-baseline/test-input-hashes.json').read_text()).items():assert sha(p)==h,p
controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text());assert len(controls)==100
for x in controls:assert sha(x['binary'])==x['sha256']
pairs=[(x['source'],Path(x['binary']).name) for x in controls]+[('smidr/tools/source_iq4_constants.mojo','iq4-constants'),('tests/hailo_source_iq4_api.mojo','iq4-api')];assert len(pairs)==len({n for _,n in pairs})==102
(out/'closure-jobs.json').write_text(json.dumps({'current':pairs,'current_count':102,'baseline_controls_frozen_before_IQ4_production':100,'all_safe_import_entrypoints_covered':True},indent=2)+'\n')
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
 for x in controls:assert sha(x['binary'])==x['sha256']
stable()
def build(pair):
 src,name=pair;log=out/(name+'-build.txt')
 with log.open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(out/name)],stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),timeout=600)
 row={'source':src,'binary':str((out/name).resolve()),'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(out/name) if r.returncode==0 else None};(out/(name+'-result.json')).write_text(json.dumps(row,indent=2)+'\n');print(name,r.returncode,row['diagnostic_bytes'],flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');stable();assert all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
print('All102 current Mojo builds clean;649source and100control identities unchanged',flush=True)
