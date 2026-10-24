from pathlib import Path
from collections import Counter,defaultdict
import hashlib,json,math,re,struct,subprocess
repo=Path.cwd();base=repo.parent/'tied-output-native-baseline';final=repo.parent/'tied-output-native-final';extra=repo.parent/'tied-output-native-compatibility';host=repo.parent/'tied-output-native-host-v4';prior=repo.parent/'tied-output-native-host-v3';legacy=repo.parent/'tied-output-native-host';out=repo.parent/'tied-output-native-audit-v4';out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
s=(repo.parent/'program-pin-native-development/audit-host.py').read_text();exec(s[s.index('def joined('):s.index('results=json.loads')])
first_results=json.loads((legacy/'results.json').read_text());assert len(first_results)==56 and {r['suite'] for r in first_results if r['returncode']}=={'tied-output','identity'}
results=json.loads((host/'results.json').read_text())+[r for r in json.loads((prior/'results.json').read_text()) if r['suite']=='identity']+[r for r in first_results if r['suite'] not in ('tied-output','identity')];assert len(results)==56 and all(r['returncode']==0 for r in results)
summary={};total=Counter();exercised=set()
for row in results:
 name=row['suite'];scope=host if name=='tied-output' else prior if name=='identity' else legacy;pairs=json.loads((scope/(name+'-pairs.json')).read_text());calls=json.loads((scope/(name+'-pairs-native-calls.json')).read_text());outputs=json.loads((scope/(name+'-pairs-full-outputs.json')).read_text());methods=int(re.search(r'Ran (\d+) tests?',(scope/(name+'.stderr')).read_text())[1]);count=Counter(methods=methods,primary=len(calls),frozen_pairs=len(pairs))
 for p in pairs:assert p['complete_stdout_equal'] and p['complete_stderr_equal'];count['frozen_accept' if p['returncode']==0 else 'frozen_refuse']+=1
 for c in calls:exercised.add(c['source'])
 assert len(outputs)==len(calls)+len(pairs),(name,len(outputs),len(calls),len(pairs))
 for r in outputs:
  for field in ('stdout','stderr'):p=Path(r[field]['path']);assert p.stat().st_size==r[field]['bytes'] and h(p)==r[field]['sha256']
 summary[name]=dict(count);total.update(count)
closure=json.loads((final/'consumer-closure.json').read_text());assert set(closure['qualified_affected'])<=exercised,sorted(set(closure['qualified_affected'])-exercised)
rows=json.loads((host/'tied-output/runs.json').read_text());fixtures=json.loads((host/'tied-output/fixtures.json').read_text());byroot={f['root']:f for f in fixtures};bycalls=defaultdict(list);new_counts=Counter()
newbins=[r['binary'] for r in json.loads((final/'build-results.json').read_text())[:2]]
for i,r in enumerate(rows):
 args=r['arguments'];bi=next((k for k,v in enumerate(args) if v in newbins),None)
 if bi is None:continue
 api=args[bi]==newbins[1];mode=args[bi+2] if api else 'tool';root=args[bi+(3 if api else 2)];bycalls[root].append(i)
 if r['returncode']:
  if mode=='replace_sealed':assert 'OwnedTiedOutput: present tied output source bytes differ' in r['stderr'];new_counts['actual_replaced_owner_byte_refusals']+=1
  continue
 f=byroot[root];files={k:bytes.fromhex(v) for k,v in f['files'].items()};lines=r['stdout'].splitlines();obj=json.loads(lines[0]);obs=json.loads(lines[1]);g=obj['lowered'];sg=g['source_graph'];exp=g['expanded'];bindings=f['bindings'];source_bytes=0
 for side,name in [('left','token_embd.weight'),('right','output.weight')]:
  b=bindings[name];data=files[Path(b['source_path']).name];n=struct.unpack_from('<Q',data)[0];header=json.loads(data[8:8+n]);t=header[b['original_name']];lo,hi=t['data_offsets'];shape=t['shape'];elements=math.prod(shape);expected={k:b[k] for k in ('source_format','source_kind','original_name','source_path','source_shape','axis_order','elements','file_offset','byte_count')};assert obs[side]==expected
  assert b['file_offset']==8+n+lo and b['byte_count']==hi-lo and b['elements']==elements and b['source_shape']==shape
  payload=data[b['file_offset']:b['file_offset']+b['byte_count']];assert len(payload)==b['byte_count'];source_bytes+=len(payload)
  if side=='left':left=payload
  else:assert payload==left
 assert obs['all_elements_equal'] and obs['differing_elements']==0 and obs['first_differing_element']==-1 and obs['raw_elements_read']==2*bindings['output.weight']['elements'] and obs['bytes_per_operand']==len(left)
 chunk=int(args[-5] if api else args[-1]);assert obs['chunks']==math.ceil(bindings['output.weight']['elements']/chunk)
 for k in ('graph_alias_resolved','compiled_artifact_identity_verified','execution_tested','device_access'):assert obs[k] is False
 assert set(sg['weights'])==set(bindings)-{'output.weight'};assert set(exp['weights'])==set(bindings);assert sg['weight_bytes']==sum(b['byte_count'] for b in bindings.values())
 for name,b in bindings.items():
  weight=exp['weights'][name];value=exp['values'][weight['value']];assert {k:v for k,v in weight.items() if k!='value'}=={k:b[k] for k in ('file_offset','columns','rows','source_kind','byte_count')}
  shape=[b['columns']] if b['rows']==1 and len(b['source_shape'])==1 else [b['rows'],b['columns']]
  assert value['shape']==shape and value['elements']==b['elements'] and value['producer']==-1 and value['source_tensor']==-1 and value['domain']=='real' and value['storage']=='source_weight' and value['source_weight']==name and value['name']==name and value['alias_of']==-1 and value['last_use']==len(exp['operations'])
 alias=exp['weights']['output.weight']['value'];assert alias==len(exp['values'])-1 and alias!=exp['weights']['token_embd.weight']['value']
 for recipe in g['recipes']['recipes']:
  name=recipe['weight_name']
  if name:assert recipe['weight']=={k:bindings[name][k] for k in ('file_offset','columns','rows','source_kind','byte_count')};new_counts['independent_recipe_source_locations']+=1
 for owner,vkey,opkey in [(sg,'tensors','operations'),(exp,'values','operations')]:
  for k,v in enumerate(owner[vkey]):assert v['id']==k and v['elements']==math.prod(v['shape'])
  for k,op in enumerate(owner[opkey]):
   assert op['id']==k and owner[vkey][op['output']]['producer']==k
   for input in op['inputs']:assert 0<=input<len(owner[vkey]) and owner[vkey][input]['last_use']>=k
 if len(lines)==4:
  views=json.loads(lines[2]);names=[op['weight'] for op in sg['operations'] if op['weight']]
  if mode=='all':assert [v['canonical'] for v in views]==names;new_counts['all_static_operation_windows']+=len(views)
  else:assert views==[]
 new_counts['independent_complete_raw_source_bytes']+=source_bytes;new_counts['accepted_full_graphs']+=1
for root,indices in bycalls.items():
 f=byroot[root];n=f['bindings'].get('output.weight',{}).get('byte_count',-1)
 if len(indices)==n+1 and all(rows[i]['returncode'] for i in indices[:-1]):
  assert all(rows[i]['returncode'] and 'OwnedTiedOutput: present tied output source bytes differ' in rows[i]['stderr'] for i in indices[:-1]);assert rows[indices[-1]]['returncode']==0;new_counts['individual_payload_byte_refusals']+=n
assert new_counts['individual_payload_byte_refusals']==1280 and new_counts['actual_replaced_owner_byte_refusals']==4,new_counts
trace_counts=Counter();opaque=[];lifetime=[]
for i,r in enumerate(rows):
 if not r['trace']:continue
 text=Path(r['trace']).read_text();assert text.count('execve(')==1
 for bad in ('/dev/h1x-','/dev/hailo','connect(','ioctl(','libhailort','libcuda','libtorch','libggml','libxxhash','libprotobuf','onnxruntime'):assert bad not in text,(i,bad)
 calls=joined(text);assert any(b.startswith('exit_group('+str(r['returncode'])+')') for pid,b in calls)
 live={};original={};maps={};capacity={};generations=Counter();events=[];allfds={}
 for pos,(pid,b) in enumerate(calls):
  if '???' in b:opaque.append(dict(trace=i,pid=pid,record=b))
  if b.startswith(('clone(','clone3(')) and re.search(r'= \d+$',b):assert 'CLONE_FILES' in b,(i,b)
  m=re.match(r'openat\(.*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in allfds;generations[fd]+=1;allfds[fd]=(pid,generations[fd]);events.append(dict(position=pos,pid=pid,fd=fd,generation=generations[fd],event='other_open',record=b));trace_counts['other_open_fds']+=1
  m=re.match(r'openat2\([^,]+, "([^"]+)".*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[2]);assert fd not in allfds;generations[fd]+=1;allfds[fd]=(pid,generations[fd]);original[fd]=(pid,generations[fd],m[1]);events.append(dict(position=pos,pid=pid,fd=fd,generation=generations[fd],event='original_open',label=m[1]));trace_counts['original_fds']+=1
  m=re.match(r'memfd_create\("aesir-source-copy".*\)\s+= (\d+)<',b)
  if m:
   fd=int(m[1]);assert fd not in allfds;generations[fd]+=1;live[fd]=(pid,generations[fd]);allfds[fd]=(pid,generations[fd]);events.append(dict(position=pos,pid=pid,fd=fd,generation=generations[fd],event='sealed_open'));trace_counts['memfds']+=1
  m=re.match(r'ftruncate\((\d+)<[^>]*memfd:[^>]*>\(deleted\), (\d+)\)\s+= 0$',b)
  if m:capacity[int(m[1])]=int(m[2])
  m=re.match(r'statx\((\d+)<[^>]*memfd:[^>]*>\(deleted\), .*stx_size=(\d+),',b)
  if m:capacity[int(m[1])]=int(m[2])
  m=re.match(r'mmap\(NULL, (\d+), ([^,]+), ([^,]+), (\d+)<[^>]*memfd:[^>]*>\(deleted\), 0\)\s+= (0x[0-9a-f]+)$',b)
  if m:
   size,prot,flags,fd,address=int(m[1]),m[2],m[3],int(m[4]),m[5];assert fd in live and not original and prot=='PROT_READ' and flags=='MAP_SHARED' and capacity[fd]==size and address not in maps;maps[address]=(fd,live[fd][1],size);events.append(dict(position=pos,pid=pid,fd=fd,generation=live[fd][1],event='map',address=address,bytes=size));trace_counts['sealed_readonly_maps']+=1
  m=re.match(r'munmap\((0x[0-9a-f]+), (\d+)\)\s+= 0$',b)
  if m and m[1] in maps:
   fd,gen,size=maps.pop(m[1]);assert fd in live and live[fd][1]==gen and size==int(m[2]);events.append(dict(position=pos,pid=pid,fd=fd,generation=gen,event='unmap',address=m[1],bytes=size));trace_counts['sealed_unmaps']+=1
  m=re.match(r'close\((\d+)<.*\)\s+= 0$',b)
  if m:
   fd=int(m[1])
   if fd in allfds:
    _,gen=allfds.pop(fd);events.append(dict(position=pos,pid=pid,fd=fd,generation=gen,event='actual_close'));trace_counts['all_observed_closes']+=1
   if fd in original:_,gen,label=original.pop(fd);events.append(dict(position=pos,pid=pid,fd=fd,generation=gen,event='original_close',label=label));trace_counts['original_closes']+=1
   if fd in live:
    assert not any(v[0]==fd for v in maps.values());_,gen=live.pop(fd);capacity.pop(fd,None);events.append(dict(position=pos,pid=pid,fd=fd,generation=gen,event='sealed_close'));trace_counts['memfd_closes']+=1
  if 'memfd:aesir-' in b:
   trace_counts['sealed_digest_reads']+=b.startswith('pread64(');trace_counts['successful_add_seals']+=bool('F_ADD_SEALS' in b and b.endswith('= 0'));trace_counts['actual_seal_checks']+=bool('F_GET_SEALS' in b and '= 0xf ' in b)
 assert not live and not original and not maps and not allfds,(i,live,original,maps,allfds);trace_counts['new_traces']+=1;lifetime.append(dict(call=i,events=events))
(out/'new-lifetime-joins.json').write_text(json.dumps(lifetime,indent=2)+'\n');(out/'new-census.json').write_text(json.dumps(dict(counts=dict(new_counts),trace_counts=dict(trace_counts),opaque=opaque),indent=2)+'\n')
summary['total']=dict(total);summary['new']=dict(new_counts);summary['new_traces']=dict(trace_counts);summary['opaque_trace_records']=opaque;(out/'census-partial.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
