from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
out=Path('../decoder-bias-hardened');out.mkdir(exist_ok=True)
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for root in ('smidr','tests') for p in Path(root).glob('**/*.mojo')}
(out/'source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
pairs=[(r['source'],Path(r['binary']).name) for r in json.loads(Path('../decoder-bias-baseline/build-results.json').read_text())]
pairs += [('smidr/tools/decoder_bias_graph.mojo','decoder-bias-graph'),('tests/hailo_decoder_bias_api.mojo','decoder-bias-api'),('tests/hailo_bias_ownership.mojo','bias-ownership'),('tests/hailo_bias_gguf.mojo','bias-gguf'),('tests/hailo_bias_consumers.mojo','bias-consumers')]
def build(pair):
 source,name=pair;target=out/name
 with (out/(name+'-build.txt')).open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',source,'-o',str(target)],env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),stdout=f,stderr=subprocess.STDOUT)
 result=dict(source=source,binary=str(target),returncode=r.returncode,sha256=hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None)
 print(name,r.returncode,flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n')
assert not any(r['returncode'] for r in results)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in manifest.items())
