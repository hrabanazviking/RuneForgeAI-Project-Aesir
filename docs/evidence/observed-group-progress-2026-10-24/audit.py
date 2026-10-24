from pathlib import Path
from collections import Counter
import hashlib,json,re
repo=Path.cwd();base=repo.parent/'soc-observed-progress-baseline';final=repo.parent/'soc-observed-progress-final-v3';host=repo.parent/'soc-observed-progress-host';out=repo.parent/'soc-observed-progress-audit';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
results=json.loads((host/'results.json').read_text());assert len(results)==2 and all(r['returncode']==0 for r in results)
s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')])
summary={};total=Counter();sources=set();new_sources={'smidr/tools/soc_exchange_progress.mojo','tests/hailo_soc_exchange_progress_api.mojo'}
for result in results:
 name=result['suite'];folder=host/(name+'-raw');rows=json.loads((folder/'records.json').read_text());c=Counter(primary=len(rows));m=re.search(r'Ran (\d+) tests?',(host/(name+'.stderr')).read_text());assert m;c['methods']=int(m[1])
 for i,r in enumerate(rows):
  sources.add(r['source']);assert r['source']!='smidr/tools/soc_rpc_device.mojo'
  assert r['equal'] and r['returncode']==r['frozen_returncode']
  for ch in ['stdout','stderr']:assert (folder/f'{i}.current.{ch}').read_bytes()==(folder/f'{i}.frozen.{ch}').read_bytes()
  c['complete_frozen_pairs']+=1;c['frozen_accept' if r['returncode']==0 else 'frozen_refuse']+=1
  if name=='observed' and r['source']=='smidr/tools/soc_exchange_progress.mojo' and r['returncode']:
   assert i+1<len(rows) and rows[i+1]['source']==r['source'] and rows[i+1]['returncode']==0;c['refusal_to_fresh_success_joins']+=1
  if r['source'] not in new_sources:continue
  assert r['traced'];t=(folder/f'{i}.strace').read_text();assert t.count('execve(')==1;c['new_consumer_traces']+=1
  assert all(re.match(r'^\d+ ',line) for line in t.splitlines());calls=joined(t)
  assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for pid,b in calls)
  assert any(b.startswith('exit_group('+str(r['returncode'])+')') for pid,b in calls)
  for bad in ['/dev/h1x-','/dev/hailo','ioctl(','connect(','memfd_create(','libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime']:assert bad not in t.lower(),(i,bad)
  live={}
  for pid,b in calls:
   assert '???' not in b
   m=re.match(r'openat\(.*\)\s+= (\d+)<',b)
   if m:
    fd=int(m[1]);assert fd not in live;live[fd]=(pid,b);c['observed_file_fd_generations']+=1
   assert 'F_DUPFD' not in b
   m=re.match(r'close\((\d+).*\)\s+= 0$',b)
   if m:
    fd=int(m[1]);assert fd in live;del live[fd];c['observed_file_fd_closes']+=1
   if b.startswith('mmap('):c['runtime_mmap_calls']+=1
   if b.startswith('munmap('):c['runtime_munmap_calls']+=1
  assert not live
 summary[name]=dict(c);total.update(c)
assert sources==new_sources|{'tests/hailo_soc_progress.mojo'}
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 old=json.loads((base/name).read_text());new=json.loads((final/name).read_text())
 for p,d in old.items():assert h(base/folder/p)==d
 for p,d in new.items():assert h(final/folder/p)==h(Path(p))==d
 assert [p for p,d in old.items() if new.get(p)!=d]==(['hailbru/soc_progress.mojo'] if folder=='source-snapshot' else [])
for r in json.loads((base/'controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
for r in json.loads(Path('docs/evidence/observed-progress-contract-2026-10-24/archive-identities.json').read_text()):assert h(repo.parent/r['path'])==r['sha256']
assert h(Path('/home/pi/mojo-dev/.pixi/envs/default/bin/mojo'))=='be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39'
for i,r in enumerate(json.loads((final/'build-results.json').read_text())):
 assert h(Path(r['binary']))==r['sha256']
 for tag in ['dynamic','symbols']:
  data=(final/f'elf-{i}-{tag}.stdout').read_bytes();assert not (final/f'elf-{i}-{tag}.stderr').read_bytes()
  assert not any(x in data.lower() for x in [b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'])
summary['total']=dict(total);summary['scope']=dict(old_mojo=708,old_python=87,final_mojo=711,final_python=88,current_controls=158,contract_archive_paths=806,old_mojo_edits=1,old_test_edits=0,mojo_links=4,elf_tables=8,affected_closure=json.loads((final/'affected-closure.json').read_text()),physical_calls=False,numerical_execution=False,new_binary_pairs='same-image frozen reproducibility;not a pre-existing capability',legacy_pairs='pre-edit vs final observable triples')
(out/'census.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
