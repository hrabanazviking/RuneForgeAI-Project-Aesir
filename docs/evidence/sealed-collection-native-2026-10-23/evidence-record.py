from pathlib import Path
import hashlib,json,os
repo=Path('.');out=repo/'docs/evidence/sealed-collection-native-2026-10-23';out.mkdir(exist_ok=False)
record=Path('../sealed-collection-native-recording');accept=Path('../sealed-collection-native-acceptance-v3');final=Path('../sealed-collection-native-final-v2');development=Path('../sealed-collection-native-development');prefix=str(repo.resolve().parent)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def project(source,name,dependency=False):
 text=Path(source).read_text().replace(prefix,'..')
 if dependency:text=text.replace(str(Path.home()),'<host-home>')
 (out/name).write_text(text)
for name in ('summary.json','consumer-closure.json','collection-trace-audit.json','other-trace-audit.json','link-before-execution.json'):
 project(record/name,name)
project(record/'dependency-inspection.json','dependency-inspection.json',True)
for name in ('qualification.json','source-hashes.json','test-input-hashes.json','controls.json'):
 project(Path('../sealed-collection-native-baseline')/name,'baseline-'+name)
for name in ('build-results.json','c-build-results.json','source-hashes.json','test-input-hashes.json','prior-auxiliary-identities.json'):
 project(final/name,'current-'+name)
project(accept/'results.json','test-results.json')
for row in json.load(open(accept/'results.json')):
 for suffix in ('-tests.txt','-pairs.json','-pairs-native-calls.json'):
  name=row['suite']+suffix;project(accept/name,name)
for name in ('summary.json','runs.json','fixtures.json','mutations.json'):
 project(accept/'sealed-collection'/name,'collection-'+name)
for source,name in [(Path('../sealed-collection-native-acceptance/sealed-collection-tests.txt'),'retained-initial-new-test-refusal.txt'),(Path('../sealed-collection-native-acceptance-v2/results.json'),'retained-second-test-results.json'),(record/'census.txt','census-run.txt'),(record/'audit-first.txt','retained-root-policy-audit-refusal.txt'),(record/'audit-policy-reviewed.txt','initial-policy-reviewed-audit.txt'),(development/'inspector-build-0.txt','retained-argv-type-build-refusal.txt')]:project(source,name)
for folder,names in [(record,['audit.py','logical.py','census.py','dependencies.py','record.py']),
 (development,['build-final.py','build-final-v2.py','prepare-acceptance.py','prepare-v3.py','run-acceptance-v3.py']),
 (accept,['pair-all.py','universe.json','jobs.json'])]:
 for name in names:project(folder/name,'evidence-'+name)
prior=[]
for name in ('sealed-metadata-native-2026-10-23','sealed-collection-contract-2026-10-23','sealed-safetensors-native-2026-10-22'):
 manifest=Path('docs/evidence')/name/'archive-identities.json';items=json.load(open(manifest))
 for item in items:
  p=Path(item['path']);assert p.stat().st_size==item['bytes'] and h(p)==item['sha256'],p
 prior.append(dict(manifest=str(manifest),files=len(items),sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(prior,indent=2)+'\n')
identities=[]
folders=['../sealed-collection-native-baseline','../sealed-collection-native-development','../sealed-collection-native-final','../sealed-collection-native-final-v2','../sealed-collection-native-acceptance','../sealed-collection-native-acceptance-v2','../sealed-collection-native-acceptance-v3']
files=[p for folder in folders for p in sorted(Path(folder).rglob('*')) if p.is_file()]
files += [p for p in sorted(record.iterdir()) if p.is_file() and not p.name.startswith(('record-run','doc-drift','ledger-','publication','remote-'))]
for p in files:
 row=dict(path=os.path.relpath(p,repo),bytes=p.stat().st_size,sha256=h(p))
 if p.is_symlink():row.update(kind='symlink',link_target=str(p.readlink()).replace(prefix,'..'),link_target_sha256=hashlib.sha256(str(p.readlink()).encode()).hexdigest())
 identities.append(row)
(out/'archive-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
(out/'qualification.json').write_text(json.dumps(dict(parent='d218e01955651c338bfec558b20416eaafabc7f5',old_production_changes=[],stable_current_mojo_builds=14,retained_first_stable_mojo_builds=14,current_clean_c_builds=6,retained_first_clean_c_builds=6,immutable_precode_primary_controls=119,additional_historical_root_control=1,selected_current_control_pairs=12,all_stable_linking_before_each_native_acceptance=True,failed_build_test_auditor_and_entry_routing_attempts_retained=True,archive_files=len(identities),work_path_projection='..',dependency_home_projection='<host-home>',prior=prior,whole_repository_or_hosted_ci_pass=False),indent=2)+'\n')
print(json.dumps(dict(archive_files=len(identities),prior=prior),indent=2))
