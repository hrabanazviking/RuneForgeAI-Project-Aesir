from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib,json,subprocess,sys
build=Path('../classic32-source-final');out=Path('../classic32-source-acceptance');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==78 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
source=json.loads((build/'source-hashes.json').read_text());inputs=json.loads((build/'input-hashes.json').read_text())
controls=json.loads(Path('../classic32-source-baseline/controls.json').read_text())
def stable():
 for p,h in {**source,**inputs}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256'],x['binary']
def paired(name,cmd):
 report=out/'pairs'/(name+'.json')
 return [sys.executable,'../classic32-source-development/pair-frozen.py',str(report),*cmd[1:]]
results=[]
def run(name,cmd,pair=True):
 stable();args=paired(name,cmd) if pair else cmd
 with (out/(name+'-tests.txt')).open('w') as f:p=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=900)
 row={'suite':name,'returncode':p.returncode,'command':args}
 (out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');print('suite',name,p.returncode,flush=True)
 stable();return row
new=[sys.executable,'tests/test_hailo_source_q8_constants.py','--binary',str(build/'q8-constants'),'--api',str(build/'q8-api'),'--tile',str(build/'tagged-source-weight-tiles'),'--tile-api',str(build/'tagged-source-weight-api'),'--inventory',str(build/'tagged-source-inventory'),'--semantic',str(build/'tagged-semantic-plan'),'--reference-library','../ggml-format-study/build/src/libggml-base.so.0.27.0','--strace','/usr/bin/strace','--evidence',str(out/'new')]
# Confirm actual build/control identities rather than assuming old labels.
by_source={x['source']:x['binary'] for x in rows}
for flag,src in [('--tile','smidr/tools/source_weight_tiles.mojo'),('--tile-api','tests/hailo_source_weight_tiles_api.mojo'),('--inventory','smidr/tools/source_inventory.mojo'),('--semantic','smidr/tools/semantic_plan.mojo')]:new[new.index(flag)+1]=by_source[src]
classic=list(new)
classic[classic.index('tests/test_hailo_source_q8_constants.py')]='tests/test_hailo_source_classic32_constants.py'
classic[classic.index('--binary')+1]=str(build/'classic32-constants')
classic[classic.index('--api')+1]=str(build/'classic32-api')
classic[classic.index('--evidence')+1]=str(out/'new')
results.append(run('classic32',classic,False));assert results[-1]['returncode']==0
results.append(run('classic32-traces',[sys.executable,'../classic32-source-development/audit-traces.py',str(out/'new')],False));assert results[-1]['returncode']==0
new[new.index('--evidence')+1]=str(out/'q8')
results.append(run('q8',new));assert results[-1]['returncode']==0
results.append(run('q8-traces',[sys.executable,'../q8-source-audit-review/audit-q8-traces.py',str(out/'q8')],False));assert results[-1]['returncode']==0
p=subprocess.run(['../classic32-source-development/layout-oracle'],capture_output=True,text=True,check=True)
assert json.loads(p.stdout)==[[2,32,18,0,-1,-1,2],[3,32,20,0,2,-1,4],[6,32,22,0,-1,2,6],[7,32,24,0,2,4,8]]
(out/'layout-oracle.json').write_text(p.stdout)

commands=[]
for file in ('../decoder-scaling-regression-accepted/test-results.json','../decoder-scaling-extra-accepted/test-results.json','../decoder-scaling-other-accepted/test-results.json','../decoder-scaling-accepted/test-results.json'):
 for row in json.loads(Path(file).read_text()):
  cmd=[]
  for arg in row['command']:
   if 'decoder-scaling-final' in arg:arg=str(build/Path(arg).name) if Path(arg).name!='decoder-scaling-final' else str(build)
   cmd.append(arg)
  if '--evidence' in cmd:cmd[cmd.index('--evidence')+1]=str(out/'legacy'/row['suite'])
  commands.append((row['suite'],cmd))
assert len(commands)==24
with ThreadPoolExecutor(max_workers=2) as pool:legacy=list(pool.map(lambda x:run(*x),commands))
results+=legacy;(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['returncode']==0 for x in legacy)
commands=[('context',[sys.executable,'tests/test_hailo_dynamic_rotary_context.py','--binary',str(build/'dynamic-context'),'--result',str(out/'context-report.json')]),('history',[sys.executable,'tests/test_hailo_dynamic_decoder_history.py','--history',str(build/'dynamic-history'),'--source',str(build/'dynamic-source'),'--frozen','../decoder-dynamic-baseline/scaling-graph','--evidence',str(out/'history')]),('graph',[sys.executable,'tests/test_hailo_dynamic_decoder_graph.py','--binary',str(build/'dynamic-graph'),'--api',str(build/'dynamic-graph-api'),'--gguf',str(build/'dynamic-graph-gguf'),'--frozen','../decoder-dynamic-baseline/scaling-graph','--mutations','../dynamic-graph-development/mutations.json','--strace','/usr/bin/strace','--evidence',str(out/'graph')]),('context-actions',[sys.executable,'tests/test_hailo_context_actions.py','--binary',str(build/'old-inspector'),'--ownership',str(build/'old-ownership'),'--oracle','../lcu-action-final/old-oracle','--strace','/usr/bin/strace','--evidence',str(out/'context-actions')]),('lcu-actions',[sys.executable,'tests/test_hailo_lcu_actions.py','--binary',str(build/'inspector'),'--ownership',str(build/'ownership'),'--oracle','../lcu-action-final/oracle','--strace','/usr/bin/strace','--evidence',str(out/'lcu-actions')])]
for name,cmd in commands:
 results.append(run(name,cmd));(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0,name
results.append(run('graph-traces',[sys.executable,'../dynamic-graph-development/audit-traces.py',str(out/'graph')],False))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(x['returncode']==0 for x in results)
allpairs=[p for file in (out/'pairs').glob('*.json') for p in json.loads(file.read_text())]
seen={Path(p['binary']).name for p in allpairs};expected={Path(x['binary']).name for x in controls}
assert seen==expected,(expected-seen,seen-expected)
(out/'frozen-pair-summary.json').write_text(json.dumps({'controls':len(seen),'success_pairs':sum(x['returncode']==0 for x in allpairs),'nonzero_pairs':sum(x['returncode']!=0 for x in allpairs),'canonical_control_names':sorted(seen)},indent=2)+'\n')
stable();print('All source/compiler/control suites and76 frozen-control comparisons passed',flush=True)

cmd=[str(build/'tagged-storage-api'),'arithmetic','gguf','2','256']
p=subprocess.run(cmd,capture_output=True,text=True);assert p.returncode==0 and json.loads(p.stdout)=={'elements':256,'bytes':144}
oldcmd=['../q8-source-final/tagged-storage-api',*cmd[1:]]
old=subprocess.run(oldcmd,capture_output=True,text=True);assert old.returncode!=0
(out/'intentional-admission-delta.json').write_text(json.dumps({'key':['tagged-storage-api','arithmetic','gguf','2','256'],'old_returncode':old.returncode,'old_stdout':old.stdout,'old_stderr':old.stderr,'new_returncode':p.returncode,'new_stdout':p.stdout,'new_stderr':p.stderr,'unrelated_comparisons_skipped':0},indent=2)+'\n')
stable()
