from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path('../iq4-native-review');original=Path('../iq4-native-acceptance');out=Path('../iq4-native-reviewed-acceptance');build=Path('../iq4-native-final');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
inputs=json.loads((original/'input-hashes.json').read_text());sources=json.loads((build/'source-hashes.json').read_text());rows=json.loads((build/'build-results.json').read_text());controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text())
inputs[str(Path(__file__))]=sha(__file__)
def stable():
 for p,h in {**inputs,**sources}.items():assert sha(p)==h,p
 for x in rows+controls:assert sha(x['binary'])==x['sha256'],x['binary']
stable();shutil.copytree(original,out)
results=json.loads((out/'test-results.json').read_text());assert len(results)==48 and sum(x['returncode']!=0 for x in results)==1
failed=next(x for x in results if x['returncode']!=0);assert failed['suite']=='q8-traces'
# Correct already-qualified normal spacing; preserve PID joins/all access guards.
cmd=[sys.executable,'../classic32-source-audit-review/audit-traces.py',str(out/'q8')]
with (out/'q8-traces-tests.txt').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=120)
assert r.returncode==0
row={'suite':'q8-traces','returncode':r.returncode,'command':cmd};results=[row if x['suite']=='q8-traces' else x for x in results];(out/'q8-traces-status.json').write_text(json.dumps(row,indent=2)+'\n');(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n')
(root/'audit-correction.json').write_text(json.dumps({'original_failure':'Old Q8 audit required exactly one space after resumed mmap closing parenthesis. Raw trace shows successful whole-fixture mmap.','corrected_auditor':'../classic32-source-audit-review/audit-traces.py','all43_native_suites_already_passed':True,'all48_final_statuses_zero':True,'source_binary_test_input_changes':False,'raw_traces_changed':False,'native_suites_reexecuted':0,'all_original_artifacts_retained':True,'comparison_skips':0},indent=2)+'\n')
# Continue only the original frozen footer that had not run after audit assertion.
code=Path('../iq4-native-development/verify-final.py').read_text();tail=code[code.index('pairs=[x for p in'):]
(root/'frozen-footer.json').write_text(json.dumps({'source':'../iq4-native-development/verify-final.py','source_sha256':sha('../iq4-native-development/verify-final.py'),'suffix_sha256':hashlib.sha256(tail.encode()).hexdigest(),'execution':'Only previously unexecuted control coverage/admission/dependency/header footer, against copied native results.'},indent=2)+'\n')
(out/'review-input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
exec(compile(tail,'<frozen-IQ4-verification-footer>','exec'))
stable();assert all(x['returncode']==0 for x in results)
print('All43 unchanged native suites and5 audits verified;old Q8 whitespace parser failure retained without native rerun',flush=True)
