from pathlib import Path
import hashlib,json,subprocess,sys
out=Path('../source-digest-native-acceptance');out.mkdir(exist_ok=False);build=Path('../source-digest-native-final')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(build/'input-hashes.json'));controls=json.load(open('../source-digest-native-baseline/controls.json'))
assert len(rows)==8 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
for p in Path('../source-digest-native-development').glob('*'):
 if p.is_file():inputs[str(p)]=sha(p)
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
def stable():
 for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256']
def run(name,cmd):
 stable()
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 row={'suite':name,'command':cmd,'returncode':r.returncode};(out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');stable();print(name,r.returncode,flush=True);return row
mapping={r['source']:r['binary'] for r in rows}
results=[run('source-digest',[sys.executable,'tests/test_hailo_source_digest.py','--binary',mapping['smidr/tools/source_byte_digest.mojo'],'--api',mapping['tests/hailo_source_digest_api.mojo'],'--faults',str((build/'io-faults.so').resolve()),'--strace','/usr/bin/strace','--evidence',str(out/'digest')])]
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n')
assert results[-1]['returncode']==0
for name,cmd,_ in json.load(open('../source-digest-native-development/selected-commands.json')):
 replacements={x['binary']:mapping[x['source']] for x in controls if x['source'] in mapping}
 new=[]
 for val in cmd[1:]:
  found=next((x for x in controls if Path(val).name==Path(x['binary']).name and x['source'] in mapping),None)
  new.append(mapping[found['source']] if found else val.replace('../iq4-native-acceptance',str(out/'legacy')))
 results.append(run(name,[sys.executable,'../source-digest-native-development/pair-selected.py',str(out/'pairs'/(name+'.json')),*new]))
 (out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert results[-1]['returncode']==0
links=[]
for r in rows:
 p=subprocess.run(['ldd',r['binary']],capture_output=True,text=True,check=True)
 for token in ('libcrypto','libssl','hailort','cuda','torch','onnxruntime','ggml'):assert token not in p.stdout.lower(),p.stdout
 links.append({'source':r['source'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
(out/'dependency-inspection.json').write_text(json.dumps(links,indent=2)+'\n')
pairs=[r for p in (out/'pairs').glob('*.json') for r in json.load(open(p))]
expected={x['binary'] for x in rows if x['source'] in {c['source'] for c in controls}}
assert {x['binary'] for x in pairs}==expected
summary={'selected_controls':len(expected),'success_pairs':sum(x['returncode']==0 for x in pairs),'nonzero_pairs':sum(x['returncode']!=0 for x in pairs),'skipped_pairs':0,'old649_sources_unchanged':True,'old66_python_inputs_unchanged':True,'old102_controls_unchanged':True,'dependency_inspection_separate_from_native_calls':True}
(out/'regression-summary.json').write_text(json.dumps(summary,indent=2)+'\n');stable();print(summary,flush=True)
