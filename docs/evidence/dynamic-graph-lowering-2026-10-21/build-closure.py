from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,os,subprocess,time
out=Path('../dynamic-graph-final');out.mkdir(exist_ok=False)
source={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for top in ('smidr','tests') for p in Path(top).rglob('*.mojo')}
(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
controls=json.loads(Path('../dynamic-graph-baseline/controls.json').read_text())
pairs=[(r['source'],Path(r['binary']).name) for r in controls]
pairs += [('smidr/tools/dynamic_decoder_graph.mojo','dynamic-graph'),('tests/hailo_dynamic_decoder_graph.mojo','dynamic-graph-api'),('tests/hailo_dynamic_graph_gguf.mojo','dynamic-graph-gguf')]
assert len(pairs)==70 and len(set(name for _,name in pairs))==70

def build(pair):
 src,name=pair;log=out/(name+'-build.txt')
 with log.open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(out/name)],stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 row=dict(source=src,binary=str(out/name),returncode=r.returncode,diagnostic_bytes=log.stat().st_size,sha256=hashlib.sha256((out/name).read_bytes()).hexdigest() if r.returncode==0 else None)
 (out/(name+'-result.json')).write_text(json.dumps(row,indent=2)+'\n');print(name,r.returncode,log.stat().st_size,flush=True)
 return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),[r for r in rows if r['returncode'] or r['diagnostic_bytes']]
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
for r in controls:assert hashlib.sha256(Path(r['binary']).read_bytes()).hexdigest()==r['sha256']
print('Final70 builds completed; source snapshot and frozen controls unchanged.',flush=True)
