from pathlib import Path
import concurrent.futures,json,subprocess
bins=Path('../decoder-activation-final');out=Path('../decoder-activation-extra-verification');out.mkdir(exist_ok=True)
commands=[('source_scalars',['python3','tests/test_hailo_source_scalars.py','--binaries',str(bins),'--baseline','../source-scalar-baseline','--public-config','../ordinary-model-metadata-study/config.json']),('rotary_recipes',['python3','tests/test_hailo_rotary_recipes.py','--binary',str(bins/'rotary-recipes'),'--api',str(bins/'rotary-api'),'--binaries',str(bins),'--baseline','../rotary-baseline','--oracle','../ordinary-modifier-study/rotary-final.json']),('decoder_graph_policy',['python3','tests/test_hailo_decoder_graph_policy.py','--binary',str(bins/'decoder-graph-policy'),'--api',str(bins/'decoder-graph-policy-api'),'--baseline','../decoder-graph-baseline/semantic-plan'])]
def run(pair):
 name,cmd=pair;cmd+=['--strace','/usr/bin/strace','--evidence',str(out/name)]
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 print(name,r.returncode,flush=True);return dict(suite=name,command=cmd,returncode=r.returncode)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(run,commands))
(out/'test-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert not any(r['returncode'] for r in rows)
