# Review copy; exact executed script is pinned in the raw archive.
from pathlib import Path
from collections import Counter
import hashlib,json,re
repo=Path.cwd();final=repo.parent/'session-transfer-pin-probe-final';host=repo.parent/'session-transfer-pin-probe-host';out=repo.parent/'session-transfer-pin-probe-host-audit';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ready=json.loads((host/'ready.json').read_text());assert ready['host_passed'] and ready['methods']==3
runs=json.loads((host/'runs.json').read_text());assert len(runs)==58;counts=Counter();s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')])
for i in range(0,len(runs),2):
 a,b=runs[i:i+2];assert a['role']==b['role'] and a['label']=='current' and b['label']=='frozen' and a['arguments'][1:]==b['arguments'][1:] and a['returncode']==b['returncode'];counts['full_pairs']+=1;counts['accept' if a['returncode']==0 else 'refuse']+=1
 for ch in ['stdout','stderr']:assert (host/f'{i}.{ch}').read_bytes()==(host/f'{i+1}.{ch}').read_bytes()
for i,r in enumerate(runs):
 assert not r['timed_out'] and not r['unresolved']
 if not r['trace']:continue
 t=Path(r['trace']).read_text();assert all(re.match(r'^\d+ ',line) for line in t.splitlines());calls=joined(t);assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for pid,b in calls)
 assert sum(b.startswith('execve(') for pid,b in calls)==1;pid=next(int(pid) for pid,b in calls if b.startswith('execve('));assert all(e['pid']==pid for e in r['events'])
 assert not any(b.startswith(('ioctl(','connect(')) or re.search(r'openat\(.*"/dev/(?:h1x-|hailo)',b) for p,b in calls)
 assert not any(x in t.lower() for x in ['libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime'])
 live={};sealed={};views={};driver=None;driver_close=-1
 for at,(p,b) in enumerate(calls):
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in live;live[fd]=b;counts['file_fd_generations']+=1
   if b.startswith('memfd_create('):sealed[fd]=True;counts['sealed_fds']+=1
   if '"/dev/null"' in b:assert driver is None;driver=fd;counts['mock_files']+=1
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)</memfd:[^>]+>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:assert int(m[2]) in sealed;views[m[3]]=int(m[1]);counts['readonly_private_views']+=1
  m=re.match(r'mprotect\((0x[0-9a-f]+), (\d+), PROT_NONE\)\s+= 0$',b)
  if m and m[1] in views:assert views[m[1]]==int(m[2]);counts['cpu_inaccessible_views']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in views:
   assert views.pop(m[1])==int(m[2]);assert driver is None or 0<=driver_close<at;counts['owned_unmaps']+=1
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:
   fd=int(m[1]);assert fd in live;opened=live.pop(fd);counts['fd_closes']+=1
   if fd==driver and '"/dev/null"' in opened:driver_close=at;counts['mock_file_closes']+=1
   if fd in sealed:assert driver is None or 0<=driver_close<at;del sealed[fd];counts['sealed_closes']+=1
  if b.startswith('pread64(') and '/memfd:' in b:assert driver is None or 0<=driver_close<at
 expected=2 if any(e['op']=='actual_exit_resources' and e['a']==2 for e in r['events']) else 0
 assert len(sealed)==len(views)==expected
 allowed=set(sealed)
 if driver is not None and driver_close<0:assert expected==2;allowed.add(driver)
 assert set(live)==allowed
 counts['traces']+=1;counts['retained_sealed_fds']+=expected;counts['retained_vmas']+=expected
for i in range(5):
 for tag in ['dynamic','symbols']:
  data=(final/f'elf-{i:03d}-{tag}.stdout').read_bytes();assert not (final/f'elf-{i:03d}-{tag}.stderr').read_bytes();assert not any(x in data.lower() for x in [b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'])
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 for p,d in json.loads((final/name).read_text()).items():assert h(Path(p))==h(final/folder/p)==d
images=json.loads((final/'binaries.json').read_text())['images']
for role,r in images.items():assert h(Path(r['current']))==r['sha256'] and h(Path(r['frozen']))==r['frozen_sha256']
j=dict(host_methods=3,host_runs=58,metrics=dict(counts),binary_manifest_sha256=h(final/'binaries.json'),ready_sha256=h(host/'ready.json'),physical_calls=False,all_links_before_host=True,source_inputs_exact=True,excluded_runtime_links=False)
(out/'census.json').write_text(json.dumps(j,indent=2)+'\n');(out/'ready.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(j,indent=2))
