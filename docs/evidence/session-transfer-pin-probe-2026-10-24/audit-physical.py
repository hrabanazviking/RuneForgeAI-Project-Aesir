# Review copy; exact executed script is pinned in the raw archive.
from pathlib import Path
from collections import Counter
import json,re,hashlib
repo=Path.cwd();root=repo.parent/'session-transfer-pin-probe-physical';out=repo.parent/'session-transfer-pin-probe-physical-audit';out.mkdir(exist_ok=False);runs=json.loads((root/'runs.json').read_text());assert len(runs)==4;ready=json.loads((repo.parent/'session-transfer-pin-probe-host/ready.json').read_text());allowed={int(v):k for k,v in ready['codes'].items()};s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')]);total=Counter();per=[]
def code(text):
 m=re.fullmatch(r'_IOC\(([^,]+), ([^,]+), ([^,]+), ([^)]+)\)',text);assert m,text;flags=0
 for flag in m[1].split('|'):flags|={'_IOC_NONE':0,'_IOC_WRITE':1,'_IOC_READ':2}[flag.strip()]
 return (flags<<30)|(int(m[2],0)<<8)|int(m[3],0)|(int(m[4],0)<<16)
for i,r in enumerate(runs):
 assert r['label']=='current' and r['returncode']==0 and not r['mock'] and not r['events'] and not r['timed_out'] and not r['unresolved'];assert not (root/f'{i}.stderr').read_bytes();j=json.loads((root/f'{i}.stdout').read_text());text=Path(r['trace']).read_text();assert all(re.match(r'^\d+ ',line) for line in text.splitlines());calls=joined(text);assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for pid,b in calls)
 assert sum(b.startswith('execve(') for pid,b in calls)==1;assert any(b.startswith('exit_group(0)') for pid,b in calls)
 for bad in ['connect(','libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime','faults.so']:assert bad not in text.lower(),(i,bad)
 live={};sealed={};vmas={};driver=None;driver_closed=-1;counts=Counter();ops=[]
 for at,(pid,b) in enumerate(calls):
  assert '???' not in b
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in live;live[fd]=b;counts['file_fd_generations']+=1
   if b.startswith('memfd_create('):sealed[fd]=True;counts['actual_sealed_fds']+=1
   if re.search(r'"/dev/(?:h1x-|hailo)',b):assert driver is None;driver=fd;counts['actual_device_opens']+=1
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)</memfd:[^>]+>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:assert int(m[2]) in sealed and m[3] not in vmas;vmas[m[3]]=int(m[1]);counts['actual_readonly_private_views']+=1
  if b.startswith('ioctl('):
   m=re.match(r'ioctl\((\d+)<.*>, (_IOC\([^)]+\)), .*\)\s+= 0$',b);assert m,b;assert int(m[1])==driver and driver_closed<0;number=code(m[2]);assert number in allowed,(i,number,b);op=allowed[number];ops.append(op);counts['actual_ioctls']+=1;counts['ioctl_'+op]+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in vmas:assert vmas.pop(m[1])==int(m[2]) and 0<=driver_closed<at;counts['actual_owned_unmaps']+=1
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:
   fd=int(m[1]);assert fd in live;opened=live.pop(fd);counts['actual_file_fd_closes']+=1
   if fd==driver and re.search(r'"/dev/(?:h1x-|hailo)',opened):driver_closed=at;counts['actual_device_closes']+=1
   if fd in sealed:assert 0<=driver_closed<at;del sealed[fd];counts['actual_sealed_closes']+=1
  if b.startswith('pread64(') and '/memfd:' in b:
   counts['actual_sealed_positional_reads']+=1
   if driver is not None:assert 0<=driver_closed<at;counts['actual_sealed_reads_after_context_close']+=1
 assert driver is not None and driver_closed>=0 and not live and not sealed and not vmas
 expected=['driver-info','properties','desc-create','desc-create','connect']+(['buffer-map','buffer-map'] if i else [])+['close','desc-release','desc-release'];assert ops==expected,(i,ops)
 if i:
  n=int(r['arguments'][1]);assert n in (70,4097,16385);e=ready['expected'][str(n)];assert all(j[k]==v for k,v in e.items());assert j['page_size']==16384 and j['properties']['desc_max_page_size']==4096 and j['allocated_descriptors_per_direction']==65536 and j['descriptor_page_size']==512;assert j['group_count']==2 and j['same_file_group'] and j['context_finalized'] and j['host_released'] and j['closed_group_refused'];assert not any(j[k] for k in ['hardware_idle_confirmed','remote_cleanup_confirmed','dma_submitted','program_submitted','execution_tested']);assert counts['actual_readonly_private_views']==counts['actual_owned_unmaps']==counts['actual_sealed_fds']==counts['actual_sealed_closes']==2
 else:assert r['role']=='session' and j['connection_closed'] and not j['user_dma_submitted'];assert not counts['actual_sealed_fds']
 counts['children']+=1;per.append(dict(child=i,role=r['role'],operations=ops,counts=dict(counts),actual_input_channel=j['input_channel'],actual_output_channel=j['output_channel']));total.update(counts)
assert total['children']==4 and total['actual_ioctls']==38 and total['ioctl_buffer-map']==6 and total['actual_device_opens']==total['actual_device_closes']==4 and total['actual_readonly_private_views']==total['actual_owned_unmaps']==total['actual_sealed_fds']==total['actual_sealed_closes']==6
j=dict(physical=dict(total),cases=per,module_identity=json.loads((root/'module-identity.json').read_text()),hardware_idle_or_remote_cleanup_confirmed=False,descriptor_usage_inferred=False,dma_submitted=False,program_submitted=False,source_model_execution=False,no_repeated_children=True);(out/'census.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(j,indent=2))
