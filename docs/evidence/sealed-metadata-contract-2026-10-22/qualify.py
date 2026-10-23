from pathlib import Path
import hashlib,json,shutil,subprocess
out=Path('../sealed-metadata-contract-study');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=json.load(open('../sealed-safetensors-native-final/source-hashes.json'))
for name,digest in sources.items():assert h(Path(name))==h(Path('../sealed-safetensors-native-final/source-snapshot')/name)==digest,name
u=json.load(open('../sealed-safetensors-native-acceptance-v2/universe.json'));builds=json.load(open('../sealed-safetensors-native-final/build-results.json'))+[r for r in json.load(open('../sealed-safetensors-native-supplement/build-results-reviewed.json')) if r['kind']=='current'];assert len(builds)==len(u['current'])==117
for row in builds:assert h(Path(row['binary']))==row['sha256'],row
inputs=json.load(open('../sealed-safetensors-native-acceptance-v2/input-hashes.json'))
for name,digest in inputs.items():
 assert h(Path(name))==h(Path('../sealed-safetensors-native-acceptance-v2/test-snapshot')/name)==digest,name
 p=out/'test-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(name,p)
for name,value in [('source-hashes.json',sources),('controls.json',builds),('test-input-hashes.json',inputs)]:
 (out/name).write_text(json.dumps(value,indent=2)+'\n')
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
qualification=dict(parent=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),tree=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],text=True).strip(),sources_verified=len(sources),native_controls_verified=len(builds),python_inputs_verified=len(inputs),actual_prior_source_snapshots_verified=True,planned_old_production_changes=[],planned_new_leaf='smidr/sealed_source_metadata.mojo',production_started=False,probe_executed=False)
(out/'qualification-start.json').write_text(json.dumps(qualification,indent=2)+'\n');print(json.dumps(qualification,indent=2))
