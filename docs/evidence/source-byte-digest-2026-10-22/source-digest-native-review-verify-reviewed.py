from pathlib import Path
import hashlib,json,shutil,subprocess,sys
original=Path('../source-digest-native-acceptance');out=Path('../source-digest-native-reviewed-acceptance');out.mkdir(exist_ok=False)
for p in original.iterdir():
 if p.is_dir():shutil.copytree(p,out/p.name)
 else:shutil.copy2(p,out/p.name)
build=Path('../source-digest-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(original/'input-hashes.json'));controls=json.load(open('../source-digest-native-baseline/controls.json'))
excluded='../source-digest-native-development/verify-final-status.txt';assert excluded in inputs;inputs.pop(excluded)
inputs[__file__]=sha(__file__)
(out/'review-input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
Path('../source-digest-native-review/runner-correction.json').write_text(json.dumps({'failure':'The original runner froze its own growing output status file as an input. New native digest suite already passed.','excluded_output_only':excluded,'native_sources_or_tests_changed':False,'digest_suite_reexecuted':False,'all_other_original_inputs_checked':True,'original_failure_preserved':True},indent=2)+'\n')
def stable():
 for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256']
def run(name,cmd):
 stable()
 with (out/(name+'-tests.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 row={'suite':name,'command':cmd,'returncode':r.returncode};(out/(name+'-status.json')).write_text(json.dumps(row,indent=2)+'\n');stable();print(name,r.returncode,flush=True);return row
mapping={r['source']:r['binary'] for r in rows};results=json.load(open(out/'test-results.json'));assert len(results)==1 and results[0]['returncode']==0
# Run only the unexecuted suffix of the original frozen verification program.
code=Path('../source-digest-native-development/verify-final.py').read_text();tail=code[code.index('for name,cmd,_ in'):]
Path('../source-digest-native-review/footer-provenance.json').write_text(json.dumps({'source':'../source-digest-native-development/verify-final.py','source_sha256':sha('../source-digest-native-development/verify-final.py'),'suffix_sha256':hashlib.sha256(tail.encode()).hexdigest(),'scope':'Previously unexecuted regression/dependency/control-coverage suffix only'},indent=2)+'\n')
exec(compile(tail,'<frozen-source-digest-verification-footer>','exec'))
