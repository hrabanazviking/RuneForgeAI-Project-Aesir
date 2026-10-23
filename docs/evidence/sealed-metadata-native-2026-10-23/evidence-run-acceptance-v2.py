from pathlib import Path
import json,subprocess
out=Path('../sealed-metadata-native-acceptance-v2');rows=[]
for job in json.load(open(out/'jobs.json')):
 cmd=[job['python'],str(out/'pair-all.py'),str(out/(job['suite']+'-pairs.json')),job['script'],*job['args'],'-v']
 with (out/(job['suite']+'-tests.txt')).open('wb') as stream:r=subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
 rows.append(dict(suite=job['suite'],arguments=cmd,returncode=r.returncode))
 (out/'results.json').write_text(json.dumps(rows,indent=2)+'\n');print(job['suite'],r.returncode,flush=True)
assert all(r['returncode']==0 for r in rows),rows
