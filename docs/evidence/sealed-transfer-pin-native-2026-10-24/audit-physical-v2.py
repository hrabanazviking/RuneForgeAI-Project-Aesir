from pathlib import Path
from collections import Counter
import json,re,hashlib
repo=Path.cwd();host=repo.parent/'sealed-group-pin-native-host-audit-v2';physical=repo.parent/'sealed-group-pin-native-physical-v2';out=repo.parent/'sealed-group-pin-native-physical-audit-v2';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=json.loads((physical/'results.json').read_text());assert len(rows)==7 and all(r['returncode']==0 for r in rows)
source=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(source[source.index('def joined('):source.index('results=json.loads')])
count=Counter(children=7);cases=[]
allowed=[('_IOC(_IOC_WRITE, 0x67, 0x1, 0xc)','identity'),('_IOC(_IOC_WRITE, 0x67, 0, 0x13)','properties'),('_IOC(_IOC_READ|_IOC_WRITE, 0x76, 0x3, 0x20)','map'),('_IOC(_IOC_READ, 0x76, 0x4, 0x20)','unmap')]
for i,r in enumerate(rows):
 for ch in ['stdout','stderr']:assert (physical/f'call-{i}.{ch}').read_bytes()==r[ch].encode()
 j=json.loads(r['stdout']);assert j['properties']==dict(desc_max_page_size=4096,board_type=2,dma_type=0,dma_engines_count=1,is_fw_loaded=True) and j['driver_info']==dict(major=5,minor=3,revision=0)
 assert not any(j[k] for k in ['dma_submitted','program_submitted','execution_tested'])
 t=(physical/f'call-{i}.strace').read_text();assert t.count('execve(')==1 and 'connect(' not in t
 for bad in ['libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime']:assert bad not in t.lower()
 calls=joined(t);assert any(b.startswith('exit_group(0)') for pid,b in calls)
 vmas={};live={};opened=-1;closed=-1;ops=[];pread_after=0;all_mmaps={};owned_unmaps=[];device_fd=None
 for at,(pid,b) in enumerate(calls):
  assert '???' not in b
  m=re.match(r'memfd_create\("(aesir-[^"]+)".*\)\s+= (\d+)<',b)
  if m:assert int(m[2]) not in live;live[int(m[2])]=m[1];count['actual_memfds']+=1
  m=re.match(r'openat\(.*"/dev/h1x-0".*\)\s+= (\d+)<',b)
  if m:assert opened<0;opened=at;device_fd=int(m[1]);count['device_opens']+=1
  m=re.match(r'mmap\(NULL, (\d+), (PROT_[^,]+), (MAP_[^,]+), .*\)\s+= (0x[0-9a-f]+)$',b)
  if m:all_mmaps[m[4]]=(at,int(m[1]),m[2],m[3])
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)</memfd:[^>]+>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:assert int(m[2]) in live;vmas[m[3]]=int(m[1]);count['readonly_private_sealed_vmas']+=1
  if b.startswith('ioctl('):
   assert device_fd is not None and b.startswith('ioctl('+str(device_fd)+'</dev/h1x-0<char 508:0>>,'),b
   matches=[label for spelling,label in allowed if spelling in b];assert len(matches)==1 and b.endswith('= 0'),b;ops.append(matches[0]);count['actual_'+matches[0]+'_ioctls']+=1
  if b.startswith('close(') and '</dev/h1x-0<char 508:0>>' in b:
   assert b.endswith('= 0') and closed<0;closed=at;count['confirmed_device_closes']+=1
  if b.startswith('pread64(') and '/memfd:' in b and closed>=0:pread_after+=1
  m=re.match(r'close\((\d+)</memfd:[^>]+>\(deleted\)\)\s+= 0$',b)
  if m:assert opened<closed<at and int(m[1]) in live;del live[int(m[1])];count['actual_sealed_closes_after_device_close']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in all_mmaps:
   created,n,prot,flags=all_mmaps.pop(m[1])
   if n!=int(m[2]):
    assert m[1] not in vmas
    count['other_runtime_partial_unmap_records']+=1
    continue
   if m[1] in vmas:
    assert opened<closed<at and vmas.pop(m[1])==n;count['sealed_unmaps_after_device_close']+=1;owned_unmaps.append((m[1],n))
   elif r['kind']=='control' and opened<closed<at and created<opened and n==j['mapping_bytes'] and prot=='PROT_READ|PROT_WRITE' and flags=='MAP_PRIVATE|MAP_ANONYMOUS':
    count['anonymous_control_unmaps_after_device_close']+=1;owned_unmaps.append((m[1],n))
 assert 0<=opened<closed and not live and not vmas,(i,live,vmas)
 expected=['identity','properties']+(['map','map','unmap','unmap'] if r['kind']=='group' else ['map','unmap']);assert ops==expected,(i,ops)
 assert len(owned_unmaps)==(2 if r['kind']=='group' else 1)
 if r['kind']=='group':assert pread_after>0;count['group_cases']+=1;count['actual_sealed_reads_after_device_close']+=pread_after
 else:count['control_cases']+=1
 cases.append(dict(child=i,kind=r['kind'],size=r['size'],page_size=j['page_size'],operations=ops,owning_file_closed_before_release=True,postfinalization_backing_reads=pread_after))
assert count['actual_map_ioctls']==count['actual_unmap_ioctls']==10 and count['confirmed_device_closes']==7 and count['group_cases']==3 and count['control_cases']==4
j=json.loads((host/'census.json').read_text());j['physical']=dict(count);j['physical_cases']=cases;j['scope']['physical_attempted']=True;j['scope']['physical_dma_or_numerical_execution']=False
(out/'census.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(count),indent=2))
