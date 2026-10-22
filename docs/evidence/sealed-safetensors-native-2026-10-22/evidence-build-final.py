from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess,re
out=Path('../sealed-safetensors-native-final');out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
(out/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n')
for name in sources:
 p=out/'source-snapshot'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(Path(name).read_bytes())
old=json.load(open('../sealed-safetensors-native-baseline/source-hashes.json'));changed=[p for p,d in old.items() if sources[p]!=d];assert changed==['armvegr/safetensors.mojo'],changed
# Every preexisting parser/conversion/tensor body stays exact outside four
# contracted SafetensorsLoader lifetime methods. Record each independently.
def bodies(path):
 lines=path.read_text().splitlines(keepends=True);owner='';result={}
 for i,line in enumerate(lines):
  m=re.match(r'^struct (\w+)',line)
  if m:owner=m[1]
  m=re.match(r'^(    )?def (\w+)',line)
  if not m:continue
  indent=4 if m[1] else 0;key=(owner+'.' if indent else '')+m[2];end=i+1
  while end<len(lines):
   nxt=lines[end]
   if nxt.strip() and len(nxt)-len(nxt.lstrip())<=indent and re.match(r'\s*(?:def |struct |# --)',nxt):break
   end+=1
  result[key]=''.join(lines[i:end]).rstrip()
 return result
before=bodies(Path('../sealed-safetensors-native-baseline/source-snapshot/armvegr/safetensors.mojo'));after=bodies(Path('armvegr/safetensors.mojo'));allowed={'SafetensorsLoader.__init__','SafetensorsLoader._req','SafetensorsLoader.open','SafetensorsLoader.close'}
proof=[]
for name,body in before.items():
 if name in allowed:continue
 assert after[name]==body,name
 proof.append(dict(name=name,sha256=hashlib.sha256(body.encode()).hexdigest()))
(out/'unchanged-existing-bodies.json').write_text(json.dumps(proof,indent=2)+'\n')
controls=json.load(open('../sealed-safetensors-native-baseline/controls.json'));names=[r['source'] for r in controls]+['smidr/tools/sealed_safetensors_source.mojo','tests/hailo_sealed_safetensors_api.mojo']
def build(item):
 i,name=item;b=(out/f'entry-{i:03d}').resolve();log=out/f'build-{i:03d}.txt'
 with log.open('wb') as stream:p=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',name,'-o',str(b)],stdout=stream,stderr=subprocess.STDOUT,timeout=600,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'))
 return dict(source=name,binary=str(b),returncode=p.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None)
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for row in pool.map(build,enumerate(names)):
  rows.append(row);(out/'build-progress.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),row['source'],row['returncode'],row['diagnostic_bytes'],flush=True)
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows),[r for r in rows if r['returncode'] or r['diagnostic_bytes']]
for name in ['tests/sealed_gguf_faults.c','tests/source_sealed_copy_faults.c','tests/owned_gguf_faults.c']:
 b=out/(Path(name).stem+'.so');p=subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',name,'-ldl','-o',str(b)],capture_output=True)
 (out/(b.name+'.build.txt')).write_bytes(p.stdout+p.stderr);assert p.returncode==0 and not p.stdout+p.stderr,(name,p.stderr)
assert sources=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
print('all stable builds complete before native execution',flush=True)
