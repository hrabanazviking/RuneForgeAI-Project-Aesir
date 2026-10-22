from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path('../sealed-copy-native-acceptance/sealed');runs=json.load(open(root/'runs.json'));manifest=json.load(open(root/'trace-manifest.json'));ids=json.load(open(root/'fixtures.json'))
def logical(text):
 pending={};result=[]
 for line in text.splitlines():
  match=re.match(r'^(\d+)\s+(.*)$',line);assert match,line
  pid,body=match.groups()
  if '<unfinished ...>' in body:
   assert pid not in pending,line;pending[pid]=body.split('<unfinished ...>',1)[0];continue
  resumed=re.match(r'<\.\.\. (\w+|\?\?\?) resumed>(.*)',body)
  if resumed:
   prefix=pending.pop(pid);assert prefix.startswith(resumed[1]+'('),(line,prefix);body=prefix+resumed[2]
  result.append((pid,body))
 assert not pending,pending
 return result
rows=[]
for item in manifest:
 trace=Path(item['trace']);r=runs[item['run_index']];text=trace.read_text();source=r['source'];opened=[];closed=[];created=[];released=[];reads=[];writes=[];seals=[];map_refusals=0
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert token not in text,(trace,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',text),(trace,'actual fatal signal delivery')
 for pid,line in logical(text):
  match=re.search(r'memfd_create\("aesir-source-copy", MFD_CLOEXEC\|MFD_ALLOW_SEALING\s*\)\s*= (\d+)<(/memfd:[^>]+)>',line)
  if match:created.append((pid,match[1],match[2]))
  match=re.search(r'close\((\d+)<(/memfd:[^>]+)>(?:\(deleted\))?\s*\)\s*= 0',line)
  if match:released.append((pid,match[1],match[2]))
  if 'mmap(' in line and '/memfd:' in line:
   assert 'PROT_READ|PROT_WRITE' in line and 'MAP_SHARED' in line and '= -1 EPERM' in line,line;map_refusals+=1
  if source and source in line:
   match=re.search(r'openat\(.*?"'+re.escape(source)+r'".*?\)\s*= (\d+)<',line)
   if match:
    if 'O_RDWR' in line or 'O_WRONLY' in line:assert r['mutation'],line
    else:assert 'O_RDONLY' in line,line
    opened.append((pid,match[1],source))
   match=re.search(r'close\((\d+)<'+re.escape(source)+r'>\s*\)\s*= 0',line)
   if match:closed.append((pid,match[1],source))
   if 'pwrite64(' in line:
    assert r['mutation'],line
    match=re.search(r', 1, (\d+)\s*\)\s*= 1',line);assert match,line
    assert int(match[1])==max(0,ids[source]['bytes']-1),line
   if 'mmap(' in line:raise AssertionError(('new copy path must not map source',line))
  if 'pread64(' in line and ((source and source in line) or '/memfd:' in line):
   match=re.search(r'pread64\((\d+)<([^>]+)>(?:\(deleted\))?, .*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line);assert match,line
   fd,path,want,offset,n=match.groups();want,offset,n=map(int,(want,offset,n));assert 0<want<=4096 and 0<n<=want,line
   size=ids[source]['bytes'];assert offset>=0 and want<=size-offset,(line,size)
   reads.append({'pid':pid,'fd':int(fd),'target':'source' if path==source else 'sealed','offset':offset,'requested':want,'returned':n})
  if 'pwrite64(' in line and '/memfd:' in line:
   match=re.search(r'pwrite64\((\d+)<[^>]+>(?:\(deleted\))?, .*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line);assert match,line
   fd,want,offset,n=map(int,match.groups());assert 0<want<=4096 and offset>=0,line
   if n<0:assert '= -1 EPERM' in line and r['arguments'][-1]=='protect',line
   else:assert n<=want and want<=ids[source]['bytes']-offset,line
   writes.append({'pid':pid,'fd':fd,'offset':offset,'requested':want,'returned':n})
  if 'fcntl(' in line and '/memfd:' in line and 'F_ADD_SEALS' in line:seals.append(line)
 assert Counter(opened)==Counter(closed),(trace,opened,closed)
 assert Counter(created)==Counter(released),(trace,created,released)
 if source:assert opened,trace
 if r['returncode']==0 and source:
  assert len(created)==1,(trace,created)
  assert len(seals)==1 and '= 0' in seals[0],(trace,seals)
  for bit in ('F_SEAL_SEAL','F_SEAL_SHRINK','F_SEAL_GROW','F_SEAL_WRITE'):assert bit in seals[0],seals
  # Actual successful source/copy byte coverage, independent of native counters.
  for effect in ([x for x in reads if x['target']=='source'],[x for x in writes if x['returned']>0]):
   done=0
   for x in effect:assert x['offset']==done,(trace,x,done);done+=x['returned']
   assert done==ids[source]['bytes'],(trace,done)
 rows.append({'trace':str(trace),'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'source_opens':len(opened),'source_closes':len(closed),'memfd_creates':len(created),'memfd_closes':len(released),'writable_shared_map_refusals':map_refusals,'kernel_reads':reads,'kernel_writes':writes,'seal_operations':seals,'fault':r['fault'],'returncode':r['returncode']})
assert len(rows)==len(list(root.glob('trace-*.strace')))==sum(Path(r['arguments'][0]).name=='strace' for r in runs)
mutations=[]
for r in runs:
 if r['mutation']:
  p=Path(r['source']);raw=bytes.fromhex(ids[str(p)]['hex']);assert p.read_bytes()==(raw[:-1]+b'\xad' if raw else b'\xad')
  mutations.append({'source':str(p),'complete_final_bytes_equal':True,'sealed_original_digest':hashlib.sha256(raw).hexdigest()})
for p,ident in ids.items():
 if not any(r['source']==p and r['mutation'] for r in runs):assert Path(p).read_bytes()==bytes.fromhex(ident['hex']),p
for r in runs:
 if not r['fault']:continue
 events=r['fault_events'];args=r['arguments'];j=next(i for i,v in enumerate(args) if Path(v).name=='sealed-source-api');args=args[j:]
 if args[1]=='copy':
  read_bound,write_bound,digest_bound=map(int,args[5:8]);counts=Counter(e['op'] for e in events)
  assert counts['source_read']<=read_bound and counts['copy_write']<=write_bound,(r,counts)
  if r['returncode']!=0:assert counts['digest_read']<=digest_bound,(r,counts)
  for kind in ('source_read','copy_write','digest_read'):
   seq=[e['attempt'] for e in events if e['op']==kind];assert seq==list(range(1,len(seq)+1)),(kind,seq)
result={'trace_count':len(rows),'totals':{k:sum(r[k] for r in rows) for k in ('source_opens','source_closes','memfd_creates','memfd_closes','writable_shared_map_refusals')},'kernel_read_count':sum(len(r['kernel_reads']) for r in rows),'kernel_write_count':sum(len(r['kernel_writes']) for r in rows),'independent_mutation_cases':len(mutations),'forbidden_access_matches':0,'all_fixture_bytes_checked':True,'trace_fault_injections_have_independent_attempt_logs':True,'traces':rows,'mutations':mutations}
(root/'trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ('traces','mutations')}))
