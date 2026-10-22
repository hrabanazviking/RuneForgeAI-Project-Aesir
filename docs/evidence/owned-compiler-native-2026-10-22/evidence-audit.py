from collections import Counter
from pathlib import Path
import ast,hashlib,json,re,subprocess
root=Path('../owned-compiler-native-acceptance-v2');out=Path('../owned-compiler-native-recording')
# Reuse the reviewed PID/name join, including opaque unreturned syscall tails.
s=Path('../sealed-gguf-native-recording/audit-old-digest-reviewed2.py').read_text();node=next(n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef) and n.name=='logical');exec(ast.get_source_segment(s,node))
rows=[];opaque=[]
for trace in sorted(root.rglob('*.strace')):
 text=trace.read_text()
 for token in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl','connect(','socket(','ioctl('):assert token not in text,(trace,token)
 opens=[];closes=[];memfds=[];memcloses=[];maps=[];unmaps=[];reads=[];writes=[];seals=[];live={};capacities={};sealed=set();firstmap={};aftermap=[];phases={};completed=[];active_maps={}
 for order,(pid,line) in enumerate(logical(text)):
  if line.startswith('???(') or '<unfinished ...>' in line:
   opaque.append(dict(trace=str(trace),pid=pid,record=line,classification='opaque; no return or effect inferred'));continue
  m=re.search(r'openat\(.*?"([^"]+\.gguf)".*?\)\s*= (\d+)<',line)
  if m:
   path,fd=m.groups();opens.append((pid,fd,path));live[(pid,fd)]=path
  m=re.search(r'memfd_create\("aesir-source-copy".*?\)\s*= (\d+)<',line)
  if m:fd=m[1];memfds.append((pid,fd));live[(pid,fd)]='sealed';sealed.discard((pid,fd));firstmap.pop((pid,fd),None)
  m=re.search(r'fcntl\((\d+)</memfd:aesir-source-copy>\(deleted\), F_ADD_SEALS, .*\)\s*= 0',line)
  if m:sealed.add((pid,m[1]));seals.append((pid,m[1]))
  m=re.search(r'statx\((\d+)</memfd:aesir-source-copy>\(deleted\).*stx_size=(\d+)',line)
  if m:capacities[(pid,m[1])]=int(m[2])
  m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)</memfd:aesir-source-copy>\(deleted\), 0\)\s*= (0x[0-9a-f]+)',line)
  if m:
   size,fd,address=m.groups();assert (pid,fd) in sealed and capacities[(pid,fd)]==int(size),(trace,line)
   assert not any(v.endswith('.gguf') for v in live.values()),(trace,'source still open during sealed mapping',live)
   maps.append((pid,address,int(size)));firstmap[(pid,fd)]=order
   phases[(pid,fd)]=dict(size=int(size),done=0,reads=0);active_maps[(pid,fd)]=(pid,address,int(size))
  elif 'mmap(' in line and 'memfd:aesir-source-copy' in line:assert '= -1' in line,(trace,line)
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\)\s*= 0',line)
  if m:
   unmaps.append((pid,m[1],int(m[2])))
   for key in list(active_maps):
    if active_maps[key]==unmaps[-1]:del active_maps[key]
  m=re.search(r'(pread64|pwrite64)\((\d+)<([^>]+)>.*?, (\d+), (\d+)\)\s*= (-?\d+)',line)
  if m:
   call,fd,label,want,offset,n=m.groups();want,offset,n=map(int,(want,offset,n))
   if '.gguf' in label or 'memfd:aesir-source-copy' in label:
    assert 0<want<=4096 and n<=want and offset>=0,(trace,line)
    row=dict(pid=pid,fd=fd,offset=offset,requested=want,returned=n,sealed='memfd:' in label)
    (reads if call=='pread64' else writes).append(row)
    if row['sealed'] and (pid,fd) in firstmap and order>firstmap[(pid,fd)] and call=='pread64':
     aftermap.append(row);phase=phases[(pid,fd)]
     assert offset==phase['done'] and want<=phase['size']-offset,(trace,row,phase)
     phase['reads']+=1
     if n>0:phase['done']+=n
  m=re.search(r'close\((\d+)<([^>]+)>.*?\)\s*= 0',line)
  if m:
   fd,label=m.groups()
   if 'memfd:aesir-source-copy' in label:
    assert (pid,fd) not in active_maps,(trace,'descriptor closed before unmap',line)
    memcloses.append((pid,fd))
    if (pid,fd) in phases:completed.append(phases.pop((pid,fd)))
   elif '.gguf' in label:closes.append((pid,fd,label))
   live.pop((pid,fd),None)
 assert Counter(memfds)==Counter(memcloses),(trace,memfds,memcloses)
 assert Counter(opens)==Counter(closes),(trace,opens,closes)
 assert not Counter(maps)-Counter(unmaps),(trace,maps,unmaps)
 rows.append(dict(trace=str(trace),sha256=hashlib.sha256(trace.read_bytes()).hexdigest(),source_opens=len(opens),source_closes=len(closes),memfds=len(memfds),memfd_closes=len(memcloses),sealed_readonly_maps=len(maps),exact_unmaps=len(maps),source_positional_reads=len(reads),copy_writes=len(writes),post_map_compiler_hash_reads=len(aftermap),complete_post_map_hash_phases=sum(p['reads']>0 and p['done']==p['size'] for p in completed),partial_post_map_hash_phases=sum(p['reads']>0 and p['done']<p['size'] for p in completed),seals=len(seals)))
assert rows
summary=dict(trace_count=len(rows),totals={k:sum(r[k] for r in rows) for k in rows[0] if isinstance(rows[0][k],int)},opaque_records=opaque,target_network_ioctl_or_inference_library_matches=0,traces=rows)
(out/'trace-audit.json').write_text(json.dumps(summary,indent=2)+'\n')
# Dependency inspection is separate from actual syscall effects.
deps=[]
for row in json.load(open('../owned-compiler-native-final/build-results.json')):
 result=subprocess.run(['ldd',row['binary']],capture_output=True,text=True,check=True)
 for forbidden in ('hailort','cuda','torch','onnxruntime','ggml','libcrypto','libssl'):assert forbidden not in result.stdout
 deps.append(dict(binary=row['binary'],source=row['source'],stdout=result.stdout,stderr=result.stderr,returncode=result.returncode))
(out/'dependency-inspection.json').write_text(json.dumps(deps,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='traces'},indent=2))
