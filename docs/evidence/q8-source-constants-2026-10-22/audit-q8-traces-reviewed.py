"""Audit read-only whole-fixture mappings and cleanup; no header-only claim."""
from collections import Counter
from pathlib import Path
import hashlib,json,re,sys
def logical_lines(raw):
 pending={};result=[]
 for line in raw.splitlines():
  match=re.match(r'^(\d+)\s+(.*)$',line)
  assert match,('missing strace PID',line)
  pid,body=match.groups()
  if '<unfinished ...>' in body:
   assert pid not in pending,('duplicate unfinished syscall',line)
   pending[pid]=body.split('<unfinished ...>',1)[0];continue
  resumed=re.match(r'<\.\.\. (\w+) resumed>(.*)',body)
  if resumed:
   assert pid in pending,('unpaired resumed syscall',line)
   prefix=pending.pop(pid)
   assert prefix.startswith(resumed[1]+'('),('wrong resumed syscall',line,prefix)
   body=prefix+resumed[2]
  result.append(pid+' '+body)
 assert not pending,('incomplete syscalls',pending)
 return result
root=Path(sys.argv[1]);ids=json.loads((root/'fixtures.json').read_text());rows=[]
for trace in sorted(root.glob('trace-*.strace')):
 text=trace.read_text()
 for token in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','libggml','connect(','ioctl('):assert token not in text,(trace,token)
 opened=[];closed=[];maps=[];unmaps=[]
 for line in logical_lines(text):
  pid=line.split()[0]
  if 'openat(' in line and '.gguf' in line:
   m=re.search(r'openat\(.*?"([^"]+\.gguf)".*?= (\d+)<',line);assert m,line
   assert 'O_RDONLY' in line and 'O_RDWR' not in line and 'O_WRONLY' not in line,line
   opened.append((pid,m[2],Path(m[1]).name))
  m=re.search(r'close\((\d+)<([^>]+\.gguf)>\s*\)\s*= 0',line)
  if m:closed.append((pid,m[1],Path(m[2]).name))
  if 'mmap(' in line and '.gguf>' in line:
   m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)<([^>]+\.gguf)>, 0\s*\) = (0x[0-9a-f]+)',line);assert m,line
   name=Path(m[3]).name;assert int(m[1])==ids[name]['bytes'],(trace,line)
   maps.append((pid,m[4],int(m[1])));
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if m:unmaps.append((pid,m[1],int(m[2])))
 assert opened and Counter(opened)==Counter(closed),(trace,opened,closed)
 assert maps and not Counter(maps)-Counter(unmaps),(trace,maps,unmaps)
 rows.append({'trace':trace.name,'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'fixture_opens':len(opened),'fixture_closes':len(closed),'whole_readonly_shared_maps':len(maps),'matching_unmaps':len(maps)})
assert len(rows)==10,len(rows)
result={'traces':rows,'totals':{k:sum(x[k] for x in rows) for k in ('fixture_opens','fixture_closes','whole_readonly_shared_maps','matching_unmaps')},'forbidden_access_matches':0,'whole_gguf_fixture_mmaps_include_payload':True,'model_or_layer_evaluation':False}
(root/'trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['totals']))
