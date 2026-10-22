from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
root=Path('../owned-compiler-native-final');root.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
(root/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n')
for name in source:
 p=root/'source-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(Path(name).read_bytes())
controls=json.load(open('../owned-compiler-native-baseline/controls.json'))
names=['smidr/tools/semantic_plan.mojo','smidr/tools/expanded_graph.mojo','smidr/tools/primitive_recipes.mojo','smidr/tools/source_weight_tiles.mojo','tests/hailo_sealed_gguf_api.mojo','tests/hailo_sealed_semantic_api.mojo','smidr/tools/sealed_gguf_source.mojo']
names+=['smidr/tools/owned_gguf_compiler.mojo','tests/hailo_owned_gguf_api.mojo']
def build(item):
 i,name=item;b=(root/f'entry-{i:03d}').resolve();log=root/f'build-{i:03d}.txt'
 cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)]
 with log.open('wb') as out:p=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 return dict(source=name,binary=str(b),returncode=p.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(build,enumerate(names)))
(root/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),rows
for name in ['tests/owned_gguf_faults.c','tests/sealed_gguf_faults.c','tests/source_sealed_copy_faults.c']:
 b=root/(Path(name).stem+'.so');p=subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',name,'-ldl','-o',str(b)],capture_output=True)
 (root/(b.name+'.build.txt')).write_bytes(p.stdout+p.stderr);assert p.returncode==0 and not p.stdout+p.stderr,(name,p.stderr)
assert source=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
print(json.dumps(rows,indent=2))
