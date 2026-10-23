from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess
out=Path('../sealed-collection-native-final');out.mkdir(exist_ok=False);base=Path('../sealed-collection-native-baseline')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};old=json.load(open(base/'source-hashes.json'));assert all(sources[k]==v for k,v in old.items()) and len(old)==669
inputs=json.load(open(base/'test-input-hashes.json'));assert all(h(Path(k))==v for k,v in inputs.items()) and len(inputs)==72
controls=json.load(open(base/'controls.json'));assert all(h(Path(r['binary']))==r['sha256'] for r in controls) and len(controls)==119
for name,data in [('source-hashes.json',sources),('test-input-hashes.json',{str(p):h(p) for p in Path('tests').glob('test_*.py')})]:(out/name).write_text(json.dumps(data,indent=2)+'\n')
for name in sources:
 q=out/'source-snapshot'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(Path(name).read_bytes())
for p in Path('tests').glob('test_*.py'):
 q=out/'test-snapshot'/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(p.read_bytes())
consumers=[p for p in sources if 'from smidr.sealed_source_collection import' in Path(p).read_text()];assert sorted(consumers)==['smidr/tools/sealed_source_collection.mojo','tests/hailo_sealed_collection_api.mojo']
names=['smidr/tools/source_root.mojo','tests/hailo_source_root_api.mojo','smidr/tools/shard_collection.mojo','tests/hailo_shard_collection_api.mojo','smidr/tools/unindexed_source.mojo','tests/hailo_unindexed_source_api.mojo','smidr/tools/sealed_source_metadata.mojo','tests/hailo_sealed_metadata_api.mojo','smidr/tools/sealed_safetensors_source.mojo','tests/hailo_sealed_safetensors_api.mojo','smidr/tools/sealed_source_copy.mojo','tests/hailo_sealed_source_api.mojo',*consumers]
# The historical auxiliary root API is an additional frozen control, not part
# of the119 pre-code primary controls. Its old binary was pinned previously.
prior=json.load(open('../sealed-safetensors-native-recording/inherited-auxiliary-input-continuity-before-reviewed.json'))
(out/'prior-auxiliary-identities.json').write_text(json.dumps(prior,indent=2)+'\n')
def build(item):
 i,name=item;b=(out/f'entry-{i:03d}').resolve();log=out/f'build-{i:03d}.txt';cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)]
 with log.open('wb') as stream:p=subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 return dict(source=name,binary=str(b),returncode=p.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None,arguments=cmd)
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for row in pool.map(build,enumerate(names)):
  rows.append(row);(out/'build-progress.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),row['source'],row['returncode'],row['diagnostic_bytes'],flush=True)
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n');assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),rows
cs=[]
for name in ('sealed_collection_faults','source_sealed_copy_faults','sealed_gguf_faults','sealed_safetensors_mutation','sealed_metadata_faults','source_root_io_faults'):
 src=Path('tests')/(name+'.c');b=out/(name+'.so');cmd=['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',str(src),'-ldl','-o',str(b)];r=subprocess.run(cmd,capture_output=True);(out/(name+'-build.txt')).write_bytes(r.stdout+r.stderr)
 cs.append(dict(source=str(src),source_sha256=h(src),binary=str(b.resolve()),binary_sha256=h(b) if b.exists() else None,returncode=r.returncode,diagnostic_bytes=len(r.stdout+r.stderr),arguments=cmd))
(out/'c-build-results.json').write_text(json.dumps(cs,indent=2)+'\n');assert all(r['returncode']==r['diagnostic_bytes']==0 for r in cs),cs
assert sources=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
print('14 stable Mojo/6 C builds linked before acceptance',flush=True)
