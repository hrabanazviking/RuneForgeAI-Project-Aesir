from pathlib import Path
from collections import Counter
import hashlib,json,re,subprocess
repo=Path.cwd();base=repo.parent/'sealed-group-pin-native-baseline';final=repo.parent/'sealed-group-pin-native-final-v3';new=repo.parent/'sealed-group-pin-native-new-host/new';old=repo.parent/'sealed-group-pin-native-host';out=repo.parent/'sealed-group-pin-native-host-audit-v2';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((new.parent/'result.json').read_text())['returncode']==0
assert (repo.parent/'sealed-group-pin-native-permission-oracle/ready.json').exists()
rows=json.loads((new/'runs.json').read_text());assert len(rows)==92;count=Counter(new_calls=len(rows),new_methods=6)
uncertain={'close_before','close_after','identity_close_before','identity_close_after','unmap_close_before','unmap_close_after'}
def join(text):
 pending=None;result=[]
 for b in text.splitlines():
  if '<unfinished ...>' in b:assert pending is None;pending=b.replace(' <unfinished ...>','');continue
  m=re.match(r'<\.\.\. (\w+) resumed>(.*)',b)
  if m:assert pending and pending.startswith(m[1]+'(');b=pending+m[2];pending=None
  assert '???' not in b and 'resumed>' not in b and 'unfinished' not in b,b
  assert re.match(r'^(?:\w+\(|--- |\+\+\+ |strace:)',b),b
  result.append(b)
 assert pending is None
 return result
per_call=[]
for i,r in enumerate(rows):
 assert all((new/f'call-{i:04d}.{ch}').read_bytes()==r[ch].encode() for ch in ['stdout','stderr'])
 if r['returncode']!=0 or r['arguments'][0]=='poison':
  assert i+1<len(rows) and rows[i+1]['returncode']==0 and rows[i+1].get('fresh_recovery_for_call')==i;count['refusal_or_poison_then_fresh_success']+=1
 events=r['events'];assert not any(e['op'].startswith('unsafe_') or e['op']=='forbidden_ioctl' for e in events)
 count['actual_kernel_views']+=sum(e['op']=='actual_kernel_view' for e in events)
 count['independent_kernel_view_bytes']+=sum(e['b'] for e in events if e['op']=='actual_kernel_view')
 count['mock_map_effects']+=sum(e['op']=='map_effect' for e in events);count['mock_unmap_effects']+=sum(e['op']=='unmap_effect' for e in events)
 files=list(new.glob(f'call-{i:04d}.trace.*'));assert files;main=[]
 for p in files:
  calls=join(p.read_text());count['pid_trace_files']+=1
  assert not any('/dev/h1x-' in b or '/dev/hailo' in b or b.startswith(('ioctl(','connect(')) for b in calls),(i,p)
  assert not any(x in p.read_text().lower() for x in ['libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime'])
  if any(b.startswith('execve(') for b in calls):main.append((p,calls))
  else:assert not any(b.startswith('memfd_create(') for b in calls)
 assert len(main)==1;path,calls=main[0];assert sum(b.startswith('execve(') for b in calls)==1
 assert any(b.startswith('exit_group('+str(r['returncode'])+')') for b in calls),(i,r['returncode'])
 live={};sealed={};vmas={};driver_close=-1;driver_fd=None
 for at,b in enumerate(calls):
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in live,(i,b,live.get(fd));live[fd]=b;count['observed_fd_generations']+=1
   if b.startswith('memfd_create('):sealed[fd]=b;count['actual_memfds']+=1
   if '"/dev/null"' in b:assert driver_fd is None;driver_fd=fd;count['actual_mock_files']+=1
  assert not ('F_DUPFD' in b),b
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)<.*memfd:.*>,?\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  # strace decoration closes the <...> before its (deleted) suffix.
  if not m:m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)</memfd:[^>]+>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:
   assert int(m[2]) in sealed;assert m[3] not in vmas;vmas[m[3]]=int(m[1]);count['actual_readonly_private_vmas']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in vmas:
   assert vmas.pop(m[1])==int(m[2]);count['actual_owned_unmaps']+=1
   if driver_fd is not None:assert 0<=driver_close<at,(i,b)
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:
   fd=int(m[1]);assert fd in live,(i,b);generation=live.pop(fd);count['actual_observed_closes']+=1
   if fd==driver_fd and '"/dev/null"' in generation:driver_close=at;count['actual_mock_file_closes']+=1
   if fd in sealed:
    if driver_fd is not None:assert 0<=driver_close<at,(i,b)
    del sealed[fd];count['actual_sealed_closes']+=1
  if b.startswith('pread64(') and '/memfd:' in b:
   count['actual_sealed_positional_reads']+=1
   if driver_close>=0:count['actual_sealed_reads_after_driver_close']+=1
 if r['fault'] in uncertain:
  assert len(sealed)==len(vmas)==2,(i,r['fault'],sealed,vmas);assert sum(e['op']=='driver_close_attempt' for e in events)==1;count['cases_retaining_both_parts_until_exit']+=1
 else:
  want_sealed=1 if r['fault'].startswith('sealed_close_before') else 0
  want_vmas=1 if r['fault'].startswith('munmap_before') else 0
  assert len(sealed)==want_sealed and len(vmas)==want_vmas,(i,r['fault'],sealed,vmas)
  count['separate_sealed_close_retentions']+=want_sealed;count['separate_host_unmap_retentions']+=want_vmas
 # No observed descriptor silently survives, except intentionally retained cases.
 allowed=set(sealed)
 if r['fault'] in uncertain and r['fault'].endswith('before') and driver_fd is not None:allowed.add(driver_fd)
 assert set(live)==allowed,(i,r['fault'],live,allowed)
 per_call.append(dict(call=i,pid=path.suffix[1:],fault=r['fault'],retained_sealed=len(sealed),retained_vmas=len(vmas)))
# Complete old current/frozen triples, including auxiliary consumers.
old_results=json.loads((old/'results.json').read_text());assert len(old_results)==8 and all(r['returncode']==0 for r in old_results);old_totals=Counter();old_suites={}
for r in old_results:
 name=r['suite'];text=(old/(name+'.stderr')).read_text();m=re.search(r'Ran (\d+) tests?',text);assert m;textmethods=int(m[1]);c=Counter(methods=textmethods)
 for i,x in enumerate(json.loads((old/(name+'-raw/records.json')).read_text())):
  c['primary']+=1
  if 'frozen_returncode' in x:
   assert x['returncode']==x['frozen_returncode'];c['frozen_pairs']+=1;c['frozen_accept' if x['returncode']==0 else 'frozen_refuse']+=1
   for ch in ['stdout','stderr']:assert (old/(name+'-raw')/(str(i)+'.current.'+ch)).read_bytes()==(old/(name+'-raw')/(str(i)+'.frozen.'+ch)).read_bytes()
 old_suites[name]=dict(c);old_totals.update(c)
# Actual source closure, baseline copies, all compiler/control identities.
for root in [base,final]:
 for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
  for p,d in json.loads((root/name).read_text()).items():assert h(root/folder/p)==h(Path(p))==d
controls=json.loads((base/'controls.json').read_text());assert len(controls)==154
for r in controls:assert h(Path(r['binary']))==r['sha256']
manifest=Path('docs/evidence/sealed-group-pin-contract-2026-10-24/archive-identities.json');assert h(manifest)=='93d8bd729867e9529946266dd56fef1450aa872d7caa903a731fdd2702942e97'
for r in json.loads(manifest.read_text()):p=Path(r['path']);assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
assert h(Path('/home/pi/mojo-dev/.pixi/envs/default/bin/mojo'))=='be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39'
binary_rows=json.loads((final/'build-results.json').read_text())+json.loads((final/'c-build-results.json').read_text())
for i,r in enumerate(binary_rows):
 p=Path(r['binary']);assert h(p)==r['sha256']
 for arg,label in [('-d','dynamic'),('-Ws','symbols')]:
  x=subprocess.run(['readelf',arg,str(p)],capture_output=True);assert x.returncode==0 and not x.stderr;(out/f'elf-{i:02d}-{label}.txt').write_bytes(x.stdout)
  assert not any(b in x.stdout.lower() for b in [b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'])
summary=dict(new=dict(count),old=dict(old_totals),old_suites=old_suites,scope=dict(old_mojo=702,old_python=85,final_mojo=705,final_python=86,controls=154,old_edits=0,mojo_links=21,c_links=9,elf_tables=60,physical_attempted=False),per_call=per_call)
(out/'census.json').write_text(json.dumps(summary,indent=2)+'\n');(out/'host-ready.json').write_text(json.dumps(dict(census_sha256=h(out/'census.json'),binary_identities={r['binary']:r['sha256'] for r in binary_rows},physical_attempted=False),indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='per_call'},indent=2))
