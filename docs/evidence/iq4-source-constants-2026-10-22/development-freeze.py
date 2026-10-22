from pathlib import Path
import hashlib,json,re,shutil
out=Path('../iq4-native-baseline');out.mkdir(exist_ok=False);prior=Path('../iq4-source-study');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for name,n,folder in [('source-hashes.json',646,'source-snapshot'),('test-input-hashes.json',65,'python-snapshot')]:
 data=json.loads((prior/name).read_text());assert len(data)==n
 for p,h in data.items():
  assert sha(p)==h,p;dst=out/folder/p;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst)
 shutil.copyfile(prior/name,out/name)
controls=json.loads((prior/'controls.json').read_text());assert len(controls)==100
for x in controls:assert sha(x['binary'])==x['sha256']
shutil.copyfile(prior/'controls.json',out/'controls.json')
sources={str(p):p.read_text() for p in Path('.').rglob('*.mojo')};imports={p:set(re.findall(r'^(?:from|import) ([\w.]+)',s,re.M)) for p,s in sources.items()};affected={'aesir_engine/loader/packed_gguf.mojo'}
while True:
 modules={p.removeprefix(prefix).removesuffix('.mojo').replace('/','.') for p in affected for prefix in ('','aesir_engine/')};new={p for p,mods in imports.items() if mods&modules}
 if new<=affected:break
 affected|=new
safe={p for p in affected if p.startswith(('smidr/','tests/hailo_')) and 'def main(' in sources[p]};covered={x['source'] for x in controls};assert not safe-covered,safe-covered
(out/'consumer-inventory.json').write_text(json.dumps({'all_transitive_imports':sorted(affected),'safe_entrypoints':sorted(safe),'frozen_control_sources':sorted(covered),'safe_entrypoints_without_control':[],'excluded_host_model_and_historical_entrypoints':[p for p in sorted(affected) if p not in covered and not p.startswith(('smidr/','tests/hailo_')) and 'def main(' in sources[p]]},indent=2)+'\n')
print('646 actual Mojo/65 Python snapshots and100 current binaries verified before code;all safe import entrypoints covered')
