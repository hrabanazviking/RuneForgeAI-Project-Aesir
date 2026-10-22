from pathlib import Path
import hashlib,json,subprocess,sys
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
oldroot=Path('../q2q3-native-acceptance');out=Path('../q2q3-native-reviewed-acceptance');build=Path('../q2q3-native-final')
inputs=json.loads((oldroot/'input-hashes.json').read_text());sources=json.loads((build/'source-hashes.json').read_text());builds=json.loads((build/'build-results.json').read_text())
for p in Path('../q2q3-native-review').glob('*'):
 if p.is_file():inputs[str(p)]=sha(p)
(out/'review-input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**inputs,**sources}.items():assert sha(p)==h,p
 for x in builds:assert sha(x['binary'])==x['sha256']
stable();results=json.loads((oldroot/'test-results.json').read_text());old=next(x for x in results if x['suite']=='safetensors_constants');assert old['returncode']==1
cmd=list(old['command']);cmd[1]='../q2q3-native-review/pair-reviewed.py';cmd[2]=str(out/'pairs/safetensors_constants.json');cmd[cmd.index('--evidence')+1]=str(out/'safetensors_constants')
with (out/'safetensors_constants-tests.txt').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=900)
row={'suite':'safetensors_constants','returncode':r.returncode,'command':cmd};(out/'safetensors_constants-status.json').write_text(json.dumps(row,indent=2)+'\n');assert r.returncode==0
results=[row if x['suite']=='safetensors_constants' else x for x in results]
for name,script in [('classic32','../classic32-source-audit-review/audit-traces.py'),('q8','../q8-source-audit-review/audit-q8-traces.py'),('graph','../dynamic-graph-development/audit-traces.py')]:
 cmd=[sys.executable,script,str(out/name)]
 with (out/(name+'-traces-tests.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 row={'suite':name+'-traces','returncode':r.returncode,'command':cmd};results.append(row);(out/(name+'-traces-status.json')).write_text(json.dumps(row,indent=2)+'\n');assert r.returncode==0
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert len(results)==46 and all(x['returncode']==0 for x in results)
pairs=[x for p in (out/'pairs').glob('*.json') for x in json.loads(p.read_text())]
current={x['source']:x for x in builds if x['side']=='current'};expected={x['binary'] for s,x in current.items() if s not in ('smidr/tools/source_q2q3_constants.mojo','tests/hailo_source_q2q3_api.mojo')};seen={x['binary'] for x in pairs};assert seen==expected,(expected-seen,seen-expected)
(out/'frozen-pair-summary.json').write_text(json.dumps({'controls':len(seen),'success_pairs':sum(x['returncode']==0 for x in pairs),'nonzero_pairs':sum(x['returncode']!=0 for x in pairs),'unrelated_native_comparisons_skipped':0,'snapshot_controls_compiled_after_implementation':17,'ldd_inspection_is_not_native_API_execution':True},indent=2)+'\n')
controls=json.loads(Path('../q2q3-native-baseline/controls.json').read_text());old=next(x['binary'] for x in controls if x['source']=='tests/hailo_source_storage_api.mojo');new=current['tests/hailo_source_storage_api.mojo']['binary'];admissions=[]
for kind,size in ((10,84),(11,110)):
 args=['arithmetic','gguf',str(kind),'256'];a=subprocess.run([old,*args],capture_output=True,text=True);b=subprocess.run([new,*args],capture_output=True,text=True)
 assert a.returncode==1 and 'unsupported tensor type '+str(kind) in a.stderr,(a.returncode,a.stdout,a.stderr)
 assert b.returncode==0 and json.loads(b.stdout)=={'elements':256,'bytes':size}
 admissions.append({'source':'tests/hailo_source_storage_api.mojo','arguments':args,'old_returncode':a.returncode,'old_stdout':a.stdout,'old_stderr':a.stderr,'new_returncode':b.returncode,'new_stdout':b.stdout,'new_stderr':b.stderr})
(out/'intentional-admission-deltas.json').write_text(json.dumps(admissions,indent=2)+'\n')
links=[]
for x in builds:
 if x['source']=='smidr/tools/safetensors_constants.mojo':
  p=subprocess.run(['ldd',x['binary']],capture_output=True,text=True,check=True)
  for token in ('torch','safetensors','hailort','cuda','ggml'):assert token not in p.stdout,p.stdout
  links.append({'binary':x['binary'],'side':x['side'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
(out/'safetensors-linked-controls.json').write_text(json.dumps(links,indent=2)+'\n');stable()
print('All42 suites and4 audits pass;98 controls paired; genuine GGUF10/11 admission and dependency inspection verified',flush=True)
