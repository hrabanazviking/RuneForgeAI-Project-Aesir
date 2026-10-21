from pathlib import Path
import hashlib,json,subprocess,time
build=Path('../decoder-window-final')
while not (build/'build-results.json').exists():time.sleep(2)
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==58 and all(r['returncode']==0 for r in rows)
manifest=json.loads((build/'source-hashes.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in manifest.items())
for driver in ('decoder-window-regressions.py','decoder-window-extra-verify.py','decoder-window-other-regressions.py'):
 r=subprocess.run(['python3','../'+driver],capture_output=True,text=True);Path('../'+driver+'.log').write_text(r.stdout+r.stderr);print(driver,r.returncode,flush=True);assert r.returncode==0
out=Path('../decoder-window-accepted');out.mkdir(exist_ok=True)
commands=[('decoder_bias',['python3','tests/test_hailo_decoder_bias.py','--binary',str(build/'decoder-bias-graph'),'--api',str(build/'decoder-bias-api'),'--ownership',str(build/'bias-ownership'),'--gguf',str(build/'bias-gguf'),'--consumers',str(build/'bias-consumers'),'--frozen','../decoder-bias-baseline/rotary-recipes']),('decoder_activation',['python3','tests/test_hailo_decoder_activation.py','--binary',str(build/'activation-graph'),'--api',str(build/'activation-api'),'--ownership',str(build/'activation-ownership'),'--gguf',str(build/'activation-gguf'),'--consumers',str(build/'activation-consumers'),'--frozen-api','../decoder-activation-baseline/decoder-bias-api','--frozen-gguf','../decoder-activation-baseline/bias-gguf','--frozen-consumers','../decoder-activation-baseline/bias-consumers']),('decoder_session',['python3','tests/test_hailo_decoder_session.py','--binary',str(build/'session-graph'),'--api',str(build/'session-api'),'--ownership',str(build/'session-ownership'),'--gguf',str(build/'session-gguf'),'--source',str(build/'session-source'),'--frozen-api','../decoder-session-baseline/activation-api','--frozen-gguf','../decoder-session-baseline/activation-gguf']),('decoder_window',['python3','tests/test_hailo_decoder_window.py','--binary',str(build/'window-graph'),'--api',str(build/'window-api'),'--source',str(build/'window-source'),'--ownership',str(build/'window-ownership'),'--gguf',str(build/'window-gguf'),'--indices',str(build/'window-indices'),'--policy',str(build/'window-policy'),'--frozen-api','../decoder-window-baseline/session-api','--frozen-gguf','../decoder-window-baseline/session-gguf','--oracle','../ordinary-window-study/config.json','--index-oracle','../ordinary-window-study/index.json'])]
results=[]
for name,cmd in commands:
 cmd+=['--strace','/usr/bin/strace','--evidence',str(out/name)]
 with (out/(name+'-test.txt')).open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 results.append(dict(suite=name,returncode=r.returncode,command=cmd));print(name,r.returncode,flush=True)
(out/'test-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(r['returncode']==0 for r in results)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in manifest.items())
print('Final source snapshot unchanged',flush=True)
