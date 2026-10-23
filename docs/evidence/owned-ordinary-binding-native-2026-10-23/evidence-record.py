from pathlib import Path
import hashlib,json,os
repo=Path('.');out=repo/'docs/evidence/owned-ordinary-binding-native-2026-10-23';out.mkdir(exist_ok=False)
record=Path('../owned-ordinary-binding-native-recording');accept=Path('../owned-ordinary-binding-native-acceptance-v3');final=Path('../owned-ordinary-binding-native-final-v3');dev=Path('../owned-ordinary-binding-native-development');prefix=str(repo.resolve().parent)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def project(source,name,dependency=False):
 text=Path(source).read_text().replace(prefix,'..')
 if dependency:text=text.replace(str(Path.home()),'<host-home>')
 (out/name).write_text(text)
for name in ('summary.json','other-trace-audit.json','supporting-input-identities.json','retained-first-audit-refusal.txt','retained-unreturned-worker-audit-refusal.txt'):project(record/name,name)
binding_audit=json.load(open(record/'binding-trace-audit.json'))
for row in binding_audit['rows']:row.pop('phases',None)
(out/'binding-trace-audit.json').write_text((json.dumps(binding_audit,indent=2)+'\n').replace(prefix,'..'))
project(record/'dependency-inspection.json','dependency-inspection.json',True)
project(accept/'link-before-execution.json','link-before-execution.json')
for name in ('qualification.json','source-hashes.json','test-input-hashes.json','controls.json'):project(Path('../owned-ordinary-binding-native-baseline')/name,'baseline-'+name)
for name in ('build-results.json','c-build-results.json','source-hashes.json','test-input-hashes.json','consumer-closure.json'):project(final/name,'current-'+name)
project(accept/'results.json','test-results.json')
for row in json.load(open(accept/'results.json')):project(accept/(row['suite']+'-tests.txt'),row['suite']+'-tests.txt')
project(accept/'owned-binding/summary.json','binding-summary.json')
# Complete stdout/stderr, fixture bytes, component words, pairs, faults and
# mutations remain in raw archives, pinned by identities below. Public records
# retain complete audit decisions rather than duplicating large raw buffers.
for folder,names in [(dev,['build-final.py','build-final-v2.py','build-final-v3.py','build-supporting-seam.py','prepare-acceptance.py','prepare-v2.py','prepare-v3.py','run-acceptance.py','run-acceptance-v2.py','run-acceptance-v3.py','audit.py','audit-v2.py','audit-v3.py','audit-final.py','logical.py','census.py','census-v2.py','census-v3.py','census-final.py','dependencies-v2.py','supporting-identities.py','supporting-identities-final.py','record.py','retained-first-build-note.json']), (accept,['pair-all.py','universe.json','jobs.json'])]:
 for name in names:project(folder/name,'evidence-'+name)
for folder,names in [(dev,['tool-build.txt','api-build.txt','acceptance-run.txt']), (Path('../owned-ordinary-binding-native-acceptance'),['sealed-collection-tests.txt','ordinary_projection_schema-tests.txt','owned-binding-tests.txt'])]:
 for name in names:project(folder/name,'retained-initial-'+name)
prior=[]
for name in ('sealed-collection-native-2026-10-23','owned-ordinary-binding-contract-2026-10-23'):
 manifest=Path('docs/evidence')/name/'archive-identities.json';items=json.load(open(manifest))
 for item in items:
  p=Path(item['path']);assert p.stat().st_size==item['bytes'] and h(p)==item['sha256'],p
  if item.get('kind')=='symlink':
   target=str(p.readlink());assert target.replace(prefix,'..')==item['link_target'] or target==item['link_target'],(p,target,item['link_target'])
 prior.append(dict(manifest=str(manifest),files=len(items),sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(prior,indent=2)+'\n')
folders=['../owned-ordinary-binding-native-baseline','../owned-ordinary-binding-native-development','../owned-ordinary-binding-native-final','../owned-ordinary-binding-native-final-v2','../owned-ordinary-binding-native-final-v3','../owned-ordinary-binding-native-acceptance','../owned-ordinary-binding-native-acceptance-v2','../owned-ordinary-binding-native-acceptance-v3']
files=[p for folder in folders for p in sorted(Path(folder).rglob('*')) if p.is_file()]
files += [p for p in sorted(record.rglob('*')) if p.is_file() and not p.name.startswith(('record-run','doc-drift','ledger-','publication','remote-'))]
identities=[]
for p in files:
 row=dict(path=os.path.relpath(p,repo),bytes=p.stat().st_size,sha256=h(p))
 if p.is_symlink():
  target=str(p.readlink());row.update(kind='symlink',link_target=target.replace(prefix,'..'),link_target_sha256=hashlib.sha256(target.encode()).hexdigest())
 identities.append(row)
(out/'archive-identities.json').write_text(json.dumps(identities,separators=(',',':'))+'\n')
(out/'qualification.json').write_text(json.dumps(dict(parent='9a0a91ea141480ea905da4ef5dbf5a3eb4dd4286',old_production_changes=[],stable_current_mojo_builds=26,current_clean_c_builds=9,retained_first_and_second_builds=True,immutable_precode_controls=122,selected_current_control_pairs=24,all_stable_linking_before_native_acceptance=True,failed_build_test_runner_and_auditor_attempts_retained=True,native_production_leaf_unchanged_after_initial_clean_module_compile=True,archive_files=len(identities),work_path_projection='..',dependency_home_projection='<host-home>',prior=prior,whole_repository_or_hosted_ci_pass=False),indent=2)+'\n')
print(json.dumps(dict(archive_files=len(identities),prior=prior),indent=2))
