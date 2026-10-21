from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
out=Path('../rotary-final')
pairs=[('smidr/tools/decoder_graph_policy.mojo','decoder-graph-policy'),('tests/hailo_decoder_graph_policy_api.mojo','decoder-graph-policy-api')]
def build(pair):
 source,name=pair;target=out/name
 with (out/(name+'-build.txt')).open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine',source,'-o',str(target)],env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),stdout=f,stderr=subprocess.STDOUT)
 result=dict(source=source,binary=str(target),returncode=r.returncode,sha256=hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None)
 print(name,r.returncode,flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(build,pairs))
p=out/'build-results.json';rows=json.loads(p.read_text());rows+=results;p.write_text(json.dumps(rows,indent=2)+'\n')
assert not any(r['returncode'] for r in rows)
