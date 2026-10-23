from pathlib import Path
import hashlib,json,subprocess
out=Path('../owned-ordinary-binding-native-recording');out.mkdir(exist_ok=True);rows=[]
for r in json.load(open('../owned-ordinary-binding-native-final-v2/build-results.json')):
 p=Path(r['binary']);cmd=['readelf','-d',str(p)];x=subprocess.run(cmd,capture_output=True,text=True);assert x.returncode==0 and not x.stderr
 assert all(v not in x.stdout.lower() for v in ('hailort','cuda','torch','onnx','crypto','ssl','ggml')),x.stdout
 rows.append(dict(source=r['source'],binary=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),arguments=cmd,stdout=x.stdout,stderr=x.stderr,returncode=x.returncode))
(out/'dependency-inspection.json').write_text(json.dumps(dict(scope='ELF dependency tables, separate from observed effects',entries=rows),indent=2)+'\n');print(len(rows),'ELF tables inspected')
