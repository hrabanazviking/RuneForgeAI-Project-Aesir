# Review copy: compiler path comes from the retained identity;raw exact audit is pinned in the archive.
from pathlib import Path
from collections import Counter
import json,hashlib,re
repo=Path.cwd();base=repo.parent/'session-group-pin-native-baseline';final=repo.parent/'session-group-pin-native-final-v4';host=repo.parent/'session-group-pin-native-host-v4';out=repo.parent/'session-group-pin-native-audit-v4';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
results=json.loads((host/'results.json').read_text());assert len(results)==10 and all(r['returncode']==0 for r in results)
s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')])
suites={};totals=Counter();newrows={}
for r in results:
 name=r['suite'];folder=host/(name+'-raw');rows=json.loads((folder/'records.json').read_text());c=Counter(primary=len(rows));m=re.search(r'Ran (\d+) tests?',(host/(name+'.stderr')).read_text());assert m;c['methods']=int(m[1])
 for i,x in enumerate(rows):
  assert x['equal'] and x['returncode']==x['frozen_returncode'],(name,i,x)
  for channel in ['stdout','stderr']:assert (folder/f'{i}.current.{channel}').read_bytes()==(folder/f'{i}.frozen.{channel}').read_bytes()
  c['full_frozen_pairs']+=1;c['accept' if x['returncode']==0 else 'refuse']+=1
  if name=='session-group' and x['source']!='protoc':newrows[x['arguments'][x['arguments'].index('-o')+1]]=(i,x)
 suites[name]=dict(c);totals.update(c)
assert totals['methods']==76
runs=json.loads((host/'session-group/runs.json').read_text());assert len(runs)==len(newrows)==101
uncertain={'close_before','close_after','identity_close_before','identity_close_after','map_close_before','map_close_after'};metrics=Counter();per_call=[]
def audit_trace(path,events,run):
 t=path.read_text();assert all(re.match(r'^\d+ ',line) for line in t.splitlines());calls=joined(t)
 assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for pid,b in calls)
 assert sum(b.startswith('execve(') for pid,b in calls)==1
 main={int(pid) for pid,b in calls if b.startswith('execve(')};assert len(main)==1;pid=next(iter(main));assert all(e['pid']==pid for e in events)
 assert any(b.startswith(f'exit_group({run["returncode"]})') for p,b in calls)
 for bad in ['/dev/h1x-','/dev/hailo','ioctl(','connect(','libhailort','libcuda','libggml','libtorch','libxxhash','libprotobuf','onnxruntime']:assert bad not in t.lower(),(path,bad)
 c=Counter(traces=1);live={};sealed={};vmas={};driver_generations=[]
 for at,(p,b) in enumerate(calls):
  assert '???' not in b
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in live,(path,b,live);record=dict(fd=fd,opened=at,closed=None,driver=None,sealed=b.startswith('memfd_create('),mock='"/dev/null"' in b);live[fd]=record;c['file_fd_generations']+=1
   if record['sealed']:sealed[fd]=record;c['actual_sealed_fds']+=1
   if record['mock']:
    c['actual_mock_files']+=1;driver_generations.append(record)
    for value in sealed.values():assert value['driver'] is None;value['driver']=record
    for value in vmas.values():assert value['driver'] is None;value['driver']=record
  assert 'F_DUPFD' not in b
  m=re.match(r'mmap\(NULL, (\d+), PROT_READ, MAP_PRIVATE, (\d+)</memfd:[^>]+>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:
   fd=int(m[2]);assert fd in sealed and m[3] not in vmas;vmas[m[3]]=dict(bytes=int(m[1]),driver=None,protected=False);c['actual_readonly_private_views']+=1
  m=re.match(r'mprotect\((0x[0-9a-f]+), (\d+), PROT_NONE\)\s+= 0$',b)
  if m and m[1] in vmas:
   v=vmas[m[1]];assert v['bytes']==int(m[2]) and not v['protected'];v['protected']=True;c['actual_owned_views_cpu_inaccessible']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in vmas:
   v=vmas.pop(m[1]);assert v['bytes']==int(m[2]);d=v['driver'];assert d is None or d['closed'] is not None and d['closed']<at;c['actual_owned_unmaps']+=1
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:
   fd=int(m[1]);assert fd in live,(path,b,live);v=live.pop(fd);v['closed']=at;c['actual_file_fd_closes']+=1
   if v['sealed']:
    d=v['driver'];assert d is None or d['closed'] is not None and d['closed']<at;del sealed[fd];c['actual_sealed_closes']+=1
   if v['mock']:c['actual_mock_file_closes']+=1
  if b.startswith('pread64(') and '/memfd:' in b:
   m=re.match(r'pread64\((\d+)<',b);assert m and int(m[1]) in sealed;d=sealed[int(m[1])]['driver'];assert d is None or d['closed'] is not None and d['closed']<at;c['actual_sealed_positional_reads']+=1
   if d is not None:c['actual_sealed_reads_after_context_close']+=1
 fault=run['fault'];expected_sealed=2 if fault in uncertain else (1 if fault.startswith('sealed_close_before') else 0);expected_vmas=2 if fault in uncertain else (1 if fault.startswith('munmap_before') else 0)
 assert len(sealed)==expected_sealed and len(vmas)==expected_vmas,(path,fault,sealed,vmas)
 allowed=set(sealed)
 for d in driver_generations:
  if d['closed'] is None:assert fault in uncertain and fault.endswith('before');allowed.add(d['fd'])
 assert set(live)==allowed,(path,fault,live,allowed)
 exits=[e for e in events if e['op']=='actual_exit_resources']
 if events:assert len(exits)==1 and (exits[0]['a'],exits[0]['b'])==(expected_sealed,expected_vmas)
 opens=[e for e in events if e['op']=='driver_opened'];assert len(opens)==len(driver_generations)
 for generation,d in enumerate(driver_generations,1):
  e=opens[generation-1];assert e['a']==d['fd'] and e['b']==generation
  for effect in [e for e in events if e['op']=='map_file_generation' and e['c']==generation]:assert effect['b']==d['fd']
 c['actual_kernel_views']+=sum(e['op']=='actual_kernel_view' for e in events);c['kernel_compared_view_bytes']+=sum(e['b'] for e in events if e['op']=='actual_kernel_view');c['mock_map_effects']+=sum(e['op']=='map_effect' for e in events)
 if fault in uncertain:c['two_part_retention_cases']+=1
 c['deliberate_retained_fds']+=expected_sealed;c['deliberate_retained_vmas']+=expected_vmas
 return c
for i,run in enumerate(runs):
 record_index,record=newrows[run['trace']]
 if run['returncode'] or run['arguments'][1]=='poison':
  assert i+1<len(runs) and runs[i+1]['returncode']==0 and runs[i+1].get('fresh_recovery_for_call')==i;metrics['refusal_or_poison_fresh_success_joins']+=1
 current_events=[json.loads(x) for x in (host/'session-group'/f'{i}.events').read_text().splitlines()] if (host/'session-group'/f'{i}.events').exists() else [];assert current_events==run['events']
 paths=[(Path(run['trace']),current_events,'current'),(Path(run['trace']+'.frozen-'+str(record_index)),[json.loads(x) for x in Path(str(host/'session-group'/f'{i}.events')+'.frozen-'+str(record_index)).read_text().splitlines()] if Path(str(host/'session-group'/f'{i}.events')+'.frozen-'+str(record_index)).exists() else [],'frozen')]
 for p,events,label in paths:
  c=audit_trace(p,events,run)
  for key,value in c.items():metrics[label+'_'+key]+=value
 per_call.append(dict(call=i,fault=run['fault'],api=run['api'],returncode=run['returncode']))
for root in [base,final]:
 for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
  for p,d in json.loads((root/name).read_text()).items():assert h(Path(p))==h(root/folder/p)==d
for r in json.loads((base/'controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
m=Path('docs/evidence/group-session-finalization-2026-10-24/archive-identities.json');assert h(m)=='49b6fef59119b58a9c5eeba32b064499430f857f7b08d88cbc6c2dd4a84d4d4a'
for r in json.loads(m.read_text())['paths']:p=repo.parent/r['path'];assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
assert h(Path(json.loads((base/'compiler.json').read_text())['path']))=='be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39'
for i,r in enumerate(json.loads((final/'build-results.json').read_text())+json.loads((final/'c-build-results.json').read_text())):
 assert h(Path(r['binary']))==r['sha256']
 if 'source_sha256' in r:assert h(Path(r['source']))==r['source_sha256']
 for tag in ['dynamic','symbols']:
  data=(final/f'elf-{i:03d}-{tag}.stdout').read_bytes();assert not (final/f'elf-{i:03d}-{tag}.stderr').read_bytes()
  assert not any(x in data.lower() for x in [b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'])
for r in json.loads((host/'supplement-controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
j=dict(suites=suites,total=dict(totals),new_primary_calls=101,new_metrics=dict(metrics),per_call=per_call,scope=dict(old_mojo=711,old_python=88,final_mojo=714,final_python=89,controls=161,contract_paths=827,old_production_edits=0,old_test_edits=0,mojo_links=23,c_links=10,elf_tables=66,closure=json.loads((final/'affected-closure.json').read_text()),physical_calls=False,numerical_execution=False,new_pairs='new frozen-image reproducibility;legacy comparisons use qualified prior images'))
(out/'census.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({k:v for k,v in j.items() if k!='per_call'},indent=2))
