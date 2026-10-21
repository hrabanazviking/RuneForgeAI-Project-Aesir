from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path.cwd();out=Path('../decoder-scaling-baseline');out.mkdir(exist_ok=True)
rows=json.loads(Path('../decoder-window-final/build-results.json').read_text());assert len(rows)==58
frozen=[]
for r in rows:
 p=Path(r['binary']);assert r['returncode']==0 and hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
 target=out/p.name;assert not target.exists(),target;shutil.copy2(p,target)
 assert hashlib.sha256(target.read_bytes()).hexdigest()==r['sha256'] and target.stat().st_mode==p.stat().st_mode
 frozen.append(dict(source=r['source'],binary=str(target),sha256=r['sha256'],mode=oct(target.stat().st_mode&0o777),returncode=0))
source=json.loads(Path('../decoder-window-final/source-hashes.json').read_text());assert len(source)==188
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
(out/'build-results.json').write_text(json.dumps(frozen,indent=2)+'\n');(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
(out/'baseline.json').write_text(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),entrypoints=58,source_files=188,acceptance_methods=154,acceptance_calls=5455,model_execution=False,device_execution=False),indent=2)+'\n')
print('Frozen58 entrypoints/188 Mojo sources; no production edits')
