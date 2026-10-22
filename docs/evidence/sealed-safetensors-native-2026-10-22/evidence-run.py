from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parent
u=json.load(open(root/'universe.json'));sources=json.load(open('../sealed-safetensors-native-final/source-hashes.json'));inputs=json.load(open('../sealed-safetensors-native-baseline/test-input-hashes.json'))
p=Path('tests/test_hailo_sealed_safetensors_source.py');inputs[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest();(root/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
for name in inputs:
 p=root/'test-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(Path(name).read_bytes())
binary_paths=set(u['current'].values())|set(u['frozen'].values())
for job in json.load(open(root/'jobs.json')):
 for value in job['args']:
  p=Path(value)
  if p.is_file() and (value.endswith('.so') or p.read_bytes()[:4]==b'\x7fELF'):binary_paths.add(str(p.resolve()))
binary_hashes={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in binary_paths};(root/'binary-hashes.json').write_text(json.dumps(binary_hashes,indent=2)+'\n')
auxiliary={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('tests').rglob('*.c')}
(root/'auxiliary-c-source-hashes.json').write_text(json.dumps(auxiliary,indent=2)+'\n')
for name in auxiliary:
 p=root/'auxiliary-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(Path(name).read_bytes())
def stable():
 for name,digest in {**sources,**inputs,**binary_hashes,**auxiliary}.items():assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest,name
results=[]
# Run the new suite first, then every original suite. Preserve all outcomes.
jobs=json.load(open(root/'jobs.json'));jobs=jobs[-1:]+jobs[:-1]
for job in jobs:
 stable();cmd=[job['python'],str(root/'pair-all.py'),str(root/(job['suite']+'-pairs.json')),job['script'],*job['args']]
 with (root/(job['suite']+'.txt')).open('w') as log:p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=2400)
 stable();row=dict(suite=job['suite'],command=cmd,returncode=p.returncode);results.append(row);(root/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');print(job['suite'],p.returncode,flush=True)
assert all(r['returncode']==0 for r in results),results
pairs=[x for p in root.glob('*-pairs.json') for x in json.load(open(p))];seen={x['binary'] for x in pairs};assert seen==set(u['pairs']),(set(u['pairs'])-seen,seen-set(u['pairs']))
print('All115 frozen controls covered, no omitted comparisons.',flush=True)
