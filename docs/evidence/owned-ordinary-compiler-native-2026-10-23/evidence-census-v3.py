from pathlib import Path
from collections import Counter
import hashlib,json,re
base=Path('../owned-ordinary-compiler-native-baseline');final=Path('../owned-ordinary-compiler-native-final-v2');accept=Path('../owned-ordinary-compiler-native-acceptance-v3');out=Path('../owned-ordinary-compiler-native-recording');out.mkdir(exist_ok=True)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.load(open(base/'source-hashes.json'));cur=json.load(open(final/'source-hashes.json'));inputs=json.load(open(base/'test-input-hashes.json'))
for p,d in old.items():assert h(Path(p))==h(base/'source-snapshot'/p)==cur[p]==d,p
for p,d in cur.items():assert h(Path(p))==h(final/'source-snapshot'/p)==d,p
for p,d in inputs.items():assert h(Path(p))==h(base/'test-snapshot'/p)==d,p
for p,d in json.load(open(accept/'test-input-hashes.json')).items():assert h(Path(p))==h(accept/'test-snapshot'/p)==d,p
controls=json.load(open(base/'controls.json'));assert len(controls)==124
for c in controls:assert h(Path(c['binary']))==c['sha256'],c
builds=json.load(open(final/'build-results.json'));assert len(builds)==30
for b in builds:assert b['returncode']==b['diagnostic_bytes']==0 and h(Path(b['binary']))==b['sha256'],b
cbuilds=json.load(open(final/'c-build-results.json'))
for b in cbuilds:assert b['returncode']==b['diagnostic_bytes']==0 and h(Path(b['source']))==b['source_sha256'] and h(Path(b['binary']))==b['binary_sha256'],b
aux=json.load(open(accept/'auxiliary-identities.json'))
for a in aux:
 assert h(Path(a['path']))==a['sha256'],a
 if 'supporting_current_source_sha256' in a:assert h(Path(a['source']))==a['supporting_current_source_sha256'],a
u=json.load(open(accept/'universe.json'));pairs=[x for p in accept.glob('*-pairs.json') for x in json.load(open(p))];assert {r['binary'] for r in pairs}==set(u['pairs']) and len(u['pairs'])==28
results=json.load(open(accept/'results.json'));assert len(results)==14 and all(r['returncode']==0 for r in results),results
methods=sum(int(re.search(r'Ran (\d+) tests? in',(accept/(r['suite']+'-tests.txt')).read_text())[1]) for r in results)
calls=[x for p in accept.glob('*-pairs-native-calls.json') for x in json.load(open(p))];assert {r['binary'] for r in calls if r['kind']=='current'}==set(u['current'].values())
# Every auxiliary ELF invoked through subprocess.run must be identified, with
# full executable digest and an explicit source identity (never filename alone).
outputs=[r for p in accept.glob('*-full-outputs.json') for r in json.load(open(p))]
assert len(outputs)==len(calls)+len(pairs),(len(outputs),len(calls),len(pairs))
for record in outputs:
 for field in ('stdout','stderr'):
  v=record[field];p=Path(v['path']);assert p.stat().st_size==v['bytes'] and h(p)==v['sha256'],p
new=json.load(open(accept/'owned-ordinary-compiler/summary.json'));mutations=json.load(open(accept/'owned-ordinary-compiler/mutations.json'));faults=json.load(open(accept/'owned-ordinary-compiler/faults.json'))
summary=dict(parent='fb77664580adac1f11ade87bdf8d1951068936bd',old_mojo_sources_unchanged=len(old),current_mojo_sources=len(cur),old_python_inputs_unchanged=len(inputs),current_python_inputs=len(json.load(open(accept/'test-input-hashes.json'))),precode_controls_unchanged=len(controls),qualified_auxiliary_inputs_unchanged=len(aux),stable_current_mojo_builds=len(builds),clean_c_builds=len(cbuilds),all_stable_linking_before_native_acceptance=True,suites=len(results),methods=methods,qualified_entry_calls=len(calls),qualified_entry_kinds=dict(Counter(r['kind'] for r in calls)),complete_frozen_pairs=len(pairs),frozen_entries=len(u['pairs']),frozen_outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in pairs)),complete_stdout_stderr_exit_handled_messages_equal=True,full_native_outputs_retained=len(outputs),full_stdout_stderr_files=len(outputs)*2,complete_file_mutation_pairs=sum(r['complete_post_mutation_bytes_equal'] for r in pairs),complete_directory_tree_pairs=sum(r.get('complete_directory_rename_equal',False) for r in pairs),complete_changed_directory_tree_pairs=sum(r.get('complete_directory_preimages')!=r.get('complete_directory_postimages') for r in pairs),explicit_root_rename_pairs=sum(r.get('complete_directory_rename_equal',False) and r['arguments'][0]=='rename' and r['binary']==u['current']['tests/hailo_source_root_api.mojo'] for r in pairs),independent_fault_log_pairs=sum(r['independent_complete_fault_logs_equal'] for r in pairs),new_suite=new,independent_mutation_runs=len(mutations),independent_fault_runs=len(faults),whole_repository_or_hosted_ci_pass=False)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
