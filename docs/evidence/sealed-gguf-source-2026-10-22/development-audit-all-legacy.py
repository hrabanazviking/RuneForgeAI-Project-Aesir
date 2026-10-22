from pathlib import Path
import hashlib,json,re
root=Path('../sealed-gguf-native-acceptance');files=[p for p in sorted(root.rglob('*.strace')) if 'sealed' not in p.relative_to(root).parts]
rows=[];opaque=[]
for path in files:
 raw=path.read_text();pending={};calls=[]
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):
  assert token not in raw,(path,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),(path,'actual fatal signal')
 for line in raw.splitlines():
  m=re.match(r'^(\d+)\s+(.*)$',line)
  if m:pid,body=m.groups()
  else:
   assert re.match(r'^(?:[A-Za-z_?][A-Za-z_0-9?]*\(|<\.\.\.|---|\+\+\+)',line),(path,line)
   pid,body='unprefixed-single-trace-scope',line
  if '<unfinished ...>' in body:
   assert pid not in pending,(path,line);pending[pid]=body.split('<unfinished ...>',1)[0];continue
  m=re.match(r'<\.\.\. (\w+|\?\?\?) resumed>(.*)',body)
  if m:
   before=pending.pop(pid);assert before.startswith(m[1]+'('),(path,line,before);body=before+m[2]
  calls.append((pid,body))
  if body.startswith('???('):opaque.append({'trace':str(path),'pid':pid,'record':body,'classification':'opaque; no inferred effect'})
 assert not pending,(path,pending)
 rows.append({'trace':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'decoded_records':len(calls),'forbidden_access_matches':0})
result={'trace_count':len(rows),'decoded_records':sum(r['decoded_records'] for r in rows),'opaque_records':opaque,'forbidden_access_matches':0,'dependency_inspection':'Separate dependency-inspection.json; these records are only actual traced native calls.','traces':rows}
(root/'all-legacy-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='traces'}))
