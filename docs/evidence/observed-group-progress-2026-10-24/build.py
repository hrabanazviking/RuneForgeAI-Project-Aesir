from pathlib import Path
import json,hashlib,subprocess,shutil,os,re,concurrent.futures
repo=Path.cwd();base=repo.parent/'soc-observed-progress-baseline';out=repo.parent/'soc-observed-progress-final-v3';out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for r in json.loads((repo/'docs/evidence/observed-progress-contract-2026-10-24/archive-identities.json').read_text()):assert h(repo.parent/r['path'])==r['sha256']
assert h(Path('/home/pi/mojo-dev/.pixi/envs/default/bin/mojo'))==json.loads((base/'compiler.json').read_text())['sha256']
for r in json.loads((base/'controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
for suffix,name,folder,n in [('.mojo','source-hashes.json','source-snapshot',711),('.py','test-input-hashes.json','test-snapshot',88)]:
 files=sorted(p for p in (repo if suffix=='.mojo' else repo/'tests').rglob('*'+suffix) if '.git' not in p.parts);assert len(files)==n
 current={str(p.relative_to(repo)):h(p) for p in files};old=json.loads((base/name).read_text());changed=[p for p,d in old.items() if current.get(p)!=d];assert changed==(['hailbru/soc_progress.mojo'] if suffix=='.mojo' else [])
 (out/name).write_text(json.dumps(current,indent=2)+'\n')
 for p in files:q=out/folder/p.relative_to(repo);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
compile(Path('tests/test_hailo_soc_exchange_progress.py').read_text(),'tests/test_hailo_soc_exchange_progress.py','exec')
files=list(repo.rglob('*.mojo'));nodes={str(p.relative_to(repo))[:-5].replace('/','.'):p for p in files if '.git' not in p.parts};affected={'hailbru.soc_progress','hailbru.soc_exchange_progress'}
while True:
 new=affected|{m for m,p in nodes.items() if set(re.findall(r'^\s*from\s+([\w.]+)\s+import',p.read_text(),re.M))&affected}
 if new==affected:break
 affected=new
entries=sorted(str(nodes[m].relative_to(repo)) for m in affected if re.search(r'^def main\(',nodes[m].read_text(),re.M));expected=['smidr/tools/soc_exchange_progress.mojo','smidr/tools/soc_rpc_device.mojo','tests/hailo_soc_exchange_progress_api.mojo','tests/hailo_soc_progress.mojo'];assert entries==expected,entries
(out/'affected-closure.json').write_text(json.dumps(dict(modules=sorted(affected),executables=entries,excluded_physical_run='smidr/tools/soc_rpc_device.mojo'),indent=2)+'\n')
# Link all actual affected/auxiliary images before acceptance.
names=['smidr/tools/soc_exchange_progress.mojo','tests/hailo_soc_exchange_progress_api.mojo','tests/hailo_soc_progress.mojo','smidr/tools/soc_rpc_device.mojo']
def build(item):
 i,src=item;binary=(out/f'entry-{i:03d}').resolve();cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(binary)];r=subprocess.run(cmd,capture_output=True,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'));(out/f'build-{i:03d}.stdout').write_bytes(r.stdout);(out/f'build-{i:03d}.stderr').write_bytes(r.stderr);print(src,r.returncode,len(r.stdout+r.stderr),flush=True);return dict(source=src,binary=str(binary),sha256=h(binary) if binary.exists() else None,returncode=r.returncode,arguments=cmd)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,enumerate(names)))
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(r['returncode']==0 for r in rows)
for i,r in enumerate(rows):
 assert not re.search(r'(?:soc_exchange_progress(?:_api)?|soc_progress)\.mojo:\d+:\d+: (?:warning|error):',(out/f'build-{i:03d}.stderr').read_text())
 for option,tag in [('-dW','dynamic'),('-Ws','symbols')]:
  p=subprocess.run(['readelf',option,r['binary']],capture_output=True,timeout=30);(out/f'elf-{i}-{tag}.stdout').write_bytes(p.stdout);(out/f'elf-{i}-{tag}.stderr').write_bytes(p.stderr);assert p.returncode==0
 if i<2:shutil.copy2(r['binary'],out/f'frozen-{i:03d}')
for name in ['source-hashes.json','test-input-hashes.json']:
 for p,d in json.loads((out/name).read_text()).items():assert h(Path(p))==d
(out/'stable.json').write_text(json.dumps(dict(mojo_links=4,all_before_tests=True,elf_tables=8,old_files_changed=['hailbru/soc_progress.mojo'],old_tests_changed=0),indent=2)+'\n')
print('STABLE4 all affected links;8 ELF tables;no acceptance/device calls',flush=True)
