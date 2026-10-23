from collections import Counter
from pathlib import Path
import hashlib,json,re
from logical import logical
root=Path('../sealed-metadata-native-acceptance-v2');out=Path(__file__).parent
runs=json.load(open(root/'sealed-metadata/runs.json'));images=json.load(open(root/'sealed-metadata/images.json'))
sizes={r['path']:len(bytes.fromhex(r['before_hex'])) for r in images};rows=[];opaque=[]
for run in runs:
 if not run['trace']:continue
 trace=Path(run['trace']);raw=trace.read_text();args=run['arguments'];marker=args.index('-e');cmd=args[marker+2:]
 api='entry-006' in cmd[0];source=cmd[3] if api else cmd[2];size=sizes[source]
 env=run['fault_environment'];mode=cmd[2] if api else 'tool';fault=env.get('AESIR_METADATA_FAULT') or env.get('AESIR_SEAL_FAULT_MODE')
 original=Counter();sealed=Counter();openfds={};generation={};phases={};extent={};seals=set();creates=closes=opens=originalcloses=0;reads=[];writes=[]
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl'):
  assert token not in raw,(trace,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),trace
 for pid,line in logical(raw):
  if line.startswith('???(') or '<unfinished ...>' in line:
   opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return/effect inferred'));continue
  m=re.search(r'openat\(.*?"'+re.escape(source)+r'".*?\)\s*= (\d+)<',line)
  if m:
   fd=m[1];key=(pid,fd);original[key]+=1;openfds[key]='original';opens+=1
   if mode not in ('truncate','mutate','replace') and not env.get('AESIR_SAFETENSORS_MUTATION_PATH'):
    assert 'O_RDONLY' in line and 'O_RDWR' not in line and 'O_WRONLY' not in line,(trace,line)
  if ('diagnostic-label-without-a-file' in line or 'label' in line and 'κ' in line) and 'openat(' in line:raise AssertionError((trace,'label reopened',line))
  m=re.search(r'memfd_create\("aesir-source-copy".*?\)\s*= (\d+)<',line)
  if m:
   key=(pid,m[1]);generation[key]=generation.get(key,0)+1;sealed[key]+=1;openfds[key]='sealed';creates+=1;seals.discard(key)
  m=re.search(r'fcntl\((\d+)</memfd:aesir-source-copy>\(deleted\), F_ADD_SEALS, .*\)\s*= 0',line)
  if m:seals.add((pid,m[1]))
  m=re.search(r'statx\((\d+)</memfd:aesir-source-copy>\(deleted\).*stx_size=(\d+)',line)
  if m:extent[(pid,m[1])]=int(m[2])
  assert not ('mmap(' in line and ('memfd:aesir-source-copy' in line or source in line)),(trace,'no source mapping',line)
  m=re.search(r'(pread64|pwrite64)\((\d+)<([^>]+)>.*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line)
  if m:
   call,fd,label,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n));key=(pid,fd)
   if label==source or label==source+' (deleted)' or 'memfd:aesir-source-copy' in label:
    issealed='memfd:' in label
    row=dict(pid=pid,fd=fd,sealed=issealed,offset=offset,requested=want,returned=n)
    (reads if call=='pread64' else writes).append(row)
    if call=='pread64' and issealed:
     groupkey=(*key,generation[key]);groups=phases.setdefault(groupkey,[])
     if offset==0:groups.append(dict(covered=0,calls=0,complete=False,eof=False,metadata=size==0 or len(groups)>=2))
     assert groups,(trace,line)
     g=groups[-1];assert offset==g['covered'],(trace,'positional continuity',line,g)
     assert 0<want<=(8192 if g['metadata'] else 4096),(trace,line,g)
     assert offset<=size and want<=size+(1 if g['metadata'] else 0)-offset,(trace,line,size,g)
     if g['metadata']:
      assert key in seals and extent.get(key)==size,(trace,'actual seals/extent before metadata',line)
      assert not any(v=='original' for v in openfds.values()),(trace,'original closed before parsing',line,openfds)
      assert size==0 or all(x['complete'] for x in groups[:2]),(trace,'two actual full hashes before metadata',groups)
     if n>0:g['covered']+=n
     g['calls']+=1;g['complete']=g['covered']==size
     if n==0:g['eof']=True
     assert n<=want,(trace,'kernel result count',line)
    else:
     assert 0<want<=4096 and offset>=0 and offset+want<=size,(trace,line)
  m=re.search(r'close\((\d+)<([^>]+)>.*?\)\s*= 0',line)
  if m:
   fd,label=m.groups();key=(pid,fd)
   if 'memfd:aesir-source-copy' in label:sealed[key]-=1;closes+=1
   elif label==source or label==source+' (deleted)':original[key]-=1;originalcloses+=1
   openfds.pop(key,None)
 assert not +original and not -original,(trace,'original fd balance',original)
 assert not +sealed and not -sealed,(trace,'sealed fd balance',sealed)
 for groups in phases.values():
  for g in groups:
   if g['metadata']:
    assert g['calls']<=size+1,(trace,'progress bound',g)
    if run['returncode']==0:assert g['complete'] and g['eof'],(trace,'exact bytes plus EOF',g)
 if run['returncode']==0 and mode not in ('closed_fd','large_fd'):
  assert phases and any(len(gs)>=3 for gs in phases.values()),(trace,'hash/read phases',phases)
 rows.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),source=source,size=size,mode=mode,fault=fault,returncode=run['returncode'],original_opens=opens,original_closes=originalcloses,sealed_creates=creates,sealed_closes=closes,positional_reads=len(reads),positional_writes=len(writes),full_hash_phases=sum(g['complete'] and not g['metadata'] for gs in phases.values() for g in gs[:2]),partial_hash_phases=sum(not g['complete'] and not g['metadata'] for gs in phases.values() for g in gs[:2]),metadata_phases=sum(g['metadata'] for gs in phases.values() for g in gs),metadata_eof_phases=sum(g['metadata'] and g['eof'] for gs in phases.values() for g in gs),phase_details=[dict(pid=k[0],fd=k[1],generation=k[2],phases=v) for k,v in phases.items()]))
assert len(rows)==len(list((root/'sealed-metadata').glob('*.strace')))
newpaths={Path(r['trace']).resolve() for r in rows};old=[];oldopaque=[]
for trace in sorted(root.rglob('*.strace')):
 if trace.resolve() in newpaths:continue
 raw=trace.read_text()
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert token not in raw,(trace,token)
 calls=logical(raw)
 for pid,line in calls:
  if line.startswith('???(') or '<unfinished ...>' in line:oldopaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no effect inferred'))
 old.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),logical_records=len(calls)))
result=dict(traces=len(rows),totals={k:sum(r[k] for r in rows) for k in ('original_opens','original_closes','sealed_creates','sealed_closes','positional_reads','positional_writes','full_hash_phases','partial_hash_phases','metadata_phases','metadata_eof_phases')},opaque_records=opaque,rows=rows)
(out/'sealed-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n')
(out/'legacy-trace-audit.json').write_text(json.dumps(dict(traces=len(old),logical_records=sum(r['logical_records'] for r in old),opaque_records=oldopaque,rows=old),indent=2)+'\n')
print(json.dumps(dict(new_traces=len(rows),totals=result['totals'],opaque_records=opaque,legacy_traces=len(old),legacy_opaque=oldopaque),indent=2))
