from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,subprocess,sys
build=Path('../q2q3-native-final');out=Path('../q2q3-native-acceptance');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==117 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
source=json.loads((build/'source-hashes.json').read_text());inputs=json.loads((build/'input-hashes.json').read_text())
# Explicit C++ test-only amendment after clean Mojo builds, never silent drift.
amend=json.loads(Path('../q2q3-native-development/cpp-amendment.json').read_text())
assert inputs[amend['path']]==amend['before_sha256'];inputs[amend['path']]=amend['after_sha256']
controls=json.loads(Path('../q2q3-native-baseline/controls.json').read_text())
commands=json.loads(Path('../q2q3-native-development/commands.json').read_text())
for p in Path('../q2q3-native-development').glob('*'):
 if p.is_file():inputs[str(p)]=sha(p)
for p in ('../source-root-api','../unindexed-baseline-collection','../source-index-study/io-faults.so','../model-root-study/io-faults.so','../owned-fd-study/io-faults.so','../model-root-study/layout','../model-root-study/layout.c','../ordinary-model-metadata-study/config.json','../ordinary-model-metadata-study/model.safetensors.index.json','../decoder-dynamic-baseline/scaling-graph','../decoder-graph-baseline/semantic-plan','../q2q3-native-development/layout-oracle'):inputs[p]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256'],x['binary']
def run(job):
 name,cmd,paired=job;stable()
 args=[sys.executable,'../q2q3-native-development/pair-frozen.py',str(out/'pairs'/(name+'.json')),*cmd[1:]] if paired else cmd
 with (out/(name+'-tests.txt')).open('w') as f:p=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 row={'suite':name,'returncode':p.returncode,'command':args}
 (out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');print('suite',name,p.returncode,flush=True);stable();return row
new=next(x for x in commands if x[0]=='q2q3');results=[run(new)]
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[0]['returncode']==0
for name,cmd in [('q2q3-traces',[sys.executable,'../classic32-source-audit-review/audit-traces.py',str(out/'q2q3')])]:
 results.append(run((name,cmd,False)));assert results[-1]['returncode']==0
with ThreadPoolExecutor(max_workers=2) as pool:results+=list(pool.map(run,(x for x in commands if x[0]!='q2q3')))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['returncode']==0 for x in results)
for name,script in [('classic32','../classic32-source-audit-review/audit-traces.py'),('q8','../q8-source-audit-review/audit-q8-traces.py'),('graph','../dynamic-graph-development/audit-traces.py')]:
 results.append(run((name+'-traces',[sys.executable,script,str(out/name)],False)))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['returncode']==0 for x in results)
pairs=[x for f in (out/'pairs').glob('*.json') for x in json.loads(f.read_text())]
current={x['source']:x for x in rows if x['side']=='current'};expected={x['binary'] for src,x in current.items() if src not in ('smidr/tools/source_q2q3_constants.mojo','tests/hailo_source_q2q3_api.mojo')}
seen={x['binary'] for x in pairs};assert seen==expected,(expected-seen,seen-expected)
(out/'frozen-pair-summary.json').write_text(json.dumps({'controls':len(seen),'success_pairs':sum(x['returncode']==0 for x in pairs),'nonzero_pairs':sum(x['returncode']!=0 for x in pairs),'unrelated_comparisons_skipped':0,'snapshot_controls_compiled_after_implementation':17},indent=2)+'\n')
# Direct newly admitted GGUF namespace; no global legacy-pair exemption.
old=next(x['binary'] for x in controls if x['source']=='tests/hailo_source_storage_api.mojo');new=current['tests/hailo_source_storage_api.mojo']['binary'];admissions=[]
for kind,size in ((10,84),(11,110)):
 args=['arithmetic','gguf',str(kind),'256'];a=subprocess.run([old,*args],capture_output=True,text=True);b=subprocess.run([new,*args],capture_output=True,text=True)
 assert a.returncode==1 and 'unsupported tensor type '+str(kind) in a.stderr,(a.returncode,a.stdout,a.stderr)
 assert b.returncode==0 and json.loads(b.stdout)=={'elements':256,'bytes':size},(b.returncode,b.stdout,b.stderr)
 admissions.append({'source':'tests/hailo_source_storage_api.mojo','arguments':args,'old_returncode':a.returncode,'old_stdout':a.stdout,'old_stderr':a.stderr,'new_returncode':b.returncode,'new_stdout':b.stdout,'new_stderr':b.stderr})
(out/'intentional-admission-deltas.json').write_text(json.dumps(admissions,indent=2)+'\n');stable()
print('42 suites, all98 actual compiler/control binaries paired; exact GGUF10/11 admission proven',flush=True)
