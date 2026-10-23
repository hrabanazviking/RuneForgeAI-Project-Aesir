from pathlib import Path
import hashlib,json,shutil
out=Path('../sealed-root-contract-study');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};assert len(sources)==669
old=json.load(open('../sealed-metadata-native-final/source-hashes.json'));assert sources==old
inputs=json.load(open('../sealed-metadata-native-baseline/test-input-hashes.json'));inputs['tests/test_hailo_sealed_source_metadata.py']=h(Path('tests/test_hailo_sealed_source_metadata.py'));assert len(inputs)==72
controls={r['source']:r for r in json.load(open('../sealed-metadata-native-baseline/controls.json'))}
for r in json.load(open('../sealed-metadata-native-final/build-results.json')):controls[r['source']]=r
assert len(controls)==119
for r in controls.values():assert h(Path(r['binary']))==r['sha256'],r
for p,d in inputs.items():
 assert h(Path(p))==d,p
 q=out/'test-snapshot'/p;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
for name,data in [('source-hashes.json',sources),('test-input-hashes.json',inputs),('controls.json',list(controls.values()))]:(out/name).write_text(json.dumps(data,indent=2)+'\n')
(out/'qualification.json').write_text(json.dumps(dict(parent='6ff5ec606848597f93d0e79b06e4c55e03474702',sources=len(sources),python_inputs=len(inputs),native_controls=len(controls),old_sources_exact=True,production_started=False),indent=2)+'\n')
print(len(sources),len(inputs),len(controls))
