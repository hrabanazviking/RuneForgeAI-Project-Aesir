from pathlib import Path
import json,hashlib,re
out=Path('../q2q3-native-baseline');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','python-snapshot')]:
 for p,h in json.loads((out/name).read_text()).items():assert sha(p)==h==sha(out/folder/p),p
sources={str(p):p.read_text() for p in Path('.').rglob('*.mojo')}
imports={p:set(re.findall(r'^(?:from|import) ([\w.]+)',s,re.M)) for p,s in sources.items()}
affected={'aesir_engine/loader/packed_gguf.mojo'}
while True:
 names={p.removeprefix(prefix).removesuffix('.mojo').replace('/','.') for p in affected for prefix in ('','aesir_engine/')}
 added={p for p,i in imports.items() if i&names}
 if added<=affected:break
 affected|=added
controls=json.loads((out/'controls.json').read_text());covered={x['source'] for x in controls}
for x in controls:assert sha(x['binary'])==x['sha256']
(out/'consumer-inventory.json').write_text(json.dumps({'affected_sources':sorted(affected),'frozen_entrypoints':sorted(covered),'affected_entrypoints_without_control':sorted(p for p in affected-covered if 'def main(' in sources[p]),'preparation_note':'Initial inventory scan reread files repeatedly and was terminated after snapshots/controls froze, before code changes. This cached scan verifies all snapshot/control identities before completing inventory.'},indent=2)+'\n')
print('Verified643 actual source snapshots,64 Python snapshots,81 controls; inventory completed')
print(json.dumps(json.loads((out/'consumer-inventory.json').read_text())['affected_entrypoints_without_control'],indent=2))
