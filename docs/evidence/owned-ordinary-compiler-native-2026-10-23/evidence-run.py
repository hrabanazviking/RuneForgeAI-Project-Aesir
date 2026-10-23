from pathlib import Path
import hashlib,json,os,subprocess
out=Path('../owned-ordinary-compiler-native-acceptance');final=Path('../owned-ordinary-compiler-native-final-v2')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,copy in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 for p,d in json.load(open(final/name)).items():assert h(Path(p))==h(final/copy/p)==d,p
for r in json.load(open(final/'build-results.json')):assert r['returncode']==r['diagnostic_bytes']==0 and h(Path(r['binary']))==r['sha256']
for r in json.load(open(final/'c-build-results.json')):assert r['returncode']==r['diagnostic_bytes']==0 and h(Path(r['binary']))==r['binary_sha256'] and h(Path(r['source']))==r['source_sha256']
rows=[]
for j in json.load(open(out/'jobs.json')):
 cmd=[j['python'],str(out/'pair-all.py'),str(out/(j['suite']+'-pairs.json')),j['script'],*j['args']]
 with (out/(j['suite']+'-tests.txt')).open('wb') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=1200,env=os.environ|{'PYTHONDONTWRITEBYTECODE':'1'})
 rows.append(dict(suite=j['suite'],arguments=cmd,returncode=r.returncode));(out/'results.json').write_text(json.dumps(rows,indent=2)+'\n');print(j['suite'],r.returncode,flush=True)
 if r.returncode:break
assert len(rows)==len(json.load(open(out/'jobs.json'))) and all(r['returncode']==0 for r in rows),rows
