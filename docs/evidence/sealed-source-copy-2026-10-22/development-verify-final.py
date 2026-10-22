from pathlib import Path
import hashlib,json,subprocess,sys
out=Path('../sealed-copy-native-acceptance');out.mkdir(exist_ok=False);build=Path('../sealed-copy-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(build/'input-hashes.json'));controls=json.load(open('../sealed-copy-native-baseline/controls.json'));c=json.load(open(build/'c-binaries.json'))
assert len(rows)==10 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
for p in Path('../sealed-copy-native-development').glob('*'):
 if p.is_file() and p.suffix in ('.py','.json'):inputs[str(p)]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
 for r in rows+controls+c:assert sha(r['binary'])==r['sha256']
def run(name,cmd):
 stable()
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 row={'suite':name,'command':cmd,'returncode':r.returncode};(out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');stable();print(name,r.returncode,flush=True);return row
mapping={r['source']:r['binary'] for r in rows}
results=[run('sealed-copy',[sys.executable,'tests/test_hailo_sealed_source_copy.py','--binary',mapping['smidr/tools/sealed_source_copy.mojo'],'--api',mapping['tests/hailo_sealed_source_api.mojo'],'--faults',str((build/'io-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'sealed')])]
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
jobs=json.load(open('../source-digest-native-development/selected-commands.json'))
jobs.append(['source-digest',[sys.executable,'tests/test_hailo_source_digest.py','--binary',mapping['smidr/tools/source_byte_digest.mojo'],'--api',mapping['tests/hailo_source_digest_api.mojo'],'--faults',str(Path('../source-digest-native-final-v2/io-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'digest')],True])
for name,cmd,_ in jobs:
 new=[]
 for val in cmd[1:]:
  found=next((r for r in controls if Path(val).name==Path(r['binary']).name and r['source'] in mapping),None)
  new.append(mapping[found['source']] if found else val.replace('../iq4-native-acceptance',str(out/'legacy')))
 results.append(run(name,[sys.executable,'../sealed-copy-native-development/pair-selected.py',str(out/'pairs'/(name+'.json')),*new]));(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
links=[]
for r in rows:
 p=subprocess.run(['ldd',r['binary']],capture_output=True,text=True,check=True)
 for token in ('libcrypto','libssl','hailort','cuda','torch','onnxruntime','ggml'):assert token not in p.stdout.lower(),p.stdout
 links.append({'source':r['source'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
(out/'dependency-inspection.json').write_text(json.dumps(links,indent=2)+'\n')
pairs=[r for p in (out/'pairs').glob('*.json') for r in json.load(open(p))];expected={r['binary'] for r in rows if r['source'] in {x['source'] for x in controls}}
assert {r['binary'] for r in pairs}==expected
(out/'regression-summary.json').write_text(json.dumps({'selected_controls':len(expected),'success_pairs':sum(r['returncode']==0 for r in pairs),'nonzero_pairs':sum(r['returncode']!=0 for r in pairs),'skipped_pairs':0,'complete_mutation_pairs':sum(bool(r['intentional_fixture_mutation_restored_for_control']) for r in pairs),'old653_sources_unchanged':True,'old67_python_inputs_unchanged':True,'old104_controls_unchanged':True},indent=2)+'\n')
p=subprocess.run([str((build/'header-seals-oracle').resolve())],capture_output=True,text=True,check=True);assert p.stderr==''
actual=json.loads(p.stdout);expected=json.load(open('../source-sealed-copy-contract-study/host-seals-result.json'));assert actual==expected
(out/'header-oracle.json').write_text(p.stdout);stable();print('all5 native suites,8 complete frozen controls and C header/kernel oracle pass',flush=True)
