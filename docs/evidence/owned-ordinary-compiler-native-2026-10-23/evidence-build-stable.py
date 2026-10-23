from pathlib import Path
import concurrent.futures,hashlib,json,os,re,shutil,subprocess
base=Path('../owned-ordinary-compiler-native-baseline');prior=Path('../owned-ordinary-compiler-native-final');out=Path('../owned-ordinary-compiler-native-final-v2');out.mkdir(exist_ok=False)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.load(open(base/'source-hashes.json'));sources={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};assert all(sources[k]==v for k,v in old.items())
for name,data,snap in [('source-hashes.json',sources,'source-snapshot'),('test-input-hashes.json',{str(p):h(p) for p in Path('tests').glob('test_*.py')},'test-snapshot')]:
 (out/name).write_text(json.dumps(data,indent=2)+'\n')
 for p,d in data.items():q=out/snap/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(Path(p).read_bytes());assert h(q)==d
mods={p[:-5].replace('/','.') if not p.startswith('tests/') else Path(p).stem:p for p in sources};deps={p:{mods[m] for m in re.findall(r'^from\s+([\w.]+)\s+import',Path(p).read_text(),re.M) if m in mods} for p in sources}
prior_hash=json.load(open(prior/'source-hashes.json'));changed={k for k,v in sources.items() if prior_hash.get(k)!=v}
def closure(p):
 c={p}
 while True:
  n=c|set().union(*(deps[x] for x in c))
  if n==c:return c
  c=n
rows=[];new=[]
for i,r in enumerate(json.load(open(prior/'build-results.json'))):
 p=r['source']
 if p in ('smidr/tools/owned_ordinary_compiler.mojo','tests/hailo_owned_ordinary_compiler_api.mojo'):new.append((i,p));continue
 assert not (closure(p)&changed),(p,changed)
 assert r['returncode']==r['diagnostic_bytes']==0 and h(Path(r['binary']))==r['sha256']
 b=(out/f'entry-{i:03d}').resolve();shutil.copy2(r['binary'],b);log=out/f'build-{i:03d}.txt';log.write_bytes((prior/f'build-{i:03d}.txt').read_bytes())
 row=r.copy();row.update(binary=str(b),actual_slice_build=r['binary'],all_transitive_inputs_unchanged=True,transitive_source_identities={p:sources[p] for p in sorted(closure(p))});rows.append(row)
def build(item):
 i,p=item;b=(out/f'entry-{i:03d}').resolve();cmd=['mojo','build','-I','.','-I','aesir_engine','-I','tests',p,'-o',str(b)];log=out/f'build-{i:03d}.txt'
 with log.open('wb') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600,env=os.environ|{'MODULAR_CACHE_DIR':'../mojo-cache'})
 return dict(source=p,binary=str(b),returncode=r.returncode,diagnostic_bytes=log.stat().st_size,sha256=h(b) if b.exists() else None,arguments=cmd,transitive_source_identities={p:sources[p] for p in sorted(closure(p))})
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for row in pool.map(build,new):rows.append(row);print(row['source'],row['returncode'],row['diagnostic_bytes'],flush=True)
assert len(rows)==30 and all(r['returncode']==r['diagnostic_bytes']==0 for r in rows)
(out/'build-results.json').write_text(json.dumps(rows,indent=2)+'\n')
cs=[]
for r in json.load(open(prior/'c-build-results.json')):
 assert h(Path(r['source']))==r['source_sha256'] and h(Path(r['binary']))==r['binary_sha256'] and r['returncode']==r['diagnostic_bytes']==0
 b=(out/Path(r['binary']).name).resolve();shutil.copy2(r['binary'],b);row=r.copy();row.update(binary=str(b),actual_slice_build=r['binary']);cs.append(row)
(out/'c-build-results.json').write_text(json.dumps(cs,indent=2)+'\n');shutil.copy2(prior/'consumer-closure.json',out/'consumer-closure.json')
assert sources=={str(p):h(p) for p in Path('.').rglob('*.mojo') if '.git' not in p.parts}
for p,d in json.load(open(out/'test-input-hashes.json')).items():assert h(Path(p))==d
print('30 clean slice builds, 9 clean C, exact actual dependency identities; all links stable before native',flush=True)
