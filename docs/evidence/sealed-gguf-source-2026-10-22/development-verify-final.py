from pathlib import Path
import hashlib,json,subprocess,sys
out=Path('../sealed-gguf-native-acceptance');out.mkdir(exist_ok=False);build=Path('../sealed-gguf-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));controls=json.load(open('../sealed-gguf-native-baseline/controls.json'));inputs=json.load(open('../sealed-gguf-native-baseline/test-input-hashes.json'))
assert len(rows)==109 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
for p in ('tests/test_hailo_sealed_gguf_source.py','tests/sealed_gguf_faults.c','tests/source_sealed_copy_faults.c'):inputs[p]=sha(p)
for p in Path('../sealed-gguf-native-development').glob('*'):
 if p.is_file() and p.suffix in ('.py','.json') and p.name not in ('continuation-status.json','additional-audits-status.json'):inputs[str(p)]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
cs=[{'binary':str((build/n).resolve()),'sha256':sha(build/n)} for n in ('parser-faults.so','copy-faults.so')];(out/'c-binaries.json').write_text(json.dumps(cs,indent=2)+'\n')
def stable():
 for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
 for r in rows+controls+cs:assert sha(r['binary'])==r['sha256'],r['binary']
def run(name,cmd):
 stable()
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=2400)
 row={'suite':name,'command':cmd,'returncode':r.returncode};(out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');stable();print(name,r.returncode,flush=True);return row
mapping={r['source']:r['binary'] for r in rows}
results=[run('sealed-gguf',[sys.executable,'tests/test_hailo_sealed_gguf_source.py','--binary',mapping['smidr/tools/sealed_gguf_source.mojo'],'--api',mapping['tests/hailo_sealed_gguf_api.mojo'],'--semantic-api',mapping['tests/hailo_sealed_semantic_api.mojo'],'--semantic-control',next(r['binary'] for r in controls if r['source']=='smidr/tools/semantic_plan.mojo'),'--faults',str((build/'parser-faults.so').resolve()),'--copy-faults',str((build/'copy-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'sealed')])]
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
jobs=json.load(open('../iq4-native-development/commands.json'))
jobs.append(['source-digest',[sys.executable,'tests/test_hailo_source_digest.py','--binary',mapping['smidr/tools/source_byte_digest.mojo'],'--api',mapping['tests/hailo_source_digest_api.mojo'],'--faults',str(Path('../source-digest-native-final-v2/io-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'digest')],True])
jobs.append(['sealed-copy',[sys.executable,'tests/test_hailo_sealed_source_copy.py','--binary',mapping['smidr/tools/sealed_source_copy.mojo'],'--api',mapping['tests/hailo_sealed_source_api.mojo'],'--faults',str((build/'copy-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'copy')],True])
# Old command paths map by exact source of historical builds, never by eligibility guesses.
historical=[]
for p in ('../iq4-native-final/build-results.json','../source-digest-native-final-v2/build-results.json','../sealed-copy-native-final/build-results.json'):
 historical+=json.load(open(p))
known={str(Path(r['binary']).resolve()):r['source'] for r in historical+controls}
for name,cmd,_ in jobs:
 new=[]
 for val in cmd[1:]:
  key=str(Path(val).resolve())
  if key in known:
   src=known[key];assert src in mapping,(name,src);new.append(mapping[src])
  else:new.append(val.replace('../iq4-native-acceptance',str(out/'legacy')))
 results.append(run(name,[sys.executable,'../sealed-gguf-native-development/pair-all.py',str(out/'pairs'/(name+'.json')),*new]))
 (out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
links=[]
for r in rows:
 p=subprocess.run(['ldd',r['binary']],capture_output=True,text=True,check=True)
 for token in ('libcrypto','libssl','hailort','cuda','torch','onnxruntime','ggml'):assert token not in p.stdout.lower(),p.stdout
 links.append({'source':r['source'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
(out/'dependency-inspection.json').write_text(json.dumps(links,indent=2)+'\n')
pairs=[r for p in (out/'pairs').glob('*.json') for r in json.load(open(p))];expected={r['binary'] for r in rows if r['source'] in {r['source'] for r in controls}}
assert {r['binary'] for r in pairs}==expected,(expected-{r['binary'] for r in pairs})
(out/'regression-summary.json').write_text(json.dumps({'controls':len(expected),'success_pairs':sum(r['returncode']==0 for r in pairs),'nonzero_pairs':sum(r['returncode']!=0 for r in pairs),'skipped_pairs':0,'complete_mutation_pairs':sum(bool(r['intentional_fixture_mutation_restored_for_control']) for r in pairs),'unchanged_old_sources':653,'unchanged_old_python_inputs':68,'unchanged_old_binary_controls':106},indent=2)+'\n')
stable();print('all scoped native suites and all 106 complete frozen binary control pairs pass',flush=True)
