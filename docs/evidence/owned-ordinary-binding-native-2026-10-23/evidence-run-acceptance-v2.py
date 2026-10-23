from pathlib import Path
import json,subprocess
out=Path('../owned-ordinary-binding-native-acceptance-v3');rows=[]
for job in json.load(open(out/'jobs.json')):
 cmd=[job['python'],str(out/'pair-all.py'),str(out/(job['suite']+'-pairs.json')),job['script'],*job['args']]
 with (out/(job['suite']+'-tests.txt')).open('wb') as stream:r=subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,timeout=900,env=__import__('os').environ|{'PYTHONDONTWRITEBYTECODE':'1'})
 rows.append(dict(suite=job['suite'],arguments=cmd,returncode=r.returncode));(out/'results.json').write_text(json.dumps(rows,indent=2)+'\n');print(job['suite'],r.returncode,flush=True)
assert all(r['returncode']==0 for r in rows),[(r['suite'],r['returncode']) for r in rows]
