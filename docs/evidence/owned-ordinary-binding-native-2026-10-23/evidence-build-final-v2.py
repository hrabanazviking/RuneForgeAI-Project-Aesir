from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
out=Path('../owned-ordinary-binding-native-final-v2');out.mkdir(exist_ok=False);base=Path('../owned-ordinary-binding-native-baseline')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};old=json.load(open(base/'source-hashes.json'));assert len(old)==672 and all(sources[k]==v for k,v in old.items())
inputs=json.load(open(base/'test-input-hashes.json'));assert len(inputs)==73 and all(h(Path(k))==v for k,v in inputs.items())
controls=json.load(open(base/'controls.json'));assert len(controls)==122 and all(h(Path(r['binary']))==r['sha256'] for r in controls)
for name,data in [('source-hashes.json',sources),('test-input-hashes.json',{str(p):h(p) for p in Path('tests').glob('test_*.py')})]:(out/name).write_text(json.dumps(data,indent=2)+'\n')
for name in sources:
 q=out/'source-snapshot'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(Path(name).read_bytes())
for p in Path('tests').glob('test_*.py'):
 q=out/'test-snapshot'/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(p.read_bytes())
names=[r['source'] for r in json.load(open('../sealed-collection-native-final-v2/build-results.json'))]
for mod,api in [('decoder_layers','hailo_decoder_layers_api'),('decoder_architecture','hailo_decoder_architecture_api'),('decoder_projections','hailo_decoder_projections_api'),('ordinary_projection_schema','hailo_ordinary_projection_schema_api'),('owned_gguf_compiler','hailo_owned_gguf_api'),('owned_ordinary_binding','hailo_owned_ordinary_binding_api')]:
 names.extend(['smidr/tools/'+mod+'.mojo','tests/'+api+'.mojo'])
assert len(names)==len(set(names))==26
# Compute new-leaf transitive closure from source imports and entrypoints.
import re
mods={p[:-5].replace('/','.') if not p.startswith('tests/') else Path(p).stem:p for p in sources}
deps={p:{mods[m] for m in re.findall(r'^from\s+([\w.]+)\s+import',Path(p).read_text(),re.M) if m in mods} for p in sources}
closure={'smidr/owned_ordinary_binding.mojo'}
while True:
 more={p for p,ds in deps.items() if ds & closure};new=closure|more
 if new==closure:break
 closure=new
consumers=sorted(p for p in closure if re.search(r'^def main\(',Path(p).read_text(),re.M));assert consumers==['smidr/tools/owned_ordinary_binding.mojo','tests/hailo_owned_ordinary_binding_api.mojo'],consumers
(out/'consumer-closure.json').write_text(json.dumps(dict(old_sources_unchanged=len(old),current_sources=len(sources),new_leaf='smidr/owned_ordinary_binding.mojo',actual_transitive_consumers=consumers,new_sources=sorted(set(sources)-set(old)),immutable_controls=len(controls)),indent=2)+'\n')
def build(item):
 i,name=item;b=(out/f'entry-{i:03d}').resolve();log=out/f'build-{i:03d}.txt';cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)]
 with log.open('wb') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 return dict(source=name,binary=str(b),returncode=r.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None,arguments=cmd)
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for row in pool.map(build,enumerate(names)):
  rows.append(row);(out/'build-progress.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),row['source'],row['returncode'],row['diagnostic_bytes'],flush=True)
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(r['returncode']==r['diagnostic_bytes']==0 for r in rows),rows
cs=[]
for name in ('sealed_collection_faults','source_sealed_copy_faults','sealed_gguf_faults','sealed_safetensors_mutation','sealed_metadata_faults','source_root_io_faults','ordinary_binding_faults','owned_gguf_faults'):
 src=Path('tests')/(name+'.c');b=out/(name+'.so');cmd=['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',str(src),'-ldl','-o',str(b)];r=subprocess.run(cmd,capture_output=True);(out/(name+'-build.txt')).write_bytes(r.stdout+r.stderr)
 cs.append(dict(source=str(src),source_sha256=h(src),binary=str(b.resolve()),binary_sha256=h(b) if b.exists() else None,returncode=r.returncode,diagnostic_bytes=len(r.stdout+r.stderr),arguments=cmd))
(out/'c-build-results.json').write_text(json.dumps(cs,indent=2)+'\n');assert all(r['returncode']==r['diagnostic_bytes']==0 for r in cs),cs
assert sources=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
print('26 clean Mojo/8 C stable links before native acceptance',flush=True)
