from pathlib import Path
from collections import Counter
import hashlib,json,re
from logical import logical
root=Path('../sealed-collection-native-acceptance-v3');out=Path('../sealed-collection-native-recording')
runs=json.load(open(root/'sealed-collection/runs.json'));rows=[];opaque=[]
for r in runs:
 if not r['trace']:continue
 trace=Path(r['trace']);raw=trace.read_text();directory=r['root'];generations={};active={};extents={};sealed_extents={};seals=set();phases={};maps={};allmaps=[];unmaps=[];sourceopens=rootopens=sourcecloses=rootcloses=creates=sealedcloses=0
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl'):assert token not in raw,(trace,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),trace
 for pid,line in logical(raw):
  if line.startswith('???(') or '<unfinished ...>' in line:
   opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return/effect inferred'));continue
  m=re.search(r'(openat2?|memfd_create)\(.*\)\s*= (\d+)<([^>]+)>',line)
  if m:
   op,fd,label=m.groups();key=(pid,fd)
   if 'memfd:aesir-source-copy' in label:
    generations[key]=generations.get(key,0)+1;active[key]=dict(kind='sealed',label=label,generation=generations[key]);creates+=1;seals.discard(key)
   elif label==directory:
    active[key]=dict(kind='root',label=label);rootopens+=1
   elif label.startswith(directory+'/'):
    active[key]=dict(kind='source',label=label);sourceopens+=1
    if op=='openat2':assert 'O_RDONLY' in line and 'O_NONBLOCK' in line and 'RESOLVE_BENEATH' in line and 'RESOLVE_NO_MAGICLINKS' in line,(trace,line)
  m=re.search(r'statx\((\d+)<([^>]+)>.*stx_size=(\d+)',line)
  if m:
   fd,label,size=m.groups();key=(pid,fd)
   if key in active:
    if active[key]['kind']=='sealed':sealed_extents[(*key,active[key]['generation'])]=int(size)
    elif active[key]['kind']=='source':extents[key]=int(size)
  m=re.search(r'fcntl\((\d+)</memfd:aesir-source-copy>\(deleted\), F_ADD_SEALS, .*\)\s*= 0',line)
  if m:seals.add((pid,m[1]))
  m=re.search(r'(pread64|pwrite64)\((\d+)<([^>]+)>.*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line)
  if m:
   call,fd,label,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n));key=(pid,fd)
   if 'memfd:aesir-source-copy' in label:
    assert key in active and active[key]['kind']=='sealed',(trace,'live actual sealed fd',line)
    gkey=(*key,active[key]['generation']);size=sealed_extents.get(gkey)
    if call=='pwrite64':
     # Copy writes precede the first actual stat of the new memfd. Exact source
     # size is independently checked again once copy finishes.
     assert 0<want<=4096 and offset>=0 and n<=want,(trace,line);continue
    assert size is not None,(trace,'actual sealed extent before read',line)
    groups=phases.setdefault(gkey,[])
    if offset==0:
     ismetadata=size==0 or len(groups)>=2
     groups.append(dict(metadata=ismetadata,covered=0,calls=0,complete=False,eof=False))
     if len(groups)==2 and not ismetadata:
      assert not any(v['kind']=='source' for v in active.values()),(trace,'original close before parser hash',line,active)
    assert groups,(trace,line);g=groups[-1]
    assert offset==g['covered'] and 0<want<=(8192 if g['metadata'] else 4096),(trace,line,g)
    assert offset<=size and want<=size+(1 if g['metadata'] else 0)-offset and n<=want,(trace,line,size,g)
    if g['metadata']:
     assert key in seals and not any(v['kind']=='source' for v in active.values()),(trace,line)
     assert size==0 or all(x['complete'] for x in groups[:2]),(trace,'two full sealed hashes',groups)
    if n>0:g['covered']+=n
    g['calls']+=1;g['complete']=g['covered']==size;g['eof']|=n==0
   elif label.startswith(directory+'/'):
    assert key in active and active[key]['kind']=='source',(trace,'live original',line)
    assert 0<want<=4096 and offset>=0 and n<=want,(trace,line)
    # The mutation seam explicitly performs a one-byte final write/read; its
    # original stat is replaced by its observed lseek and retained fixture images.
    if key in extents:assert offset+want<=extents[key],(trace,line,extents[key])
  m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)</memfd:aesir-source-copy>\(deleted\), 0\s*\)\s*= (0x[0-9a-f]+)',line)
  if m:
   size,fd,address=m.groups();size=int(size);key=(pid,fd);gkey=(*key,active[key]['generation'])
   assert size==sealed_extents[gkey] and key in seals,(trace,line)
   groups=phases[gkey];assert len(groups)==2 and all(g['complete'] and not g['metadata'] for g in groups),(trace,'two full hashes before mapping',groups)
   assert not any(v['kind']=='source' for v in active.values()),(trace,line)
   entry=(pid,address,size);maps[key]=entry;allmaps.append(entry)
  elif 'mmap(' in line and (directory+'/' in line or 'memfd:aesir-source-copy' in line):assert '= -1' in line,(trace,'unexpected source mapping',line)
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if m:
   entry=(pid,m[1],int(m[2]));unmaps.append(entry)
   for key in list(maps):
    if maps[key]==entry:del maps[key]
  m=re.search(r'close\((\d+)<([^>]+)>.*?\)\s*= 0',line)
  if m:
   fd,label=m.groups();key=(pid,fd)
   if key in active:
    item=active.pop(key)
    if item['kind']=='source':sourcecloses+=1
    elif item['kind']=='root':rootcloses+=1
    else:assert key not in maps,(trace,'exact unmap before close',line);sealedcloses+=1
 assert sourceopens==sourcecloses and rootopens==rootcloses and creates==sealedcloses and not active and not maps,(trace,sourceopens,sourcecloses,rootopens,rootcloses,creates,sealedcloses,active,maps)
 assert not Counter(allmaps)-Counter(unmaps),(trace,allmaps,unmaps)
 for groups in phases.values():
  for g in groups:
   if g['metadata']:assert g['calls']<=max(1,g['covered']+1),(trace,'bounded progress',g)
 rows.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),root_opens=rootopens,root_closes=rootcloses,source_opens=sourceopens,source_closes=sourcecloses,sealed_creates=creates,sealed_closes=sealedcloses,sealed_maps=len(allmaps),exact_unmaps=len(allmaps),complete_hashes=sum(g['complete'] and not g['metadata'] for gs in phases.values() for g in gs),partial_hashes=sum(not g['complete'] and not g['metadata'] for gs in phases.values() for g in gs),metadata_phases=sum(g['metadata'] for gs in phases.values() for g in gs),observed_eof_phases=sum(g['metadata'] and g['eof'] for gs in phases.values() for g in gs),returncode=r['returncode'],phase_details=[dict(pid=k[0],fd=k[1],generation=k[2],phases=v) for k,v in phases.items()]))
assert len(rows)==len(list((root/'sealed-collection').glob('*.strace')))
newpaths={Path(r['trace']).resolve() for r in rows};others=[];oldopaque=[]
for trace in root.rglob('*.strace'):
 if trace.resolve() in newpaths:continue
 raw=trace.read_text()
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert token not in raw,(trace,token)
 calls=logical(raw)
 for pid,line in calls:
  if line.startswith('???(') or '<unfinished ...>' in line:oldopaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no effect inferred'))
 others.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),logical_records=len(calls)))
keys=('root_opens','root_closes','source_opens','source_closes','sealed_creates','sealed_closes','sealed_maps','exact_unmaps','complete_hashes','partial_hashes','metadata_phases','observed_eof_phases')
result=dict(traces=len(rows),totals={k:sum(r[k] for r in rows) for k in keys},opaque_records=opaque,rows=rows)
(out/'collection-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');(out/'other-trace-audit.json').write_text(json.dumps(dict(traces=len(others),logical_records=sum(r['logical_records'] for r in others),opaque_records=oldopaque,rows=others),indent=2)+'\n')
print(json.dumps(dict(new_traces=len(rows),totals=result['totals'],new_opaque=opaque,other_traces=len(others),other_opaque=oldopaque),indent=2))
