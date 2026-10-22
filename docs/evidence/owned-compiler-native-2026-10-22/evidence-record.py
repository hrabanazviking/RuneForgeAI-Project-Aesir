from pathlib import Path
import hashlib,json,re,shutil
root=Path('.');out=root/'docs/evidence/owned-compiler-native-2026-10-22';out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
# Retain raw local evidence exactly; published text projections replace only the
# task work prefix in path labels, never native oracle values/counts/digests.
prefix=str(root.resolve().parent)
def project(source,destination):
 s=Path(source).read_text();(out/destination).write_text(s.replace(prefix,'..'))
for src,dst in [('../owned-compiler-native-recording/summary.json','summary.json'),('../owned-compiler-native-recording/consumer-closure.json','consumer-closure.json'),('../owned-compiler-native-recording/trace-audit.json','trace-audit.json'),('../owned-compiler-native-recording/dependency-inspection.json','dependency-inspection.json'),('../owned-compiler-native-final/build-results.json','build-results.json'),('../owned-compiler-native-final/source-hashes.json','source-hashes.json'),('../owned-compiler-native-baseline/qualification.json','baseline-qualification.json'),('../owned-compiler-native-acceptance-v2/test-results.json','test-results.json')]:project(src,dst)
for name in ['owned','semantic','sealed']:
 project(f'../owned-compiler-native-acceptance-v2/{name}.txt',name+'-tests.txt')
 project(f'../owned-compiler-native-acceptance-v2/{name}-pairs.json',name+'-frozen-pairs.json')
project('../owned-compiler-native-acceptance/owned.txt','retained-initial-owned-tests.txt')
for i in range(4):
 p=Path(f'../owned-compiler-native-development/build-{i}.txt')
 if p.exists():project(p,'development-build-'+str(i)+'.txt')
for name in ['audit.py','census.py','record.py']:
 if (Path('../owned-compiler-native-recording')/name).exists():project('../owned-compiler-native-recording/'+name,'evidence-'+name)
for p in ['../owned-compiler-native-acceptance-v2/pair-all.py','../owned-compiler-native-acceptance-v2/run.py','../owned-compiler-native-development/build-final.py']:
 project(p,'evidence-'+Path(p).name)
# Re-verify every identity from historical snapshots without changing them.
prior=[]
for name in ['sealed-gguf-source-2026-10-22','sealed-source-copy-2026-10-21','source-byte-digest-2026-10-21','owned-compiler-contract-2026-10-22']:
 folder=root/'docs/evidence'/name
 if folder.exists():prior.extend(folder.glob('*archive*identit*.json'))
verified=[]
for manifest in prior:
 data=json.loads(manifest.read_text());assert isinstance(data,list),manifest
 count=0
 for item in data:
  path=Path(item['path']);assert h(path)==item['sha256'] and path.stat().st_size==item['bytes'],path;count+=1
 verified.append(dict(manifest=str(manifest),verified=count,sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(verified,indent=2)+'\n')
# Seal this slice's baseline, development, final and both acceptance attempts.
folders=['../owned-compiler-native-baseline','../owned-compiler-native-development','../owned-compiler-native-final','../owned-compiler-native-acceptance','../owned-compiler-native-reviewed','../owned-compiler-native-acceptance-v2']
identities=[]
for folder in folders:
 for p in sorted(Path(folder).rglob('*')):
  if p.is_file():identities.append(dict(path=str(p),bytes=p.stat().st_size,sha256=h(p)))
(out/'archive-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
qualification=dict(raw_native_attempts_retained=True,published_path_prefix_projection=prefix,archive_files=len(identities),old_production_sources_changed=0,current_native_sources=663,all_previous_660_sources_69_python_inputs_109_controls_unchanged=True,all_linking_finished_before_native_acceptance=True,whole_repository_or_hosted_ci_pass=False)
(out/'qualification.json').write_text(json.dumps(qualification,indent=2).replace(prefix,'task work root')+'\n')
print(json.dumps(dict(archive_files=len(identities),prior=verified),indent=2))
