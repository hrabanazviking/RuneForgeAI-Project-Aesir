from collections import Counter
from pathlib import Path
import ast,hashlib,json,re,subprocess
root=Path('../sealed-safetensors-native-acceptance-v2');out=Path('../sealed-safetensors-native-recording')
s=Path('../sealed-gguf-native-recording/audit-old-digest-reviewed2.py').read_text();node=next(n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef) and n.name=='logical');exec(ast.get_source_segment(s,node))
new=root/'sealed-safetensors';manifest=json.load(open(new/'trace-manifest.json'));runs=json.load(open(new/'runs.json'));fixtures=json.load(open(new/'fixtures.json'));rows=[];opaque=[]
for record in manifest:
 trace=Path(record['trace']);raw=trace.read_text();run=runs[record['run_index']];source=run['path'];size=fixtures[source]['bytes'];mutation=run['mutation']
 opens=[];closes=[];memfds=[];memcloses=[];maps=[];unmaps=[];readonly_old=[];active={};extent={};seals=set();reads=[];writes=[];mapfds={};fdpaths={};generations={};phases={}
 for forbidden in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl'):
  assert forbidden not in raw,(trace,forbidden)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),trace
 for pid,line in logical(raw):
  if line.startswith('???(') or '<unfinished ...>' in line:opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return/effect inferred'));continue
  m=re.search(r'openat\(.*?"'+re.escape(source)+r'".*?\)\s*= (\d+)<',line)
  if m:
   fd=m[1];opens.append((pid,fd));fdpaths[(pid,fd)]=source
   if not mutation:assert 'O_RDONLY' in line and 'O_RDWR' not in line and 'O_WRONLY' not in line,(trace,line)
  if '"/aesir-provenance-only-must-not-open"' in line and ('open(' in line or 'openat(' in line):raise AssertionError((trace,'provenance label reopened',line))
  m=re.search(r'memfd_create\("aesir-source-copy".*?\)\s*= (\d+)<',line)
  if m:fd=m[1];memfds.append((pid,fd));seals.discard((pid,fd));fdpaths[(pid,fd)]='sealed';generations[(pid,fd)]=generations.get((pid,fd),0)+1
  m=re.search(r'fcntl\((\d+)</memfd:aesir-source-copy>\(deleted\), F_ADD_SEALS, .*\)\s*= 0',line)
  if m:seals.add((pid,m[1]))
  m=re.search(r'statx\((\d+)</memfd:aesir-source-copy>\(deleted\).*stx_size=(\d+)',line)
  if m:extent[(pid,m[1])]=int(m[2])
  m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)</memfd:aesir-source-copy>\(deleted\), 0\s*\)\s*= (0x[0-9a-f]+)',line)
  if m:
   n,fd,address=m.groups();assert int(n)==size==extent[(pid,fd)] and (pid,fd) in seals,(trace,line)
   assert source not in fdpaths.values(),(trace,'original still open at sealed map',fdpaths)
   groups=phases[(pid,fd,generations[(pid,fd)])];assert len(groups)==2 and all(g['covered']==size and g['complete'] for g in groups),(trace,'two complete actual sealed hashes required before admission',groups)
   entry=(pid,address,int(n));maps.append(entry);active[(pid,fd)]=entry;mapfds[(pid,address)]=fd
  elif 'mmap(' in line and 'memfd:aesir-source-copy' in line:assert '= -1' in line,(trace,line)
  m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)<'+re.escape(source)+r'>, 0\s*\)\s*= (0x[0-9a-f]+)',line)
  if m:assert int(m[1])==size;(readonly_old.append((pid,m[3],int(m[1]))))
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if m:
   entry=(pid,m[1],int(m[2]));unmaps.append(entry)
   for key in list(active):
    if active[key]==entry:del active[key]
  m=re.search(r'(pread64|pwrite64)\((\d+)<([^>]+)>.*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line)
  if m:
   call,fd,label,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n))
   if label==source or 'memfd:aesir-source-copy' in label:
    assert 0<want<=4096 and offset>=0 and n<=want,(trace,line)
    # The only intentional original payload read/write outside the copy/hash
    # stream is the one-byte same-extent test shim, still inside this fixture.
    assert offset<=size and want<=size-offset,(trace,line,size)
    row=dict(pid=pid,fd=fd,sealed='memfd:' in label,offset=offset,requested=want,returned=n)
    (reads if call=='pread64' else writes).append(row)
    if call=='pread64' and row['sealed']:
     key=(pid,fd,generations[(pid,fd)]);groups=phases.setdefault(key,[])
     if not groups or offset==0:groups.append(dict(covered=0,complete=False,calls=0))
     g=groups[-1];assert offset==g['covered'] and 0<n<=want,(trace,'sealed hash continuity',line,g)
     g['covered']+=n;g['calls']+=1;g['complete']=g['covered']==size
  m=re.search(r'close\((\d+)<([^>]+)>.*?\)\s*= 0',line)
  if m:
   fd,label=m.groups()
   if 'memfd:aesir-source-copy' in label:
    assert (pid,fd) not in active,(trace,'close before exact unmap',line);memcloses.append((pid,fd))
   elif label==source:closes.append((pid,fd))
   fdpaths.pop((pid,fd),None)
 assert Counter(opens)==Counter(closes),(trace,opens,closes)
 assert Counter(memfds)==Counter(memcloses),(trace,memfds,memcloses)
 assert not Counter(maps+readonly_old)-Counter(unmaps),(trace,maps+readonly_old,unmaps)
 rows.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),source_opens=len(opens),source_closes=len(closes),sealed_creates=len(memfds),sealed_closes=len(memcloses),sealed_readonly_maps=len(maps),ordinary_readonly_maps=len(readonly_old),exact_unmaps=len(maps)+len(readonly_old),positional_reads=len(reads),positional_writes=len(writes),complete_sealed_hash_phases=sum(g['complete'] for groups in phases.values() for g in groups),partial_sealed_hash_phases=sum(not g['complete'] for groups in phases.values() for g in groups),mutation=mutation,fault=run['fault']))
assert len(rows)==len(list(new.glob('*.strace')))
result=dict(trace_count=len(rows),totals={k:sum(r[k] for r in rows) for k in rows[0] if isinstance(rows[0][k],int) and not isinstance(rows[0][k],bool)},opaque_records=opaque,traces=rows)
(out/'sealed-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n')
# All other actual traces, including directory consumers, receive the complete
# PID/name join and forbidden-effect/signal audit; keep opaque records literally.
legacy=[];all_opaque=[]
for trace in sorted(root.rglob('*.strace')):
 if trace.resolve() in {Path(m['trace']).resolve() for m in manifest}:continue
 raw=trace.read_text()
 for forbidden in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert forbidden not in raw,(trace,forbidden)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),(trace,'fatal signal')
 calls=logical(raw)
 for pid,line in calls:
  if line.startswith('???(') or '<unfinished ...>' in line:all_opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return/effect inferred'))
 legacy.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),decoded_records=len(calls)))
assert len(rows)+len(legacy)==len(list(root.rglob('*.strace'))),(len(rows),len(legacy))
assert not {Path(r['trace']).resolve() for r in rows}&{Path(r['trace']).resolve() for r in legacy}
(out/'all-legacy-trace-audit.json').write_text(json.dumps(dict(trace_count=len(legacy),decoded_records=sum(r['decoded_records'] for r in legacy),opaque_records=all_opaque,forbidden_effect_matches=0,traces=legacy),indent=2)+'\n')
print(json.dumps(dict(new_traces=len(rows),new_totals=result['totals'],new_opaque=opaque,legacy_traces=len(legacy),legacy_opaque=all_opaque),indent=2))
