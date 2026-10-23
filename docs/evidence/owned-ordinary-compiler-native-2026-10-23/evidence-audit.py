from pathlib import Path
from collections import Counter
import hashlib,json,re
from logical import logical
root=Path('../owned-ordinary-compiler-native-acceptance');out=Path('../owned-ordinary-compiler-native-recording');out.mkdir(exist_ok=True)
runs=json.load(open(root/'owned-ordinary-compiler/runs.json'));rows=[];opaque=[]
for r in runs:
 if not r['trace']:continue
 trace=Path(r['trace']);raw=trace.read_text();directory=r['root'];active={};gens={};extents={};phases={};maps={};mapped=set();allmaps=[];unmaps=[];seals=set();counts=Counter();root_closed=False
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl'):assert token not in raw,(trace,token)
 assert not re.search(r'--- SIG(?:BUS|SEGV|ABRT)\b|\+\+\+ killed by SIG(?:BUS|SEGV|ABRT)\b',raw),trace
 for pid,line in logical(raw):
  if line.startswith('???(') or '<unfinished ...>' in line:opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return/effect inferred'));continue
  if re.search(r'\bdup[23]?\([^\n]*memfd:aesir-source-copy',line):raise AssertionError((trace,'duplicated sealed owner',line))
  m=re.search(r'(openat2?|memfd_create)\(.*\)\s*= (\d+)<([^>]+)>',line)
  if m:
   op,fd,label=m.groups();key=(pid,fd)
   if 'memfd:aesir-source-copy' in label:
    gens[key]=gens.get(key,0)+1;g=(*key,gens[key]);active[key]=dict(kind='sealed',label=label,g=g);counts['sealed_creates']+=1
   elif label==directory:
    assert not root_closed,(trace,'root reopen',line);active[key]=dict(kind='root',label=label);counts['root_opens']+=1
   elif label.startswith(directory+'/'):
    if op=='openat2':
     assert not root_closed and 'O_RDONLY' in line and 'O_NONBLOCK' in line and 'RESOLVE_BENEATH' in line and 'RESOLVE_NO_MAGICLINKS' in line,(trace,'beneath read-only once before binding',line)
    elif root_closed:assert 'O_RDWR' in line,(trace,'unexpected path reopen after binding',line)
    active[key]=dict(kind='original',label=label);counts['original_opens']+=1
  m=re.search(r'statx\((\d+)<([^>]+)>.*stx_size=(\d+)',line)
  if m:
   fd,label,size=m.groups();key=(pid,fd)
   if key in active and active[key]['kind']=='sealed':extents[active[key]['g']]=int(size)
  m=re.search(r'fcntl\((\d+)</memfd:aesir-source-copy>\(deleted\), F_ADD_SEALS, .*\)\s*= 0',line)
  if m:seals.add(active[(pid,m[1])]['g'])
  m=re.search(r'(pread64|pwrite64)\((\d+)<([^>]+)>.*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line)
  if m:
   op,fd,label,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n));key=(pid,fd)
   if 'memfd:aesir-source-copy' in label:
    assert key in active and active[key]['kind']=='sealed',(trace,line)
    g=active[key]['g']
    if op=='pwrite64':assert 0<want<=4096 and n<=want and g not in seals,(trace,line);continue
    assert g in extents and g in seals,(trace,'actual extent and all seals before retained read',line)
    groups=phases.setdefault(g,[])
    if offset==0:groups.append(dict(reads=[],covered=0))
    assert groups and offset==groups[-1]['covered'] and 0<want<=8192 and n<=want,(trace,line,groups)
    phase=groups[-1];phase['reads'].append(dict(want=want,offset=offset,returned=n));phase['covered']+=max(0,n)
    if len(groups)>=2:assert not any(v['kind']=='original' for v in active.values()),(trace,'original still live during parser/compiler hash or metadata read',line)
  m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)</memfd:aesir-source-copy>\(deleted\), 0\s*\)\s*= (0x[0-9a-f]+)',line)
  if m:
   size,fd,address=m.groups();key=(pid,fd);g=active[key]['g'];size=int(size)
   assert size==extents[g] and g in seals and len(phases[g])==2 and all(p['covered']==size for p in phases[g]),(trace,'two full hashes before one retained mapping',line)
   assert g not in mapped,(trace,'remapped retained owner',line);mapped.add(g);entry=(pid,address,size);maps[key]=entry;allmaps.append(entry)
  elif 'mmap(' in line and (directory+'/' in line or 'memfd:aesir-source-copy' in line):assert '= -1' in line,(trace,'unexpected map',line)
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if m:
   entry=(pid,m[1],int(m[2]));unmaps.append(entry)
   for key in list(maps):
    if maps[key]==entry:del maps[key]
  m=re.search(r'close\((\d+)<([^>]+)>.*?\)\s*= 0',line)
  if m:
   key=(pid,m[1])
   if key in active:
    item=active.pop(key)
    if item['kind']=='sealed':assert key not in maps,(trace,'unmap before descriptor close',line)
    if item['kind']=='root':root_closed=True
    counts[item['kind']+'_closes']+=1
 assert counts['root_opens']==counts['root_closes'] and counts['original_opens']==counts['original_closes'] and counts['sealed_creates']==counts['sealed_closes'] and not active and not maps,(trace,counts,active,maps)
 assert not Counter(allmaps)-Counter(unmaps),(trace,allmaps,unmaps)
 for g,groups in phases.items():
  size=extents[g]
  for i,p in enumerate(groups):
   metadata=g not in mapped and i>=2 and i%2==0
   p.update(metadata=metadata,complete=p['covered']==size,eof=any(x['returned']==0 for x in p['reads']))
   for read in p['reads']:
    assert read['want']<=(8192 if metadata else 4096) and read['offset']<=size and read['want']<=size+(1 if metadata else 0)-read['offset'],(trace,g,i,read,size)
   counts['metadata_phases' if metadata else 'hash_phases']+=1
   counts['complete_metadata' if metadata else 'complete_hashes']+=p['complete']
   counts['metadata_eof']+=metadata and p['eof']
 rows.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),returncode=r['returncode'],totals=dict(counts),exact_maps=len(allmaps),exact_unmaps=len(allmaps),phases=[dict(pid=g[0],fd=g[1],generation=g[2],mapped=g in mapped,extent=extents[g],phases=v) for g,v in phases.items()]))
assert len(rows)==len(list((root/'owned-ordinary-compiler').glob('*.strace')))
newpaths={Path(r['trace']).resolve() for r in rows};others=[];oldopaque=[]
for trace in root.rglob('*.strace'):
 if trace.resolve() in newpaths:continue
 raw=trace.read_text()
 for token in ('/dev/h1x-','/dev/hailo','connect(','socket(','ioctl(','libhailort','libcuda','libtorch','libonnxruntime','libcrypto','libssl'):assert token not in raw,(trace,token)
 calls=logical(raw)
 for pid,line in calls:
  if line.startswith('???(') or '<unfinished ...>' in line:oldopaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no effect inferred'))
 others.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),logical_records=len(calls)))
keys=set().union(*(r['totals'] for r in rows));result=dict(traces=len(rows),totals={k:sum(r['totals'].get(k,0) for r in rows) for k in sorted(keys)},exact_maps=sum(r['exact_maps'] for r in rows),exact_unmaps=sum(r['exact_unmaps'] for r in rows),opaque_records=opaque,rows=rows)
(out/'compiler-trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');(out/'other-trace-audit.json').write_text(json.dumps(dict(traces=len(others),logical_records=sum(r['logical_records'] for r in others),opaque_records=oldopaque,rows=others),indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2))
