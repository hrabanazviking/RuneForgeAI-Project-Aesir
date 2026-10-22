from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,os,shutil,subprocess
out=Path('../sealed-copy-native-final');out.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
old=json.load(open('../sealed-copy-native-baseline/source-hashes.json'));inputs=json.load(open('../sealed-copy-native-baseline/test-input-hashes.json'));controls=json.load(open('../sealed-copy-native-baseline/controls.json'))
for p,h in {**old,**inputs}.items():assert sha(p)==h,p
for r in controls:assert sha(r['binary'])==r['sha256']
sources={str(p):sha(p) for p in sorted(Path('.').rglob('*.mojo')) if '.git' not in p.parts};assert len(sources)==656
for p in sources:
 dest=out/'source-snapshot'/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
for p in ('tests/test_hailo_sealed_source_copy.py','tests/source_sealed_copy_faults.c','../sealed-copy-native-development/build-final.py','../source-sealed-copy-contract-study/host-seals-oracle.c'):inputs[p]=sha(p)
(out/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n');(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
selected=json.load(open('../source-digest-native-final-v2/build-results.json'))
jobs=[(r['source'],Path(r['binary']).name) for r in selected]+[('smidr/tools/sealed_source_copy.mojo','sealed-source-copy'),('tests/hailo_sealed_source_api.mojo','sealed-source-api')]
(out/'import-boundary.json').write_text(json.dumps({'new_sources':sorted(set(sources)-set(old)),'old_sources_changed':[],'new_affected_entrypoints':[s for s,n in jobs[-2:]],'old_import_closures_affected':[],'selected_regression_entrypoints':[s for s,n in jobs[:-2]],'reason':'New leaf imports existing syscall and digest modules. No old source imports the new leaf. Rebuild only affected new leaves and selected source-owner/digest/constant/byte-tile controls.'},indent=2)+'\n')
env=os.environ.copy();env['MODULAR_CACHE_DIR']='../mojo-cache'
def build(job):
 src,name=job;binary=out/name;log=out/(name+'.build.log');cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)]
 with log.open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600,env=env)
 row={'source':src,'binary':str(binary.resolve()),'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(binary) if binary.exists() else None};print(name,r.returncode,log.stat().st_size,flush=True);return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,jobs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
assert len(rows)==10 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
for src,name,flags in [('tests/source_sealed_copy_faults.c','io-faults.so',['-shared','-fPIC','-ldl']),('../source-sealed-copy-contract-study/host-seals-oracle.c','header-seals-oracle',[])]:
 r=subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror',src,*flags,'-o',str(out/name)],capture_output=True,text=True);(out/(name+'.build.log')).write_text(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout+r.stderr
(out/'c-binaries.json').write_text(json.dumps([{'binary':str((out/n).resolve()),'sha256':sha(out/n)} for n in ('io-faults.so','header-seals-oracle')],indent=2)+'\n')
print('10 stable Mojo builds and two clean C builds; all linking before execution',flush=True)
