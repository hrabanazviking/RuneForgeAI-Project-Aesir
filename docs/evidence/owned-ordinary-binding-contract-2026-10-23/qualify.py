from pathlib import Path
import hashlib,json,shutil
out=Path('../owned-ordinary-binding-contract-study');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};assert len(sources)==672
assert sources==json.load(open('../sealed-collection-native-final-v2/source-hashes.json'))
inputs=json.load(open('../sealed-collection-native-final-v2/test-input-hashes.json'));assert len(inputs)==73
controls={r['source']:r for r in json.load(open('../sealed-collection-native-baseline/controls.json'))}
for r in json.load(open('../sealed-collection-native-final-v2/build-results.json')):controls[r['source']]=r
assert len(controls)==122
for r in controls.values():assert h(Path(r['binary']))==r['sha256'],r
for name,d in inputs.items():
 assert h(Path(name))==d,name;q=out/'test-snapshot'/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(name,q)
for name,obj in [('source-hashes.json',sources),('test-input-hashes.json',inputs),('controls.json',list(controls.values()))]:(out/name).write_text(json.dumps(obj,indent=2)+'\n')
(out/'qualification.json').write_text(json.dumps(dict(parent='b61c0bc7e036c8dd4e936f4b02c20e9fa79d027e',source_identities=len(sources),python_inputs=len(inputs),native_controls=len(controls),production_started=False,old_sources_exact=True,probe_executed=False),indent=2)+'\n')
print(len(sources),len(inputs),len(controls))
