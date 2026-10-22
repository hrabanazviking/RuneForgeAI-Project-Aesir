from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path('../sealed-gguf-native-acceptance-v2/sealed');runs=json.load(open(root/'runs.json'));manifest=json.load(open(root/'trace-manifest.json'));ids=json.load(open(root/'fixtures.json'))
def logical(raw):
 pending={};out=[]
 for line in raw.splitlines():
  m=re.match(r'^(\d+)\s+(.*)$',line);assert m,line
  pid,body=m.groups()
  if '<unfinished ...>' in body:
   assert pid not in pending,line;pending[pid]=body.split('<unfinished ...>',1)[0];continue
  m=re.match(r'<\.\.\. (\w+|\?\?\?) resumed>(.*)',body)
  if m:
   before=pending.pop(pid);assert before.startswith(m[1]+'('),(line,before);body=before+m[2]
  out.append((pid,body))
 assert not pending,pending
 return out
rows=[];opaque=[]
for item in manifest:
 trace=Path(item['trace']);r=runs[item['run_index']];text=trace.read_text();source=r['source'];created=[];closed=[];maps=[];unmaps=[];sourceopens=[];sourcecloses=[];reads=[];writes=[];seals=[];label='/aesir-sealed-provenance-must-not-open'
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert token not in text,(trace,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',text),(trace,'actual fatal signal')
 for pid,line in logical(text):
  if line.startswith('???('):opaque.append({'trace':str(trace),'pid':pid,'line':line,'classification':'opaque; no inferred effect'})
  if ('openat(' in line or 'open(' in line) and label in line:raise AssertionError(('provenance label reopened',trace,line))
  m=re.search(r'memfd_create\("aesir-source-copy", MFD_CLOEXEC\|MFD_ALLOW_SEALING\s*\)\s*= (\d+)<(/memfd:[^>]+)>',line)
  if m:created.append((pid,m[1],m[2]))
  m=re.search(r'close\((\d+)<(/memfd:[^>]+)>(?:\(deleted\))?\s*\)\s*= 0',line)
  if m:closed.append((pid,m[1],m[2]))
  if 'mmap(' in line and '/memfd:' in line:
   assert 'PROT_READ, MAP_SHARED' in line,line
   m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)<(/memfd:[^>]+)>(?:\(deleted\))?, 0\s*\)\s*= (0x[0-9a-f]+)',line);assert m,line
   extent,fd,target,address=m.groups();extent=int(extent);assert extent==ids[source]['bytes'],(line,source)
   assert (pid,fd,target) in created,('mapped exact fd not created in this owner',line,created)
   maps.append({'pid':pid,'fd':fd,'target':target,'address':address,'extent':extent})
  if 'munmap(' in line:
   m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
   if m and any(x['address']==m[1] for x in maps):unmaps.append((pid,m[1],int(m[2])))
  if source and source in line:
   m=re.search(r'openat\(.*?"'+re.escape(source)+r'".*?\)\s*= (\d+)<',line)
   if m:
    if 'O_RDWR' in line or 'O_WRONLY' in line:assert r['mutation'] in ('truncate','mutate','replace'),line
    else:assert 'O_RDONLY' in line,line
    sourceopens.append((pid,m[1],source))
   m=re.search(r'close\((\d+)<'+re.escape(source)+r'>(?:\(deleted\))?\s*\)\s*= 0',line)
   if m:sourcecloses.append((pid,m[1],source))
   if 'mmap(' in line:
    assert 'path_capacity' in r['arguments'] and 'PROT_READ, MAP_SHARED' in line,line
    m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)<[^>]+>, 0\s*\)\s*= (0x[0-9a-f]+)',line);assert m,line
    extent,fd,address=m.groups();assert int(extent)==ids[source]['bytes'],line
    maps.append({'pid':pid,'fd':fd,'target':source,'address':address,'extent':int(extent)})
  if 'pread64(' in line and ((source and source in line) or '/memfd:' in line):
   m=re.search(r'pread64\((\d+)<([^>]+)>(?:\(deleted\))?, .*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line);assert m,line
   fd,target,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n));assert 0<want<=4096 and 0<n<=want,line
   assert offset>=0 and want<=ids[source]['bytes']-offset,line
   reads.append({'pid':pid,'fd':int(fd),'target':target,'offset':offset,'requested':want,'returned':n})
  if 'pwrite64(' in line and '/memfd:' in line:
   m=re.search(r'pwrite64\((\d+)<[^>]+>(?:\(deleted\))?, .*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line);assert m,line
   fd,want,offset,n=map(int,m.groups());assert 0<want<=4096 and offset>=0 and 0<n<=want and want<=ids[source]['bytes']-offset,line
   writes.append({'pid':pid,'fd':fd,'offset':offset,'requested':want,'returned':n})
  if 'fcntl(' in line and '/memfd:' in line and 'F_ADD_SEALS' in line:
   assert '= 0' in line,line
   for bit in ('F_SEAL_SEAL','F_SEAL_SHRINK','F_SEAL_GROW','F_SEAL_WRITE'):assert bit in line,line
   seals.append(line)
 assert Counter(created)==Counter(closed),(trace,created,closed)
 assert Counter(sourceopens)==Counter(sourcecloses),(trace,sourceopens,sourcecloses)
 assert Counter((x['pid'],x['address'],x['extent']) for x in maps)==Counter(unmaps),(trace,maps,unmaps)
 if r['returncode']==0 and source and maps and 'path_capacity' not in r['arguments']:assert created and seals,(trace,r)
 rows.append({'trace':str(trace),'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'returncode':r['returncode'],'fault':r['fault'],'source_opens':len(sourceopens),'source_closes':len(sourcecloses),'memfd_creates':len(created),'memfd_closes':len(closed),'maps':maps,'unmaps':unmaps,'kernel_reads':reads,'kernel_writes':writes,'seal_operations':len(seals)})
assert len(rows)==len(list(root.glob('trace-*.strace')))
result={'trace_count':len(rows),'totals':{k:sum(r[k] for r in rows) for k in ('source_opens','source_closes','memfd_creates','memfd_closes','seal_operations')},'readonly_sealed_maps':sum(sum(x['target'].startswith('/memfd:') for x in r['maps']) for r in rows),'readonly_path_maps':sum(sum(not x['target'].startswith('/memfd:') for x in r['maps']) for r in rows),'exact_capacity_unmaps':sum(len(r['unmaps']) for r in rows),'kernel_reads':sum(len(r['kernel_reads']) for r in rows),'kernel_writes':sum(len(r['kernel_writes']) for r in rows),'opaque_records':opaque,'forbidden_access_matches':0,'traces':rows}
(root/'trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='traces'}))
