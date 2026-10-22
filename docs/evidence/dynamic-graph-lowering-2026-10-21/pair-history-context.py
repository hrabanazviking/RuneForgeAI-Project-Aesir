# Additional full frozen stdout pairing for the three phase1/context controls.
# Run only after the current complete final verifier succeeds.
from pathlib import Path
import subprocess,json,sys,hashlib
root=Path('../dynamic-graph-acceptance');out=root/'additional-frozen';out.mkdir(exist_ok=False)
rows=json.loads((root/'test-results.json').read_text());assert len(rows)==5 and all(r['returncode']==0 for r in rows)
commands=[('context',['tests/test_hailo_dynamic_rotary_context.py','--binary','../dynamic-graph-final/dynamic-context','--result',str(out/'context-result.json')]),('history',['tests/test_hailo_dynamic_decoder_history.py','--history','../dynamic-graph-final/dynamic-history','--source','../dynamic-graph-final/dynamic-source','--frozen','../decoder-dynamic-baseline/scaling-graph','--evidence',str(out/'history')])]
results=[]
for name,args in commands:
 cmd=[sys.executable,'../dynamic-graph-development/run-frozen-pairs.py',str(out/(name+'-frozen-pairs.json')),*args]
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 results.append(dict(name=name,returncode=r.returncode,command=cmd));assert r.returncode==0,(name,out/(name+'-test.txt'))
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n')
reports=[*Path('../dynamic-graph-regressions').glob('*-frozen-pairs.json'),*out.glob('*-frozen-pairs.json')]
compared=[r for p in reports for r in json.loads(p.read_text())['calls']]
diagnostics=[r for p in reports for r in json.loads(p.read_text())['diagnostics']]
success={str(Path(r['binary']).resolve()) for r in compared}
refused={str(Path(r['binary']).resolve()) for r in diagnostics}
summary=dict(full_stdout_pairs=len(compared),unique_success_binaries=len(success),unique_binaries=len(success|refused),mutation_only_binaries=sorted(refused-success),handled_diagnostic_pairs=len(diagnostics),reports={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in reports})
(out/'comparison-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
