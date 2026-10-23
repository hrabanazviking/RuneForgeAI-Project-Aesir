from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent;rows=[]
for r in json.load(open('../sealed-metadata-native-final/build-results.json')):
 p=Path(r['binary']);cmd=['readelf','-d',str(p)];result=subprocess.run(cmd,capture_output=True,text=True);assert result.returncode==0,result.stderr
 assert all(x not in result.stdout.lower() for x in ('hailort','cuda','torch','onnx','crypto','ssl','ggml')),result.stdout
 rows.append(dict(source=r['source'],binary=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),arguments=cmd,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
(out/'dependencies.json').write_text(json.dumps(dict(scope='ELF dependency inspection separate from observed syscall effects',entries=rows),indent=2)+'\n')
print(len(rows),'ELF tables inspected')
