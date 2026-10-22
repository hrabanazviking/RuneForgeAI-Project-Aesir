from pathlib import Path
from collections import Counter
import json,re,hashlib,struct,sys
root=Path(sys.argv[1]);identities=json.loads((root/'fixture-identities.json').read_text());copies=json.loads((root/'fixture-copies.json').read_text())
for name,h in identities.items():assert hashlib.sha256(Path(copies[name]).read_bytes()).hexdigest()==h,name
rows=[]
for path in sorted(root.glob('*.trace')):
 text=path.read_text();opened=Counter();closed=Counter();reads=[]
 assert not re.search(r'\b(connect|ioctl)\(',text),path
 for line in text.splitlines():
  assert not (('openat' in line or 'openat2' in line) and re.search(r'lib(torch|cuda|hailort)|/dev/(h1x|hailo|nvidia)',line)),(path,line)
  assert not ('mmap(' in line and '.weights>' in line),(path,line)
  m=re.search(r'openat2?\(.*\)\s*=\s*\d+<([^>]+)>',line)
  if m and m[1] in identities:opened[m[1]]+=1
  m=re.search(r'close\(\d+<([^>]+)>\)\s*=\s*0',line)
  if m and m[1] in identities:closed[m[1]]+=1
  m=re.search(r'pread64\(\d+<([^>]+\.weights)>,.*?, (\d+), (\d+)\)\s*=\s*(\d+)',line)
  if m:
   name,count,offset,got=m.groups();count,offset,got=map(int,(count,offset,got));raw=Path(copies[name]).read_bytes();end=8+struct.unpack_from('<Q',raw)[0]
   assert offset+count<=end and got==count,(path,line,end)
   reads.append(dict(path=name,count=count,offset=offset,header_end=end))
  assert not re.search(r'\bread\(\d+<[^>]+\.weights>',line),(path,line)
 assert opened==closed and opened,(path,opened,closed)
 rows.append(dict(trace=path.name,fixture_opens=sum(opened.values()),fixture_closes=sum(closed.values()),weight_header_reads=reads,connects=0,ioctls=0))
assert len(rows)==8,len(rows)
summary=dict(traces=len(rows),fixture_files=len(identities),fixture_opens=sum(r['fixture_opens'] for r in rows),fixture_closes=sum(r['fixture_closes'] for r in rows),weight_header_reads=sum(len(r['weight_header_reads']) for r in rows),all_weight_reads_within_header=True,weight_payload_mmaps=0,inference_library_or_device_opens=0,connects=0,ioctls=0,per_trace=rows)
(root/'trace-audit.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='per_trace'},indent=2))
