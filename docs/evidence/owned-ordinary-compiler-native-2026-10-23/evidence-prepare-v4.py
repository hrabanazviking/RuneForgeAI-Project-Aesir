from pathlib import Path
import hashlib,json
final=Path('../owned-ordinary-compiler-native-final-v2').resolve();out=Path('../owned-ordinary-compiler-native-acceptance-v4').resolve();out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cur={r['source']:r['binary'] for r in json.load(open(final/'build-results.json'))};controls=json.load(open('../owned-ordinary-compiler-native-baseline/controls.json'));frozen={r['source']:r['binary'] for r in controls};assert len(cur)==30
old=json.load(open('../owned-ordinary-binding-native-acceptance-v3/universe.json'))
route={v:cur[k] for k,v in old['current'].items() if k in cur}
jobs=json.load(open('../owned-ordinary-binding-native-acceptance-v3/jobs.json'))
for j in jobs:
 j['args']=[route.get(v,v) for v in j['args']];j['args'][j['args'].index('--evidence')+1]=str(out/j['suite'])
 for i,v in enumerate(j['args']):
  if v.endswith('.so') and (final/Path(v).name).is_file():j['args'][i]=str(final/Path(v).name)
args=[]
for key,value in [('binary',cur['smidr/tools/owned_ordinary_compiler.mojo']),('api',cur['tests/hailo_owned_ordinary_compiler_api.mojo']),('graph',cur['smidr/tools/decoder_scaling_graph.mojo']),('graph-api',cur['tests/hailo_decoder_scaling_api.mojo']),('schema',cur['smidr/tools/ordinary_projection_schema.mojo']),('faults',str(final/'ordinary_binding_faults.so')),('strace','/usr/bin/strace'),('mutations',str(Path('../owned-ordinary-compiler-native-development/mutations.json').resolve())),('evidence',str(out/'owned-ordinary-compiler'))]:args.extend(['--'+key,value])
jobs.insert(0,dict(suite='owned-ordinary-compiler',python='/usr/bin/python3',script='tests/test_hailo_owned_ordinary_compiler.py',args=args))
pairs={v:frozen[k] for k,v in cur.items() if k in frozen};assert len(pairs)==28
(out/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n');(out/'universe.json').write_text(json.dumps(dict(current=cur,frozen=frozen,pairs=pairs),indent=2)+'\n')
s=Path('../owned-ordinary-binding-native-acceptance-v3/pair-all.py').read_text().replace("('tests/hailo_sealed_collection_api.mojo','smidr/tools/sealed_source_collection.mojo')", "('tests/hailo_sealed_collection_api.mojo','smidr/tools/sealed_source_collection.mojo','tests/hailo_owned_ordinary_binding_api.mojo','smidr/tools/owned_ordinary_binding.mojo')");(out/'pair-all.py').write_text(s)
# Every explicitly invoked auxiliary binary retains its actual source identity.
prior=json.load(open('../owned-ordinary-binding-native-acceptance-v3/auxiliary-identities.json'))
known={r['path']:r['source'] for r in prior if r.get('elf')}
known.update({r['binary']:r['source'] for r in controls});known.update({v:k for k,v in cur.items()});known.update({r['binary']:r['source'] for r in json.load(open(final/'c-build-results.json'))})
aux=[]
for j in jobs:
 for i,v in enumerate(j['args']):
  if v.startswith('--') and v not in ('--evidence','--strace'):
   p=Path(j['args'][i+1])
   if not p.is_file():continue
   magic=p.read_bytes()[:4];row=dict(path=str(p.resolve()),sha256=h(p),bytes=p.stat().st_size,elf=magic==b'\x7fELF')
   if row['elf']:
    src=Path(known[str(p.resolve())]);row.update(source=str(src),supporting_current_source_sha256=h(src))
    copy=final/'supporting-source-snapshot'/src;copy.parent.mkdir(parents=True,exist_ok=True);copy.write_bytes(src.read_bytes());row.update(actual_supporting_source_copy=str(copy),actual_supporting_source_copy_sha256=h(copy))
   aux.append(row)
(out/'auxiliary-identities.json').write_text(json.dumps(aux,indent=2)+'\n')
print(len(cur),len(pairs),len(jobs),len(aux))
