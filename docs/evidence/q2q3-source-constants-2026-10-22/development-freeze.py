from pathlib import Path
import hashlib,json,shutil
root=Path('../q2q3-source-study');out=Path('../q2q3-native-baseline');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for file,n in [('source-hashes.json',643),('test-input-hashes.json',64)]:
 obj=json.loads((root/file).read_text());assert len(obj)==n
 for p,h in obj.items():
  assert sha(p)==h,p
  dst=out/('source-snapshot' if p.endswith('.mojo') else 'python-snapshot')/p
  dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst)
 shutil.copyfile(root/file,out/file)
controls=json.loads((root/'controls.json').read_text());assert len(controls)==81
for x in controls:assert sha(x['binary'])==x['sha256']
shutil.copyfile(root/'controls.json',out/'controls.json')
# Enumerate transitive imports textually, retain all matches for closure review.
paths=list(Path('.').rglob('*.mojo'));affected={'aesir_engine/loader/packed_gguf.mojo'}
modules=lambda p:{p.removesuffix('.mojo').replace('/','.'),p.removeprefix('aesir_engine/').removesuffix('.mojo').replace('/','.')}
while True:
 names={n for p in affected for n in modules(p)}
 added={str(p) for p in paths if any(line.startswith('from '+n+' import ') or line.startswith('import '+n) for n in names for line in p.read_text().splitlines())}
 if added<=affected:break
 affected|=added
covered={x['source'] for x in controls}
(out/'consumer-inventory.json').write_text(json.dumps({'affected_sources':sorted(affected),'frozen_entrypoints':sorted(covered),'affected_entrypoints_without_control':sorted(p for p in affected-covered if 'def main(' in Path(p).read_text())},indent=2)+'\n')
print('Frozen643 sources,64 Python inputs,81 binary controls')
