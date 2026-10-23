from pathlib import Path
import hashlib,json
base=Path('../owned-ordinary-binding-native-baseline');final=Path('../owned-ordinary-binding-native-final-v3');accept=Path('../owned-ordinary-binding-native-acceptance-v3');out=Path('../owned-ordinary-binding-native-recording');out.mkdir(exist_ok=True)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for r in json.load(open(accept/'auxiliary-identities.json')):
 p=Path(r['path']);assert h(p)==r['sha256']
 row=r.copy()
 if r.get('elf'):
  src=Path(r['source']);assert src.is_file(),r
  snapshot=(base if (base/'source-snapshot'/src).exists() else final)/'source-snapshot'/src
  if src.suffix=='.c':
   snapshot=out/'c-source-snapshot'/src;snapshot.parent.mkdir(parents=True,exist_ok=True);snapshot.write_bytes(src.read_bytes())
   build=next(b for b in json.load(open(final/'c-build-results.json')) if b['source']==str(src));assert h(p)==build['binary_sha256'] and h(src)==build['source_sha256']
  assert snapshot.is_file() and h(snapshot)==h(src),(src,snapshot)
  row.update(actual_supporting_source=str(src),actual_supporting_source_sha256=h(src),actual_supporting_source_copy=str(snapshot.resolve()),actual_supporting_source_copy_sha256=h(snapshot))
 rows.append(row)
(out/'supporting-input-identities.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),'actual auxiliary inputs/source copies verified')
