from pathlib import Path
import time,subprocess,json,hashlib,sys
build=Path('../dynamic-graph-final');out=Path('../dynamic-graph-acceptance');out.mkdir(exist_ok=False)
while not (build/'build-results.json').exists():time.sleep(2)
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==70 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
source=json.loads((build/'source-hashes.json').read_text());assert len(source)==208
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
commands=[('legacy24',[sys.executable,'../dynamic-graph-development/regressions.py']),
('context',[sys.executable,'tests/test_hailo_dynamic_rotary_context.py','--binary',str(build/'dynamic-context'),'--result',str(out/'context-result.json')]),
('history',[sys.executable,'tests/test_hailo_dynamic_decoder_history.py','--history',str(build/'dynamic-history'),'--source',str(build/'dynamic-source'),'--frozen','../decoder-dynamic-baseline/scaling-graph','--evidence',str(out/'history')]),
('graph',[sys.executable,'tests/test_hailo_dynamic_decoder_graph.py','--binary',str(build/'dynamic-graph'),'--api',str(build/'dynamic-graph-api'),'--gguf',str(build/'dynamic-graph-gguf'),'--frozen','../decoder-dynamic-baseline/scaling-graph','--mutations','../dynamic-graph-development/mutations.json','--strace','/usr/bin/strace','--evidence',str(out/'graph')]),
('trace_audit',[sys.executable,'../dynamic-graph-development/audit-traces.py',str(out/'graph')])]
results=[]
for name,cmd in commands:
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 row=dict(name=name,returncode=r.returncode,command=cmd);results.append(row)
 (out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');print(name,r.returncode,flush=True)
 assert r.returncode==0,(name,out/(name+'-test.txt'))
 assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
print('All final targeted graph/legacy/context/history/audit runs completed;208-source snapshot unchanged.')
