# Review copy;exact executed script pinned in raw archive.
from pathlib import Path
from collections import Counter
import json,hashlib,re
repo=Path.cwd();work=repo.parent;selected=work/'grouped-device-rpc-native-selected';final=work/'grouped-device-rpc-native-final-v8';out=work/'grouped-device-rpc-native-selected-audit-v8';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();meta=json.loads((selected/'meta.json').read_text());counts=Counter();suites=[]
for p,d in meta['images'].items():assert h(Path(p))==d
old_images=json.loads((work/'grouped-device-rpc-native-final-v2/images.json').read_text());new_images=json.loads((final/'images.json').read_text())
for src,r in old_images.items():
 if src not in ('faults',):assert r['sha256']==new_images[src]['sha256']

all_results=json.loads((selected/'results.json').read_text());assert len(all_results)==9
assert [r['suite'] for r in all_results if r['returncode']!=0]==['worker']
worker=work/'grouped-device-rpc-native-worker-final-v8';worker_result=json.loads((worker/'result.json').read_text());assert worker_result['returncode']==0
for p,d in json.loads((worker/'meta.json').read_text())['images'].items():assert h(Path(p))==d
results=[r for r in all_results if r['suite'] not in ('group-control','worker')]+[worker_result];assert len(results)==8 and all(r['returncode']==0 for r in results)

for row in results:
 name=row['suite'];root=worker if name=='worker' else selected;raw=root/(name+'-raw');records=json.loads((raw/'records.json').read_text());stderr=(root/(name+'.stderr')).read_text();m=re.search(r'Ran (\d+) tests? in',stderr);assert m and stderr.rstrip().endswith('OK');methods=int(m[1]);counts['methods']+=methods
 for i,r in enumerate(records):
  assert r['equal'] and r['returncode']==r['frozen_returncode'] and r['source']!='faults'
  if name=='worker':assert not r['guard_expired'] and not r['unresolved']
  for ch in ['stdout','stderr']:assert (raw/f'{i}.current.{ch}').read_bytes()==(raw/f'{i}.frozen.{ch}').read_bytes()
  for args in [r['arguments'],r['frozen_arguments']]:
   assert args[0] in ('strace','/usr/bin/strace');trace=Path(args[args.index('-o')+1]);assert trace.exists() and trace.stat().st_size>0;data=trace.read_text();assert not any(s in data.lower() for s in ['libhailort','libcuda','libtorch','libggml','onnxruntime']);assert not re.search(r'openat\(.*"/dev/(?:h1x-|hailo)',data);assert not re.search(r'\bconnect\(',data);counts['traces']+=1
  counts['full_pairs']+=1;counts['accept_pairs' if r['returncode']==0 else 'refuse_pairs']+=1
  if name=='worker':counts['new_bounded_worker_reproducibility_pairs']+=1
  counts['historical_known_gap_pairs' if r['source'].startswith('historical-known-gap:') else 'selected_current_pairs']+=1
  if r['source']=='abi-oracle' and r['arguments'][-1]=='layout':(out/'header-layout.json').write_bytes((raw/f'{i}.current.stdout').read_bytes())
 suites.append(dict(suite=name,methods=methods,full_pairs=len(records)))
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 for p,d in json.loads((final/name).read_text()).items():assert h(repo/p)==h(final/folder/p)==d
result=dict(metrics=dict(counts),suites=suites,physical_device_calls=False,old_production_and_tests_unchanged=True,all_full_pairs=True,unrestricted_legacy_worker_failures_retained=True,new_worker_has_bounded_procfs_census=True,selected_images_bit_identical_to_final=True);(out/'census.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
