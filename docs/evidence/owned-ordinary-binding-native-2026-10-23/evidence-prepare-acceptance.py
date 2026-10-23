from pathlib import Path
import hashlib,json
final=Path('../owned-ordinary-binding-native-final-v3').resolve();out=Path('../owned-ordinary-binding-native-acceptance').resolve();out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cur={r['source']:r['binary'] for r in json.load(open(final/'build-results.json'))};primary=json.load(open('../owned-ordinary-binding-native-baseline/controls.json'));frozen={r['source']:r['binary'] for r in primary}
assert len(primary)==122
pairs={v:frozen[k] for k,v in cur.items() if k in frozen};assert len(pairs)==24
historical=[]
for p in ['../sealed-metadata-native-baseline/controls.json','../sealed-collection-native-final-v2/build-results.json']:
 historical+=json.load(open(p))
oldmap={r['binary']:cur[r['source']] for r in historical+primary if r['source'] in cur};oldmap['../source-root-api']=cur['tests/hailo_source_root_api.mojo']
jobs=json.load(open('../sealed-collection-native-acceptance-v3/jobs.json'))
for j in json.load(open('../sealed-safetensors-native-acceptance-v2/jobs.json')):
 if j['suite'] in ('decoder_layers','decoder_architecture','decoder_projections','ordinary_projection_schema','owned-compiler'):jobs.append(j)
for j in jobs:
 j['args']=[oldmap.get(v,v) for v in j['args']]
 j['args'][j['args'].index('--evidence')+1]=str(out/j['suite'])
 for flag,source in [('--frozen','smidr/tools/decoder_projections.mojo'),('--baseline','smidr/tools/shard_collection.mojo')]:
  if flag in j['args']:j['args'][j['args'].index(flag)+1]=frozen[source]
 if j['suite'] in ('shard_collection','unindexed_source'):
  j['args'][j['args'].index('--faults')+1]=str(final/'safetensors_fd_io_faults.so')
 for i,v in enumerate(j['args']):
  if v.endswith('.so') and (final/Path(v).name).is_file():j['args'][i]=str(final/Path(v).name)
jobs.append(dict(suite='owned-binding',python='/usr/bin/python3',script='tests/test_hailo_owned_ordinary_binding.py',args=['--binary',cur['smidr/tools/owned_ordinary_binding.mojo'],'--api',cur['tests/hailo_owned_ordinary_binding_api.mojo'],'--schema',cur['smidr/tools/ordinary_projection_schema.mojo'],'--faults',str(final/'ordinary_binding_faults.so'),'--strace','/usr/bin/strace','--evidence',str(out/'owned-binding')]))
# Pin every binary and actual supporting source used by the jobs. Intentional
# older auxiliary versions remain explicit, never routed as selected controls.
aux=[]
known={str(Path(r['binary']).resolve()):r['source'] for r in primary+historical}
# Explicit comparison baselines use the current pre-code frozen source snapshot.
for j in jobs:
 for i,flag in enumerate(j['args']):
  if flag.startswith('--') and flag not in ('--evidence','--strace'):
   p=Path(j['args'][i+1])
   if p.is_file():
    magic=p.read_bytes()[:4];row=dict(path=str(p.resolve()),sha256=h(p),bytes=p.stat().st_size,elf=magic==b'\x7fELF')
    if row['elf']:
     row['source']=known.get(str(p.resolve()),next((k for k,v in cur.items() if v==str(p.resolve())),None))
     if p.suffix=='.so':row['source']='tests/'+p.stem+'.c' if (Path('tests')/(p.stem+'.c')).is_file() else 'historical qualified test seam'
     assert row['source'],row
     if Path(row['source']).is_file():row['supporting_current_source_sha256']=h(Path(row['source']))
     if row['elf'] and row['source'].endswith('.mojo'):
      source_copy=Path('../owned-ordinary-binding-native-baseline/source-snapshot')/row['source']
      if source_copy.exists():row.update(supporting_source_snapshot=str(source_copy.resolve()),supporting_source_snapshot_sha256=h(source_copy))
    aux.append(row)
(out/'auxiliary-identities.json').write_text(json.dumps(aux,indent=2)+'\n')
(out/'universe.json').write_text(json.dumps(dict(current=cur,frozen=frozen,pairs=pairs),indent=2)+'\n')
(out/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
s=Path('../sealed-collection-native-acceptance-v3/pair-all.py').read_text();(out/'pair-all.py').write_text(s)
print(len(cur),len(pairs),len(jobs),len(aux))
