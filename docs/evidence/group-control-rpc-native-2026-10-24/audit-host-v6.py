# Review copy;exact executed script is pinned in the immutable raw archive.
from pathlib import Path
from collections import Counter
import hashlib,json,re,sys
repo=Path.cwd();work=repo.parent;host=Path(sys.argv[1]).resolve();final=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();runs=json.loads((host/'runs.json').read_text());assert len(runs)%2==0
layout=json.loads((work/'group-control-rpc-native-selected-audit/header-layout.json').read_text());allowed_codes={layout[k] for k in ['HAILO_QUERY_DRIVER_INFO','HAILO_QUERY_DEVICE_PROPERTIES','HAILO_DESC_LIST_CREATE','HAILO_DESC_LIST_RELEASE','HAILO_SOC_CONNECT','HAILO_SOC_CLOSE','HAILO_VDMA_BUFFER_MAP','HAILO_VDMA_BUFFER_UNMAP','HAILO_VDMA_BUFFER_SYNC','HAILO_VDMA_ENABLE_CHANNELS','HAILO_VDMA_DISABLE_CHANNELS','HAILO_VDMA_INTERRUPTS_WAIT','HAILO_VDMA_LAUNCH_TRANSFER']};counts=Counter();faults=Counter();by_label={k:Counter() for k in ["current","frozen"]};generation_cases=[]
def joined(text):
 pending={};result=[]
 for line in text.splitlines():
  pid,b=line.split(' ',1);b=b.lstrip();assert pid.isdigit()
  if b.endswith('<unfinished ...>'):assert pid not in pending;pending[pid]=b.removesuffix('<unfinished ...>').rstrip()
  elif b.startswith('<... ') and ' resumed>' in b:assert pid in pending;result.append((int(pid),pending.pop(pid)+b.split(' resumed>',1)[1]))
  else:result.append((int(pid),b))
 assert not pending;return result
def state(r):
 pointers={(e['generation'],e['b']):'view'+str(e['a']) for e in r['events'] if e['op']=='allocated' and e['b']!=-1};result=[]
 for e in r['events']:
  j={k:v for k,v in e.items() if k not in ('pid','tid')}
  for k in ['a','b','c']:
   if k in j and (j['generation'],j[k]) in pointers:j[k]=pointers[(j['generation'],j[k])]
  result.append(json.dumps(j,sort_keys=True))
 return Counter(result)
for i in range(0,len(runs),2):
 a,b=runs[i:i+2];assert a['label']=='current' and b['label']=='frozen' and a['role']==b['role'] and a['fault']==b['fault'] and a.get('close')==b.get('close') and a['returncode']==b['returncode'] and a['arguments'][1:]==b['arguments'][1:]
 for ch in ['stdout','stderr']:assert (host/f'{i}.{ch}').read_bytes()==(host/f'{i+1}.{ch}').read_bytes()
 assert state(a)==state(b),(i,a['fault'],state(a)-state(b),state(b)-state(a));counts['full_fault_state_pairs']+=1;counts['full_pairs']+=1;counts['accept_pairs' if a['returncode']==0 else 'refuse_pairs']+=1;faults[a['fault']]+=1
for i,r in enumerate(runs):
 before_counts=counts.copy()
 assert not r['timed_out'] and not r['unresolved'];t=Path(r['trace']).read_text();calls=joined(t);assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for p,b in calls);assert sum(b.startswith('execve(') for p,b in calls)==1
 pids={p for p,b in calls};assert all(e['pid'] in pids and e['tid'] in pids for e in r['events']);main_pid=next(p for p,b in calls if b.startswith('execve('));workers={e['tid'] for e in r['events'] if e['op']=='wait_attempt'};assert main_pid not in workers;clones={int(m[1]) for p,b in calls if (m:=re.match(r'^clone(?:3)?\(.*\)\s+= (\d+)$',b))};assert workers<=clones;counts['actual_irq_workers']+=len(workers);assert not any(b.startswith(('ioctl(','connect(')) or re.search(r'openat\(.*"/dev/(?:h1x-|hailo)',b) for p,b in calls);assert not any(s in t.lower() for s in ['libhailort','libcuda','libtorch','libggml','libprotobuf','libxxhash','onnxruntime'])
 exit_indices={p:at for at,(p,b) in enumerate(calls) if b=='+++ exited with 0 +++'};attempts=[at for at,(p,b) in enumerate(calls) if b.startswith('write(') and str(host/f'{i}.events') in b and 'file_close_attempt' in b];generations=[e['generation'] for e in r['events'] if e['op']=='file_close_attempt'];assert len(attempts)==len(generations);close_attempts=dict(zip(generations,attempts));assert all(e['tid'] in exit_indices and exit_indices[e['tid']]<close_attempts[e['generation']] for e in r['events'] if e['op']=='wait_attempt');counts['worker_exits_before_context_close']+=len(workers);assert all(e['a'] in allowed_codes for e in r['events'] if e['op']=='ioctl');live={};owned={};drivers={};protected=set();file_generation=0;last_close={};addresses={}
 # Event records independently identify allocations and owning fd generations.
 for e in r['events']:
  if e['op']=='allocated' and e['b']!=-1:addresses[(e['generation'],e['a'])]=(e['b'],e['c'])
 for at,(p,b) in enumerate(calls):
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in live;live[fd]=b;counts['file_fd_generations']+=1
   if '"/dev/null"' in b:file_generation+=1;drivers[fd]=file_generation;counts['mock_file_opens']+=1
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ\|PROT_WRITE, MAP_PRIVATE\|MAP_ANONYMOUS, -1, 0\)\s+= (0x[0-9a-f]+)$',b)
  if m and (int(m[2],16),int(m[1])) in addresses.values():
   # A numeric VMA may be reused by a later fresh owner;bind current generation.
   addr=int(m[2],16);size=int(m[1]);assert addr not in owned;assert (addr,size) in [v for (g,j),v in addresses.items() if g==file_generation];owned[addr]=(size,file_generation);counts['actual_owned_views']+=1
  m=re.match(r'mprotect\((0x[0-9a-f]+), (\d+), (PROT_NONE|PROT_READ(?:\|PROT_WRITE)?)\)\s+= 0$',b)
  if m and int(m[1],16) in owned:
   addr=int(m[1],16);assert int(m[2])==owned[addr][0];counts['actual_protection_changes']+=1
   if m[3]=='PROT_NONE':protected.add(addr);counts['actual_cpu_blocks']+=1
   else:protected.discard(addr)
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:
   fd=int(m[1]);assert fd in live;live.pop(fd);counts['file_fd_closes']+=1
   if fd in drivers:last_close[drivers.pop(fd)]=at;counts['mock_file_closes']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and int(m[1],16) in owned:
   addr=int(m[1],16);size,g=owned.pop(addr);assert size==int(m[2]) and g in last_close and last_close[g]<at;protected.discard(addr);counts['actual_owned_unmaps']+=1
 # Only deliberate uncertain/mock-close or independent host-unmap failures survive.
 exits=[e for e in r['events'] if e['op']=='exit_resources'];expected_views=exits[-1]['a'] if exits else 0;expected_fds=exits[-1]['b'] if exits else 0
 assert len(owned)==expected_views and len(drivers)==expected_fds and len(live)==expected_fds,(i,r['fault'],owned,live,exits)
 counts['retained_views']+=len(owned);counts['retained_mock_fds']+=len(drivers)
 for e in r['events']:
  if e['op']=='wire':
   data=bytes.fromhex(e['hex']);n=r['body'];seq=int.from_bytes(data[8:12],'little');expected=(0x8a554432).to_bytes(4,'little')+n.to_bytes(4,'little')+seq.to_bytes(4,'little')+(1).to_bytes(4,'little')+(1).to_bytes(4,'little')+bytes((j*29+7)%256 for j in range(n))+bytes(2048-n);assert data==expected;counts['full_wire_checks']+=1
  if e['op']=='cpu_blocked':assert (e['generation'],e['a']) in addresses
  if e['op']=='file_close_attempt':counts['mock_close_attempts']+=1
  if e['op']=='launch_effect':counts['mock_launch_effects']+=1
 counts['traces']+=1
 for k,v in counts.items():by_label[r['label']][k]+=v-before_counts[k]
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 for p,d in json.loads((final/name).read_text()).items():assert h(repo/p)==h(final/folder/p)==d
for r in json.loads((final/'images.json').read_text()).values():assert h(Path(r['current']))==h(Path(r['frozen']))==r['sha256']
for p in final.glob('elf-*.stdout'):assert not any(s in p.read_bytes().lower() for s in [b'libhailort',b'libcuda',b'libtorch',b'libggml',b'libprotobuf',b'libxxhash',b'onnxruntime'])
assert by_label['current']==by_label['frozen'];result=dict(metrics=dict(counts),by_label={k:{name:value for name,value in v.items() if value} for k,v in by_label.items()},fault_pairs=dict(faults),physical_calls=False,numerical_execution=False,all_trace_calls_classified=True,all_owned_fds_vmas_accounted=True,full_byte_oracle=True,source_images_exact=True);(out/'census.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
