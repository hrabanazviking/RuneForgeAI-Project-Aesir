from pathlib import Path
import concurrent.futures,hashlib,json,subprocess,os
out=Path('../decoder-window-final');out.mkdir(exist_ok=True)
pairs=[(r['source'],Path(r['binary']).name) for r in json.loads(Path('../decoder-window-baseline/build-results.json').read_text())]+[('smidr/tools/decoder_window_graph.mojo','window-graph'),('tests/hailo_decoder_window_api.mojo','window-api'),('tests/hailo_window_source.mojo','window-source'),('tests/hailo_window_ownership.mojo','window-ownership'),('tests/hailo_window_gguf.mojo','window-gguf'),('tests/hailo_window_indices.mojo','window-indices'),('tests/hailo_window_policy.mojo','window-policy')]
assert len(pairs)==58
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for root in ('smidr','tests') for p in Path(root).glob('**/*.mojo')};(out/'source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
def build(pair):
 source,name=pair;target=out/name
 with (out/(name+'-build.txt')).open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',source,'-o',str(target)],env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),stdout=f,stderr=subprocess.STDOUT)
 print(name,r.returncode,flush=True);return dict(source=source,binary=str(target),returncode=r.returncode,sha256=hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(r['returncode']==0 for r in rows)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in manifest.items())
