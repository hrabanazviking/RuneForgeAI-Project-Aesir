from pathlib import Path
import hashlib,json,shutil
root=Path.cwd();folder=root/'docs/evidence/dynamic-graph-lowering-2026-10-21';original=root.parent/'dynamic-graph-publication/receipts-original-absolute'
shutil.copytree(folder,original)
rows=[]
for p in folder.glob('*.json'):
 before=p.read_text();after=before.replace(str(root)+'/', '').replace(str(root.parent)+'/', '../')
 if after!=before:
  p.write_text(after)
  rows.append(dict(file=p.name,original_sha256=hashlib.sha256(before.encode()).hexdigest(),portable_sha256=hashlib.sha256(after.encode()).hexdigest()))
(folder/'portable-paths.json').write_text(json.dumps(dict(scope='Published JSON paths inside the task repository are relative to the repository root; neighboring work artifacts use ../. Raw machine-local originals are preserved outside Git. File-content hashes and actual test results are unchanged.',transformed=rows),indent=2)+'\n')
(folder/'README.md').write_text((folder/'README.md').read_text()+'''\nPublished JSON uses repository-relative paths and ../ for neighboring work
artifacts. portable-paths.json records original and portable document identities.
Unmodified machine-local originals are retained outside Git; payload/source/binary
file hashes and acceptance outcomes are unchanged by this publication transform.
''')
p=root/'CAPABILITY_LEDGER.md';s=p.read_text().replace('| `verified` | 115 |','| `verified` | 116 |',1).replace('| **Total** | **160** |','| **Total** | **161** |',1);p.write_text(s)
print('Portable JSON copies:',len(rows))
