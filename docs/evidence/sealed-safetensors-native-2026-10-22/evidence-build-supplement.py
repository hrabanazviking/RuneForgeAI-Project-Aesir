from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
out=Path('../sealed-safetensors-native-supplement');out.mkdir(exist_ok=False)
root=Path('.').resolve();baseline=Path('../sealed-safetensors-native-baseline/source-snapshot').resolve()
names=['smidr/tools/safetensors_fd.mojo','tests/hailo_safetensors_fd_api.mojo','tests/hailo_safetensors_inventory_api.mojo','tests/h043_st_check.mojo']
def build(job):
 kind,i,name=job;cwd=root if kind=='current' else baseline;b=(out/f'{kind}-{i}').resolve();log=out/f'{kind}-{i}.txt'
 with log.open('wb') as f:p=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)],cwd=cwd,env=dict(os.environ,MODULAR_CACHE_DIR=str(root.parent/'mojo-cache')),stdout=f,stderr=subprocess.STDOUT,timeout=600)
 return dict(kind=kind,source=name,binary=str(b),returncode=p.returncode,diagnostic_bytes=log.stat().st_size,sha256=hashlib.sha256(b.read_bytes()).hexdigest() if b.exists() else None)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,[(kind,i,name) for kind in ('baseline','current') for i,name in enumerate(names)]))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),rows
for name in ['tests/sealed_safetensors_mutation.c','tests/safetensors_fd_io_faults.c']:
 b=out/(Path(name).stem+'.so');p=subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',name,'-ldl','-o',str(b)],capture_output=True);(out/(b.name+'.build.txt')).write_bytes(p.stdout+p.stderr);assert p.returncode==0 and not p.stdout+p.stderr,(name,p.stderr)
print(json.dumps(rows,indent=2))
