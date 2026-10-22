from pathlib import Path
import hashlib,json,subprocess
u=json.load(open('../sealed-safetensors-native-acceptance/universe.json'));out=Path('../sealed-safetensors-native-recording');rows=[]
for source,binary in sorted(u['current'].items()):
 p=subprocess.run(['readelf','-d',binary],capture_output=True,text=True,check=True)
 for token in ('libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl'):assert token not in p.stdout,(source,token)
 rows.append(dict(source=source,binary=binary,sha256=hashlib.sha256(Path(binary).read_bytes()).hexdigest(),command=['readelf','-d',binary],returncode=p.returncode,stdout=p.stdout,stderr=p.stderr))
(out/'dependency-inspection.json').write_text(json.dumps(dict(scope='ELF dynamic-section inspection only; separately audited syscall traces establish actual effects',entries=len(rows),forbidden_needed_matches=0,entries_by_source=rows),indent=2)+'\n')
print(len(rows),'ELF dependency tables inspected separately from actual syscall effects')
