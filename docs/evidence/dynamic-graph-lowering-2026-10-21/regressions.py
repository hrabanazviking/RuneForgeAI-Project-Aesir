from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,hashlib,sys
out=Path('../dynamic-graph-regressions');out.mkdir(exist_ok=False)
controls=json.loads(Path('../dynamic-graph-baseline/controls.json').read_text())
results=json.loads(Path('../dynamic-graph-final/build-results.json').read_text())
assert len(results)==70 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in results)
for r in results:assert hashlib.sha256(Path(r['binary']).read_bytes()).hexdigest()==r['sha256']
for r in controls:assert hashlib.sha256(Path(r['binary']).read_bytes()).hexdigest()==r['sha256']
files=['../decoder-scaling-regression-accepted/test-results.json','../decoder-scaling-extra-accepted/test-results.json','../decoder-scaling-other-accepted/test-results.json','../decoder-scaling-accepted/test-results.json']
commands=[]
for name in files:
 for row in json.loads(Path(name).read_text()):
  cmd=row['command'];converted=[]
  for arg in cmd:
   if 'decoder-scaling-final' in arg:
    arg=str(Path('../dynamic-graph-final')/Path(arg).name) if Path(arg).name!='decoder-scaling-final' else '../dynamic-graph-final'
   converted.append(arg)
  if '--evidence' in converted:converted[converted.index('--evidence')+1]=str(out/row['suite'])
  commands.append((row['suite'],converted))
assert len(commands)==24

def run(item):
 name,cmd=item
 paired=[sys.executable,'../dynamic-graph-development/run-frozen-pairs.py',str(out/(name+'-frozen-pairs.json')),*cmd[1:]]
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(paired,stdout=f,stderr=subprocess.STDOUT)
 result=dict(suite=name,returncode=r.returncode,command=paired)
 (out/(name+'-result.json')).write_text(json.dumps(result,indent=2)+'\n');print(name,r.returncode,flush=True)
 return result
with ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(run,commands))
(out/'test-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['returncode']==0 for r in rows),[r for r in rows if r['returncode']]
print('24 targeted regression suites completed with full frozen output comparisons')
