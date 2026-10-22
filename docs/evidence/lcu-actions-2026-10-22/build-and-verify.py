import hashlib,json,os,subprocess
from pathlib import Path
root=Path.cwd();out=Path('../lcu-action-final')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
mojo={str(p):sha(p) for p in sorted(root.rglob('*.mojo')) if '.git' not in p.parts}
# Portable identities: no source bodies or binaries in the published receipt.
mojo={str(Path(p).relative_to(root)):h for p,h in mojo.items()}
inputs=['tests/test_hailo_lcu_actions.py','tests/hailo_lcu_action_oracle.cpp','tests/test_hailo_context_actions.py','tests/hailo_context_action_oracle.cpp','../lcu-action-development/build-and-verify.py','../lcu-action-development/pair-legacy.py']
inputs={p:sha(p) for p in inputs}
freeze=json.loads(Path('docs/evidence/program-target-lcu-boundary-2026-10-22/pre-code-freeze.json').read_text())
for p,h in freeze['source_sha256'].items():assert sha(p)==h,p
for p,h in freeze['control_sha256'].items():assert sha(p)==h,p
(out/'source-hashes.json').write_text(json.dumps(mojo,indent=2)+'\n')
(out/'input-hashes.json').write_text(json.dumps(inputs,indent=2)+'\n')
for p in mojo:
 dest=out/'source-snapshot'/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(Path(p).read_bytes())
def stable():
 for p,h in {**mojo,**inputs,**freeze['control_sha256']}.items():assert sha(p)==h,p
builds=[('inspector','smidr/tools/lcu_actions.mojo'),('ownership','tests/hailo_lcu_action_ownership.mojo'),('old-inspector','smidr/tools/context_actions.mojo'),('old-ownership','tests/hailo_context_action_ownership.mojo'),('oracle','tests/hailo_lcu_action_oracle.cpp'),('old-oracle','tests/hailo_context_action_oracle.cpp')]
results=[]
for name,src in builds:
 stable();binary=out/name;log=out/(name+'-build.txt')
 if src.endswith('.mojo'):
  cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)]
 else:cmd=['g++','-std=c++20','-Wall','-Wextra','-Werror','-I','../hailort-program-census/source/common/include',src,'-o',str(binary)]
 env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache')
 p=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=300)
 log.write_text(p.stdout+p.stderr)
 row={'source':src,'binary':str(binary),'returncode':p.returncode,'diagnostic_bytes':log.stat().st_size}
 if p.returncode==0:row['sha256']=sha(binary)
 results.append(row);(out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n');print('build',name,p.returncode,log.stat().st_size,flush=True)
 assert p.returncode==0 and log.stat().st_size==0,(name,log)
stable()
steps=[('new',['python3','tests/test_hailo_lcu_actions.py','--binary',str(out/'inspector'),'--ownership',str(out/'ownership'),'--oracle',str(out/'oracle'),'--strace','strace','--evidence',str(out/'new')]),('legacy',['python3','../lcu-action-development/pair-legacy.py'])]
tests=[]
for name,cmd in steps:
 stable();p=subprocess.run(cmd,capture_output=True,text=True,timeout=300)
 (out/(name+'-tests.txt')).write_text(p.stdout+p.stderr)
 tests.append({'suite':name,'returncode':p.returncode});(out/'test-results.json').write_text(json.dumps(tests,indent=2)+'\n');print('suite',name,p.returncode,flush=True)
 assert p.returncode==0,name
stable();print('All frozen sources/inputs/controls unchanged; six clean builds and both suites passed',flush=True)
