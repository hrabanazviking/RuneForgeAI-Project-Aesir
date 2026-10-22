from pathlib import Path
import hashlib,json,re
root=Path('../sealed-gguf-native-acceptance-v2');files=[p for p in sorted(root.rglob('*.strace')) if 'sealed' not in p.relative_to(root).parts]
def logical(raw):
 pending={};out=[]
 for line in raw.splitlines():
  m=re.match(r'^(\d+)\s+(.*)$',line)
  if m:pid,body=m.groups()
  else:
   assert re.match(r'^(?:[A-Za-z_?][A-Za-z_0-9?]*\(|<\.\.\.|---|\+\+\+)',line),line
   pid,body='unprefixed-single-trace-scope',line
  resumed=re.match(r'<\.\.\. (\w+|\?\?\?) resumed>(.*)',body)
  if resumed:
   before=pending.pop(pid);assert before.startswith(resumed[1]+'('),(line,before)
   body=before+resumed[2]
   # strace can emit a resumed-but-unreturned call at exit_group termination.
   # Keep the literal incomplete tail as opaque; do not invent a return/effect.
   if '<unfinished ...>' in body:
    assert body.rstrip().endswith('= ?'),line
    out.append((pid,body));continue
  elif '<unfinished ...>' in body:
   assert pid not in pending,line
   pending[pid]=body.split('<unfinished ...>',1)[0];continue
  out.append((pid,body))
 assert not pending,pending
 return out
files+=sorted(Path('../sealed-gguf-native-closure/acceptance').rglob('*.strace'))
rows=[];opaque=[]
for path in files:
 raw=path.read_text();pending={};calls=[]
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):
  assert token not in raw,(path,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),(path,'actual fatal signal')
 for pid,body in logical(raw):
  calls.append((pid,body))
  if body.startswith('???(') or '<unfinished ...>' in body:opaque.append({'trace':str(path),'pid':pid,'record':body,'classification':'opaque; no inferred effect'})
 rows.append({'trace':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'decoded_records':len(calls),'forbidden_access_matches':0})
result={'trace_count':len(rows),'decoded_records':sum(r['decoded_records'] for r in rows),'opaque_records':opaque,'forbidden_access_matches':0,'dependency_inspection':'Separate dependency-inspection.json; these records are only actual traced native calls.','traces':rows}
(root/'all-legacy-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='traces'}))
