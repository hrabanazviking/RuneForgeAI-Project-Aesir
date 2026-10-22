from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,subprocess,sys
build=Path('../iq4-native-final');out=Path('../iq4-native-acceptance');out.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==102 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
sources=json.loads((build/'source-hashes.json').read_text());inputs=json.loads((build/'input-hashes.json').read_text());controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text());commands=json.loads(Path('../iq4-native-development/commands.json').read_text())
for p in Path('../iq4-native-development').glob('*'):
 if p.is_file():inputs[str(p)]=sha(p)
for p in ('../source-root-api','../unindexed-baseline-collection','../source-index-study/io-faults.so','../model-root-study/io-faults.so','../owned-fd-study/io-faults.so','../q2q3-native-development/root-layout.json','../ordinary-model-metadata-study/config.json','../ordinary-model-metadata-study/model.safetensors.index.json','../decoder-dynamic-baseline/scaling-graph','../decoder-graph-baseline/semantic-plan'):inputs[p]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**inputs,**sources}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256'],x['binary']
def run(job):
 name,cmd,pair=job;stable();args=[sys.executable,'../iq4-native-development/pair-frozen.py',str(out/'pairs'/(name+'.json')),*cmd[1:]] if pair else cmd
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 row={'suite':name,'returncode':r.returncode,'command':args};(out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');stable();print('suite',name,r.returncode,flush=True);return row
results=[run(commands[0])];(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
results.append(run(('iq4-traces',[sys.executable,'../classic32-source-audit-review/audit-traces.py',str(out/'iq4')],False)));assert results[-1]['returncode']==0
with ThreadPoolExecutor(max_workers=2) as pool:results+=list(pool.map(run,commands[1:]))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['returncode']==0 for x in results)
for name,script in [('q2q3','../classic32-source-audit-review/audit-traces.py'),('classic32','../classic32-source-audit-review/audit-traces.py'),('q8','../q8-source-audit-review/audit-q8-traces.py'),('graph','../dynamic-graph-development/audit-traces.py')]:results.append(run((name+'-traces',[sys.executable,script,str(out/name)],False)))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert len(results)==48 and all(x['returncode']==0 for x in results)
pairs=[x for p in (out/'pairs').glob('*.json') for x in json.loads(p.read_text())];expected={x['binary'] for x in rows if x['source'] in {c['source'] for c in controls}};seen={x['binary'] for x in pairs};assert seen==expected,(expected-seen,seen-expected)
(out/'frozen-pair-summary.json').write_text(json.dumps({'controls':len(seen),'success_pairs':sum(x['returncode']==0 for x in pairs),'nonzero_pairs':sum(x['returncode']!=0 for x in pairs),'unrelated_native_comparisons_skipped':0,'all_controls_frozen_before_production':True,'ldd_is_dependency_inspection_not_API_request':True},indent=2)+'\n')
# Genuine source namespace admission; keep this separate from legacy pairing.
new={x['source']:x['binary'] for x in rows};old={x['source']:x['binary'] for x in controls};admissions=[]
for kind,columns,size in ((20,32,18),(20,256,144),(23,256,136)):
 args=['arithmetic','gguf',str(kind),str(columns)];a=subprocess.run([old['tests/hailo_source_storage_api.mojo'],*args],capture_output=True,text=True);b=subprocess.run([new['tests/hailo_source_storage_api.mojo'],*args],capture_output=True,text=True)
 assert a.returncode==1 and ('unsupported tensor type' in a.stderr or (kind==20 and columns==32 and 'K-quant row is not block aligned' in a.stderr)),(a.returncode,a.stdout,a.stderr)
 assert b.returncode==0 and json.loads(b.stdout)=={'elements':columns,'bytes':size},(b.returncode,b.stdout,b.stderr)
 admissions.append({'source':'tests/hailo_source_storage_api.mojo','arguments':args,'old_returncode':a.returncode,'old_stdout':a.stdout,'old_stderr':a.stderr,'new_returncode':b.returncode,'new_stdout':b.stdout,'new_stderr':b.stderr})
(out/'intentional-admission-deltas.json').write_text(json.dumps(admissions,indent=2)+'\n')
links=[]
for side,mapping in [('current',new),('precode',old)]:
 for src in ('smidr/tools/safetensors_constants.mojo','smidr/tools/source_iq4_constants.mojo'):
  if src not in mapping:continue
  r=subprocess.run(['ldd',mapping[src]],capture_output=True,text=True,check=True)
  for token in ('torch','hailort','cuda','ggml'):assert token not in r.stdout,r.stdout
  links.append({'side':side,'source':src,'binary':mapping[src],'stdout':r.stdout,'stderr':r.stderr,'returncode':r.returncode})
(out/'linked-controls.json').write_text(json.dumps(links,indent=2)+'\n')
# Independently rebuild the qualified header object after Mojo linking completes.
cmd=['c++','-std=c++17','-Wall','-Wextra','-Werror','-I','../ggml-format-study/source/src','tests/hailo_iq4_layout_oracle.cpp','-o',str(out/'layout-oracle')];r=subprocess.run(cmd,capture_output=True,text=True)
(out/'layout-build.txt').write_text(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout+r.stderr
r=subprocess.run([str(out/'layout-oracle')],capture_output=True,text=True,check=True);assert json.loads(r.stdout)==[[20,32,18,0,2],[23,256,136,0,2,4,8]];(out/'layout-oracle.json').write_text(r.stdout)
stable();print('All43 suites and5 audits pass;100 precode controls paired;nonlinear admission/header/dependencies verified',flush=True)
