from pathlib import Path
import concurrent.futures,json,subprocess
bins=Path('../decoder-activation-final');out=Path('../decoder-activation-other-regressions');out.mkdir(exist_ok=True)
common=['--public-config','../ordinary-model-metadata-study/config.json','--header0','../ordinary-binding-study/0-header.json','--header1','../ordinary-binding-study/1-header.json','--strace','/usr/bin/strace']
commands=[('decoder_projections',['python3','tests/test_hailo_decoder_projections.py','--binary',str(bins/'decoder-projections'),'--api',str(bins/'decoder-projections-api'),*common]),('ordinary_projection_schema',['python3','tests/test_hailo_ordinary_projection_schema.py','--binary',str(bins/'ordinary-schema'),'--api',str(bins/'ordinary-schema-api'),'--legacy',str(bins/'decoder-projections'),'--frozen','../ordinary-projection-schema-baseline/decoder-projections',*common])]
def run(pair):
 name,command=pair;command+=['--evidence',str(out/name)]
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT)
 return dict(suite=name,returncode=r.returncode,command=command)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(run,commands))
(out/'test-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert not any(r['returncode'] for r in rows)
print(rows)
