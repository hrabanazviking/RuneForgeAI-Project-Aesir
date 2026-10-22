from pathlib import Path
import hashlib,json,subprocess,sys
root=Path('../classic32-source-extra');out=root/'acceptance';out.mkdir(exist_ok=False)
rows=json.loads((root/'build/build-results.json').read_text());current={x['source']:x['binary'] for x in rows if x['side']=='current'};old={x['source']:x['binary'] for x in rows if x['side']=='old'}
for x in rows:assert hashlib.sha256(Path(x['binary']).read_bytes()).hexdigest()==x['sha256']
cmd=[sys.executable,str(root/'pair-extra.py'),str(out/'frozen-pairs.json'),'tests/test_hailo_source_storage.py','--binary',current['smidr/tools/source_storage.mojo'],'--api',current['tests/hailo_source_storage_api.mojo'],'--gguf-inventory',str(Path('../classic32-source-final/tagged-source-inventory').resolve()),'--safe-inventory',current['smidr/tools/safetensors_inventory.mojo'],'--strace','/usr/bin/strace','--evidence',str(out/'source-storage')]
with (out/'tests.txt').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=900)
(out/'status.json').write_text(json.dumps({'command':cmd,'returncode':r.returncode},indent=2)+'\n');assert r.returncode==0
args=['arithmetic','gguf','2','256']
a=subprocess.run([old['tests/hailo_source_storage_api.mojo'],*args],capture_output=True,text=True);b=subprocess.run([current['tests/hailo_source_storage_api.mojo'],*args],capture_output=True,text=True)
assert a.returncode!=0 and 'unsupported tensor type 2' in a.stderr,(a.returncode,a.stdout,a.stderr)
assert b.returncode==0 and json.loads(b.stdout)=={'elements':256,'bytes':144}
(out/'intentional-admission-delta.json').write_text(json.dumps({'key':['tests/hailo_source_storage_api.mojo',*args],'old_binary':old['tests/hailo_source_storage_api.mojo'],'new_binary':current['tests/hailo_source_storage_api.mojo'],'old_returncode':a.returncode,'old_stdout':a.stdout,'old_stderr':a.stderr,'new_returncode':b.returncode,'new_stdout':b.stdout,'new_stderr':b.stderr,'unrelated_comparisons_skipped':0,'baseline_built_after_implementation_from_pre_code_snapshot':True},indent=2)+'\n')
print('Complete source-storage suite and genuine source-kind2 admission delta passed',flush=True)
