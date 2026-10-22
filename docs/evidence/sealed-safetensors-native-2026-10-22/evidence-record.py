from pathlib import Path
import hashlib,json
repo=Path('.');out=repo/'docs/evidence/sealed-safetensors-native-2026-10-22';out.mkdir(exist_ok=False)
record=Path('../sealed-safetensors-native-recording');accept=Path('../sealed-safetensors-native-acceptance-v2');prefix=str(repo.resolve().parent)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def project(source,destination,dependency=False):
 text=Path(source).read_text().replace(prefix,'..')
 if dependency:text=text.replace(str(Path.home()),'<host-home>')
 (out/destination).write_text(text)
for name in ('summary.json','consumer-closure.json','sealed-trace-audit.json','all-legacy-trace-audit.json','entry-scope-audit.json','c-binaries.json','link-before-execution.json','inherited-auxiliary-input-continuity-before-reviewed.json','inherited-auxiliary-input-continuity-after-reviewed.json'):
 project(record/name,name)
project(record/'dependency-inspection.json','dependency-inspection.json',dependency=True)
for src,dst in [('../sealed-safetensors-native-baseline/qualification.json','baseline-qualification.json'),('../sealed-safetensors-native-baseline/controls.json','baseline-controls.json'),('../sealed-safetensors-native-baseline/source-hashes.json','baseline-source-hashes.json'),('../sealed-safetensors-native-baseline/test-input-hashes.json','baseline-test-input-hashes.json'),('../sealed-safetensors-native-final/build-results.json','main-build-results.json'),('../sealed-safetensors-native-final/source-hashes.json','current-source-hashes.json'),('../sealed-safetensors-native-final/unchanged-existing-bodies.json','unchanged-existing-bodies.json'),('../sealed-safetensors-native-supplement/build-results-reviewed.json','supplement-build-results.json'),('../sealed-safetensors-native-supplement/inherited-warning-review.json','inherited-warning-review.json'),(accept/'test-results.json','test-results.json'),(accept/'input-hashes.json','current-test-input-hashes.json'),(accept/'auxiliary-c-source-hashes.json','auxiliary-c-source-hashes.json'),('../sealed-safetensors-native-acceptance/test-results.json','retained-initial-test-results.json')]:project(src,dst)
for row in json.load(open(accept/'test-results.json')):
 suite=row['suite'];project(accept/(suite+'.txt'),suite+'-tests.txt');project(accept/(suite+'-pairs.json'),suite+'-frozen-pairs.json')
for row in json.load(open('../sealed-safetensors-native-acceptance/test-results.json')):
 if row['returncode']:project(Path('../sealed-safetensors-native-acceptance')/(row['suite']+'.txt'),'retained-initial-'+row['suite']+'-tests.txt')
for src,dst in [('../sealed-safetensors-native-development/build-1.txt','retained-development-test-api-build.txt'),('../sealed-safetensors-native-development/supplement-build-run.txt','retained-strict-supplement-refusal.txt'),('../sealed-safetensors-native-development/supplement-review-run.txt','supplement-review.txt'),('../sealed-safetensors-native-supplement/baseline-3.txt','inherited-warning-baseline.txt'),('../sealed-safetensors-native-supplement/current-3.txt','inherited-warning-current.txt'),('../sealed-safetensors-native-acceptance/prepare-initial-run.txt','retained-prepare-refusal.txt'),('../sealed-safetensors-native-recording/audit-new-only-run.txt','retained-audit-split-spacing-refusal.txt'),('../sealed-safetensors-native-acceptance/safetensors-fd/reconstructed-rename-fixtures.json','retained-reconstructed-rename-fixtures.json')]:project(src,dst)
for folder,names in [(record,['audit.py','census.py','dependencies.py','qualified-entry-scope.py','post-verification.py','record.py']),(accept,['prepare.py','run.py','pair-all.py']),(Path('../sealed-safetensors-native-development'),['build-final.py','build-supplement.py','review-supplement.py'])]:
 for name in names:project(folder/name,'evidence-'+name)
prior=[]
for name in ['owned-compiler-native-2026-10-22','sealed-safetensors-contract-2026-10-22','sealed-gguf-source-2026-10-22']:
 manifest=Path('docs/evidence')/name/'archive-identities.json';data=json.load(open(manifest));count=0
 for item in data:
  p=Path(item['path']);assert h(p)==item['sha256'] and p.stat().st_size==item['bytes'],p;count+=1
 prior.append(dict(manifest=str(manifest),files_verified=count,sha256=h(manifest)))
(out/'prior-archive-verification.json').write_text(json.dumps(prior,indent=2)+'\n')
identities=[]
folders=['../sealed-safetensors-native-baseline','../sealed-safetensors-native-development','../sealed-safetensors-native-final','../sealed-safetensors-native-supplement','../sealed-safetensors-native-acceptance','../sealed-safetensors-native-acceptance-v2']
for folder in folders:
 for p in sorted(Path(folder).rglob('*')):
  if p.is_file():identities.append(dict(path=str(p),bytes=p.stat().st_size,sha256=h(p)))
# Recording logs may be extended by publication; pin the completed static
# analyses/scripts here, never the still-open record-run stream.
for p in sorted(record.iterdir()):
 if p.is_file() and not p.name.startswith(('record-run','publication','remote-','doc-drift','ledger-')):
  identities.append(dict(path=str(p),bytes=p.stat().st_size,sha256=h(p)))
(out/'archive-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
qualification=dict(precode_parent='42686ee7f084240d89d2d663a28fe8bd5f898f5c',current_source_identities=666,old_production_sources_modified=['armvegr/safetensors.mojo'],byte_identical_old_parser_conversion_query_bodies=40,precode_native_controls=111,late_frozen_source_controls=4,current_native_entries=117,current_native_builds=117,late_frozen_control_builds=4,c_fault_shim_builds=5,all_linking_before_native_acceptance=True,raw_failed_attempts_retained=True,early_test_expression_and_temporary_rename_fixtures_reconstructed_and_explicitly_labeled=True,published_work_path_prefix_projection='..',published_runtime_home_path_projection='<host-home>',archive_files=len(identities),prior_archive_manifests_verified=len(prior),no_old_python_test_modified=True,whole_repository_or_hosted_ci_pass=False)
(out/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n')
print(json.dumps(dict(archive_files=len(identities),prior=prior),indent=2))
