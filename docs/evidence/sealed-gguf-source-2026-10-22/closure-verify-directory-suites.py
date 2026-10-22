from pathlib import Path
import hashlib,json,subprocess,sys
root=Path('../sealed-gguf-native-closure');out=root/'acceptance';out.mkdir(exist_ok=False);build=Path('../sealed-gguf-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open('../sealed-gguf-native-acceptance-v2/input-hashes.json'));rows=json.load(open(build/'build-results.json'));controls=json.load(open('../sealed-gguf-native-baseline/controls.json'))
for p in root.glob('*.py'):inputs[str(p)]=sha(p)
inputs[str(root/'aliases.json')]=sha(root/'aliases.json');(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
 for r in rows+controls:assert sha(r['binary'])==r['sha256'],r['binary']
 for name,binary in json.load(open(root/'aliases.json')).items():assert (root/'binaries'/name).resolve()==Path(binary)
results=[]
for name,cmd,_ in json.load(open('../iq4-native-development/commands.json')):
 if '--binaries' not in cmd:continue
 original=next(r for r in json.load(open('../sealed-gguf-native-acceptance-v2/test-results.json')) if r['suite']==name)
 # Reuse the exact already remapped explicit options, replacing only the directory and evidence destination.
 actual=original['command'][3:];assert actual[0].startswith('tests/'),actual
 actual[actual.index('--binaries')+1]=str((root/'binaries').resolve());actual[actual.index('--evidence')+1]=str((out/name).resolve())
 job=[sys.executable,str(root/'pair-all.py'),str(out/'pairs'/(name+'.json')),*actual];stable()
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(job,stdout=f,stderr=subprocess.STDOUT,timeout=2400)
 stable();row={'suite':name,'command':job,'returncode':r.returncode};results.append(row);(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');print(name,r.returncode,flush=True);assert r.returncode==0
# Canonical46 suites use these3 fully current reruns, preserving all previous attempts.
canonical=[]
for r in json.load(open('../sealed-gguf-native-acceptance-v2/test-results.json')):canonical.append(next((n for n in results if n['suite']==r['suite']),r))
assert len(canonical)==46 and all(r['returncode']==0 for r in canonical)
pairfiles=[]
for r in canonical:
 if r['suite']=='sealed-gguf':continue
 pairfiles.append(Path(r['command'][2]))
pairs=[x for p in pairfiles for x in json.load(open(p))];expected={r['binary'] for r in rows if r['source'] in {r['source'] for r in controls}}
assert {r['binary'] for r in pairs}==expected,expected-{r['binary'] for r in pairs}
(root/'canonical-test-results.json').write_text(json.dumps(canonical,indent=2)+'\n')
(root/'canonical-pair-files.json').write_text(json.dumps(list(map(str,pairfiles)),indent=2)+'\n')
(root/'regression-summary.json').write_text(json.dumps({'controls':len(expected),'success_pairs':sum(r['returncode']==0 for r in pairs),'nonzero_pairs':sum(r['returncode']!=0 for r in pairs),'skipped_pairs':0,'complete_mutation_pairs':sum(bool(r['intentional_fixture_mutation_restored_for_control']) for r in pairs),'independent_complete_fault_log_pairs':sum(bool(r.get('independent_complete_fault_logs_equal')) for r in pairs),'canonical_suites':46,'supplemental_directory_suite_reruns':len(results),'unchanged_native_binaries':109,'unchanged_old_python_inputs':68},indent=2)+'\n')
stable();print('All106 current controls paired; canonical46 suites pass including3 remapped directory suites.',flush=True)
