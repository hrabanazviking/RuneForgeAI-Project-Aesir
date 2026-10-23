from pathlib import Path
import concurrent.futures,hashlib,json,os,re,subprocess
out=Path('../sealed-metadata-native-final');out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
old=json.load(open('../sealed-metadata-native-baseline/source-hashes.json'))
assert len(old)==666 and all(sources[k]==v for k,v in old.items())
inputs=json.load(open('../sealed-metadata-native-baseline/test-input-hashes.json'))
assert len(inputs)==71 and all(h(Path(k))==v for k,v in inputs.items())
controls=json.load(open('../sealed-metadata-native-baseline/controls.json'))
assert len(controls)==117 and all(h(Path(r['binary']))==r['sha256'] for r in controls)
for name,data in [('source-hashes.json',sources),('old-source-hashes.json',old),('old-test-hashes.json',inputs)]:
 (out/name).write_text(json.dumps(data,indent=2)+'\n')
for name in sources:
 p=out/'source-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(Path(name).read_bytes())
for p in Path('tests').glob('test_*.py'):
 q=out/'test-snapshot'/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(p.read_bytes())
consumers=[p for p in sources if 'from smidr.sealed_source_metadata import' in Path(p).read_text()]
assert sorted(consumers)==['smidr/tools/sealed_source_metadata.mojo','tests/hailo_sealed_metadata_api.mojo'],consumers
(out/'consumer-closure.json').write_text(json.dumps(dict(new_leaf='smidr/sealed_source_metadata.mojo',consumers=consumers,old_sources_unchanged=666,old_tests_unchanged=71,immutable_controls=117),indent=2)+'\n')
names=['smidr/tools/source_config.mojo','tests/hailo_source_config_api.mojo','smidr/tools/source_index.mojo','tests/hailo_source_index_api.mojo','smidr/tools/sealed_source_copy.mojo','tests/hailo_sealed_source_api.mojo',*consumers]
def build(item):
 i,name=item;b=(out/f'entry-{i:03d}').resolve();log=out/f'build-{i:03d}.txt'
 cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)]
 with log.open('wb') as stream:r=subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 return dict(source=name,arguments=cmd,binary=str(b),returncode=r.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None)
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for row in pool.map(build,enumerate(names)):
  rows.append(row);(out/'build-progress.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),row['source'],row['returncode'],row['diagnostic_bytes'],flush=True)
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),rows
crows=[]
for name in ['tests/sealed_metadata_faults.c','tests/source_sealed_copy_faults.c','tests/sealed_safetensors_mutation.c','tests/source_index_io_faults.c']:
 b=out/(Path(name).stem+'.so');cmd=['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',name,'-ldl','-o',str(b)]
 r=subprocess.run(cmd,capture_output=True);(out/(b.name+'.build.txt')).write_bytes(r.stdout+r.stderr)
 crows.append(dict(source=name,arguments=cmd,source_sha256=h(Path(name)),returncode=r.returncode,diagnostic_bytes=len(r.stdout+r.stderr),binary_sha256=h(b) if b.exists() else None))
(out/'c-build-results.json').write_text(json.dumps(crows,indent=2)+'\n')
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in crows),crows
assert sources=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
print('8 stable Mojo and 4 C builds complete before native acceptance',flush=True)
