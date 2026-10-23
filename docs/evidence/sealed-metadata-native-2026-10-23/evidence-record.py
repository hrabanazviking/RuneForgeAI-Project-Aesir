from pathlib import Path
import hashlib,json
repo=Path('.');out=repo/'docs/evidence/sealed-metadata-native-2026-10-23';out.mkdir(exist_ok=False)
record=Path(__file__).parent;accept=Path('../sealed-metadata-native-acceptance-v2');final=Path('../sealed-metadata-native-final');prefix=str(repo.resolve().parent)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def project(source,name,dependency=False):
 text=Path(source).read_text().replace(prefix,'..')
 if dependency:text=text.replace(str(Path.home()),'<host-home>')
 (out/name).write_text(text)
for name in ('summary.json','consumer-closure.json','sealed-trace-audit.json','legacy-trace-audit.json','link-before-execution.json','dependencies.json'):
 project(record/name,name,dependency=name=='dependencies.json')
for name in ('source-hashes.json','test-input-hashes.json','controls.json','qualification.json'):
 project(Path('../sealed-metadata-native-baseline')/name,'baseline-'+name)
for name in ('source-hashes.json','build-results.json','c-build-results.json'):
 project(final/name,'current-'+name)
project(accept/'results.json','test-results.json')
for suite in ('source_config','source_index','sealed-copy','sealed-metadata'):
 for suffix in ('-tests.txt','-pairs.json','-pairs-native-calls.json'):project(accept/(suite+suffix),suite+suffix)
for name in ('summary.json','independent.json','images.json','runs.json'):
 project(accept/'sealed-metadata'/name,'metadata-'+name)
project('../sealed-metadata-native-acceptance/sealed-metadata-tests.txt','retained-initial-test-refusal.txt')
for name in ('audit-first.txt','audit-recovery-reviewed.txt','audit-final.txt'):
 project(record/name,'retained-'+name)
for folder,names in [(record,['audit.py','logical.py','census.py','dependencies.py','record.py']),
 (Path('../sealed-metadata-native-development'),['build-final.py','prepare-acceptance.py','run-acceptance-v2.py']),
 (accept,['pair-all.py','universe.json','jobs.json'])]:
 for name in names:project(folder/name,'evidence-'+name)
prior=[]
for name in ('sealed-safetensors-native-2026-10-22','sealed-metadata-contract-2026-10-22','owned-compiler-native-2026-10-22'):
 manifest=Path('docs/evidence')/name/'archive-identities.json';data=json.load(open(manifest))
 for r in data:
  p=Path(r['path']);assert p.stat().st_size==r['bytes'] and h(p)==r['sha256'],p
 prior.append(dict(manifest=str(manifest),files=len(data),sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(prior,indent=2)+'\n')
identities=[]
for folder in ('../sealed-metadata-native-baseline','../sealed-metadata-native-development','../sealed-metadata-native-final','../sealed-metadata-native-acceptance','../sealed-metadata-native-acceptance-v2'):
 for p in sorted(Path(folder).rglob('*')):
  if p.is_file():identities.append(dict(path=str(p),bytes=p.stat().st_size,sha256=h(p)))
for p in sorted(record.iterdir()):
 if p.is_file() and not p.name.startswith(('record-run','doc-drift','ledger-','publication','remote-')):
  identities.append(dict(path=str(p),bytes=p.stat().st_size,sha256=h(p)))
(out/'archive-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
(out/'qualification.json').write_text(json.dumps(dict(precode_parent='06c7158a106701873c90a5c0b601e5f883e21721',old_production_changes=[],immutable_precode_controls=117,stable_selected_old_entries=6,new_entries=2,all_linking_before_acceptance=True,failed_test_and_auditor_attempts_retained=True,final_python_test_source='tests/test_hailo_sealed_source_metadata.py',raw_files_pinned=len(identities),work_path_prefix_projection='..',dependency_host_home_projection='<host-home>',prior=prior,whole_repository_or_hosted_ci_pass=False),indent=2)+'\n')
print(json.dumps(dict(raw_files_pinned=len(identities),prior=prior),indent=2))
