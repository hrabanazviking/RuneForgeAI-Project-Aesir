from pathlib import Path
from collections import Counter
import hashlib,json,re,subprocess
repo=Path.cwd();base=repo.parent/'soc-prepare-native-baseline';final=repo.parent/'soc-prepare-native-final';host=repo.parent/'soc-prepare-native-host';out=repo.parent/'soc-prepare-native-audit-v2';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
results=json.loads((host/'results.json').read_text());assert len(results)==3 and all(r['returncode']==0 for r in results)
s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')])
summary={};total=Counter();exercised=set();new_sources={'smidr/tools/soc_prepare.mojo','tests/hailo_soc_prepare_api.mojo','prepare-oracle'}
for result in results:
 name=result['suite'];folder=host/(name+'-raw');rows=json.loads((folder/'records.json').read_text());c=Counter(primary=len(rows));m=re.search(r'Ran (\d+) tests?',(host/(name+'.stderr')).read_text());assert m;c['methods']=int(m[1])
 for i,r in enumerate(rows):
  current={ch:(folder/(str(i)+'.current.'+ch)).read_bytes() for ch in ['stdout','stderr']}
  if 'frozen_returncode' in r:
   assert r['returncode']==r['frozen_returncode'];assert r['equal']
   for ch in ['stdout','stderr']:assert current[ch]==(folder/(str(i)+'.frozen.'+ch)).read_bytes()
   c['complete_frozen_pairs']+=1;c['frozen_accept' if r['returncode']==0 else 'frozen_refuse']+=1;exercised.add(r['source'])
  if name=='prepare' and r['source']=='smidr/tools/soc_prepare.mojo' and r['returncode']:
   assert i+1<len(rows);n=rows[i+1];assert n['source']==r['source'] and n['returncode']==0 and n['arguments'][1:]==['prepare','3','0','65536','2068','196608','70'];c['individual_refusal_to_fresh_success_joins']+=1
  if r['source'] in new_sources:
   assert r['traced'];t=(folder/(str(i)+'.strace')).read_text();assert t.count('execve(')==1;c['new_consumer_traces']+=1
   assert all(re.match(r'^\d+ ',line) for line in t.splitlines()),(name,i,'unclassified trace line')
   calls=joined(t);assert all(re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x') for pid,b in calls),(name,i,'opaque call')
   assert any(b.startswith('exit_group('+str(r['returncode'])+')') for pid,b in calls)
   for bad in ['/dev/h1x-','/dev/hailo','ioctl(','connect(','memfd_create(','libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime']:assert bad not in t.lower(),(name,i,bad)
   live={}
   for pid,b in calls:
    assert '???' not in b
    m=re.match(r'openat\(.*\)\s+= (\d+)<',b)
    if m:
     fd=int(m[1]);assert fd not in live,(name,i,b,live);live[fd]=(pid,b);c['observed_fd_generations']+=1
    assert 'F_DUPFD' not in b
    m=re.match(r'close\((\d+).*\)\s+= 0$',b)
    if m:
     fd=int(m[1]);assert fd in live,(name,i,b);del live[fd];c['actual_observed_closes']+=1
   assert not live,(name,i,live)
 summary[name]=dict(c);total.update(c)
assert exercised>={'smidr/tools/soc_group.mojo','tests/hailo_soc_group_ownership.mojo','smidr/tools/soc_abi.mojo','prepare-oracle','group-oracle','abi-oracle'}
for root in [base,final]:
 for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
  for p,d in json.loads((root/name).read_text()).items():assert h(root/folder/p)==h(Path(p))==d
for r in json.loads((base/'controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
m=Path('docs/evidence/soc-prepare-contract-2026-10-24/archive-identities.json');assert h(m)=='e23ddde53977dbf23a0208857457d5ffdf49c026d360cdab02b26af398f1dcac'
for r in json.loads(m.read_text()):p=Path(r['path']);assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
assert h(Path('/home/pi/mojo-dev/.pixi/envs/default/bin/mojo'))=='be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39'
mods={str(p.with_suffix('')).replace('/','.'):p for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};edges={m:set(re.findall(r'^from ([\w.]+) import',p.read_text(),re.M))&mods.keys() for m,p in mods.items()}
def reaches(m,seen=None):
 seen=set() if seen is None else seen
 if m in seen:return False
 seen.add(m);return m=='hailbru.soc_prepare' or any(reaches(n,seen) for n in edges[m])
closure=sorted(str(p) for m,p in mods.items() if re.search(r'^def main\(',p.read_text(),re.M) and reaches(m));assert closure==['smidr/tools/soc_prepare.mojo','tests/hailo_soc_prepare_api.mojo']
rows=json.loads((final/'build-results.json').read_text())+json.loads((final/'c-build-results.json').read_text())
for i,r in enumerate(rows):
 binary=Path(r['binary']);assert h(binary)==r['sha256']
 for arg,label in [('-d','dynamic'),('-Ws','symbols')]:
  x=subprocess.run(['readelf',arg,str(binary)],capture_output=True);assert x.returncode==0 and not x.stderr;(out/f'elf-{i}-{label}.txt').write_bytes(x.stdout)
  assert not any(b in x.stdout.lower() for b in [b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'])
summary['total']=dict(total);summary['scope']=dict(old_mojo=705,old_python=86,final_mojo=708,final_python=87,controls=156,contract_paths=868,old_edits=0,affected_consumer_closure=closure,mojo_links=5,cxx_links=3,elf_tables=16,new_statement_warnings=0,physical_calls=False,descriptor_count_inferred=False,source_model_execution=False)
(out/'census.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
