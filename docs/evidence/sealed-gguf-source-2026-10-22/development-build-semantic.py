from pathlib import Path
import hashlib,json,os,shutil,subprocess
out=Path('../sealed-gguf-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(out/'build-results.json'));assert len(rows)==108 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
sources=json.load(open(out/'source-hashes.json'))
for p,h in sources.items():assert sha(p)==h,p
src='tests/hailo_sealed_semantic_api.mojo';binary=out/'sealed-semantic-api';log=out/'sealed-semantic-api.build.log';env=os.environ.copy();env['MODULAR_CACHE_DIR']='../mojo-cache'
with log.open('w') as f:r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)],stdout=f,stderr=subprocess.STDOUT,timeout=600,env=env)
row={'source':src,'binary':str(binary.resolve()),'returncode':r.returncode,'diagnostic_bytes':log.stat().st_size,'sha256':sha(binary) if binary.exists() else None}
(out/'semantic-build-result.json').write_text(json.dumps(row,indent=2)+'\n');assert r.returncode==0 and row['diagnostic_bytes']==0
# The additional leaf changes none of the original 108 source import closures.
(out/'broad-build-results.json').write_text(json.dumps(rows,indent=2)+'\n');rows.append(row);(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
sources[src]=sha(src);target=out/'source-snapshot'/src;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
for p,h in sources.items():assert sha(p)==h,p
assert len(sources)==660;(out/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n')
print('109 clean stable builds, including additional semantic borrowing leaf; no native tests during linking',flush=True)
