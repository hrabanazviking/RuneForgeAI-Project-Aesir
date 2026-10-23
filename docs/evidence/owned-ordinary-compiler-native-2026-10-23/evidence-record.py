from pathlib import Path
import hashlib,json,os
repo=Path('.');out=repo/'docs/evidence/owned-ordinary-compiler-native-2026-10-23';out.mkdir(exist_ok=False)
record=Path('../owned-ordinary-compiler-native-recording');accept=Path('../owned-ordinary-compiler-native-acceptance-v4');final=Path('../owned-ordinary-compiler-native-final-v2');dev=Path('../owned-ordinary-compiler-native-development');base=Path('../owned-ordinary-compiler-native-baseline');prefix=str(repo.resolve().parent)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def project(source,name,dependency=False):
 text=Path(source).read_text().replace(prefix,'..').replace(str(Path.home()),'<host-home>')
 if dependency:text=text.replace(str(Path.home()),'<host-home>')
 (out/name).write_text(text)
for name in ('summary.json','other-trace-audit.json','supporting-input-identities.json','compiler-identity.json'):project(record/name,name)
audit=json.load(open(record/'compiler-trace-audit.json'))
for row in audit['rows']:row.pop('phases',None)
(out/'compiler-trace-audit.json').write_text((json.dumps(audit,indent=2)+'\n').replace(prefix,'..'))
project(record/'dependency-inspection.json','dependency-inspection.json',True)
for name in ('qualification.json','source-hashes.json','test-input-hashes.json','controls.json'):project(base/name,'baseline-'+name)
for name in ('build-results.json','c-build-results.json','source-hashes.json','consumer-closure.json'):project(final/name,'current-'+name)
project(accept/'test-input-hashes.json','current-test-input-hashes.json')
project(accept/'results.json','test-results.json');project(accept/'owned-ordinary-compiler/summary.json','compiler-summary.json')
for row in json.load(open(accept/'results.json')):project(accept/(row['suite']+'-tests.txt'),row['suite']+'-tests.txt')
for p in sorted(dev.glob('*.py')):project(p,'evidence-'+p.name)
for p in sorted(dev.glob('*.json')):project(p,'evidence-'+p.name)
for p in sorted(dev.glob('*build*.txt')):project(p,'retained-'+p.name)
for folder,suffix in [(Path('../owned-ordinary-compiler-native-acceptance'),'v1'),(Path('../owned-ordinary-compiler-native-acceptance-v2'),'v2')]:project(folder/'owned-ordinary-compiler-tests.txt','retained-'+suffix+'-compiler-tests.txt')
project(Path('../owned-ordinary-compiler-native-acceptance-v3')/'owned-binding-tests.txt','retained-v3-binding-tests.txt')
for name in ('pair-all.py','jobs.json','universe.json','link-before-execution.json'):project(accept/name,name)
prior=[]
for name in ('owned-ordinary-binding-native-2026-10-23','owned-ordinary-compiler-contract-2026-10-23'):
 manifest=Path('docs/evidence')/name/'archive-identities.json';items=json.load(open(manifest))
 for item in items:
  p=Path(item['path']);assert p.stat().st_size==item['bytes'] and h(p)==item['sha256'],p
 prior.append(dict(manifest=str(manifest),files=len(items),sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(prior,indent=2)+'\n')
folders=[base,dev,Path('../owned-ordinary-compiler-native-final'),final,Path('../owned-ordinary-compiler-native-acceptance'),Path('../owned-ordinary-compiler-native-acceptance-v2'),Path('../owned-ordinary-compiler-native-acceptance-v3'),accept]
files=[p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
files += [p for p in sorted(record.rglob('*')) if p.is_file() and not p.name.startswith(('record-run','doc-drift','ledger-','publication','remote-'))]
identities=[]
for p in files:
 row=dict(path=os.path.relpath(p,repo),bytes=p.stat().st_size,sha256=h(p))
 if p.is_symlink():
  target=str(p.readlink());row.update(kind='symlink',link_target=target.replace(prefix,'..'),link_target_sha256=hashlib.sha256(target.encode()).hexdigest())
 identities.append(row)
(out/'archive-identities.json').write_text(json.dumps(identities,separators=(',',':'))+'\n')
(out/'qualification.json').write_text(json.dumps(dict(parent='fb77664580adac1f11ade87bdf8d1951068936bd',old_production_changes=[],stable_current_mojo_builds=30,current_clean_c_builds=9,immutable_precode_controls=124,selected_current_control_pairs=28,all_stable_linking_before_native_acceptance=True,selected_old_entries_rebuilt_in_this_slice_with_exact_transitive_sources_unchanged=True,both_new_consumers_rebuilt_from_final_source=True,test_expectation_and_oracle_failures_retained=True,production_unchanged_after_stable_build=True,archive_files=len(identities),work_path_projection='..',dependency_home_projection='<host-home>',prior=prior,whole_repository_or_hosted_ci_pass=False),indent=2)+'\n')
print(json.dumps(dict(archive_files=len(identities),prior=prior),indent=2))
