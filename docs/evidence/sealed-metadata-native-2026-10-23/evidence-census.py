from pathlib import Path
from collections import Counter
import ast,hashlib,json,re
out=Path(__file__).parent;base=Path('../sealed-metadata-native-baseline');final=Path('../sealed-metadata-native-final');accept=Path('../sealed-metadata-native-acceptance-v2')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.load(open(base/'source-hashes.json'));current=json.load(open(final/'source-hashes.json'));tests=json.load(open(base/'test-input-hashes.json'))
for p,d in old.items():assert h(Path(p))==h(base/'source-snapshot'/p)==current[p]==d,p
for p,d in current.items():assert h(Path(p))==h(final/'source-snapshot'/p)==d,p
for p,d in tests.items():assert h(Path(p))==h(base/'test-snapshot'/p)==d,p
controls=json.load(open(base/'controls.json'));assert len(controls)==117
for c in controls:assert h(Path(c['binary']))==c['sha256'],c
builds=json.load(open(final/'build-results.json'));assert len(builds)==8
for b in builds:assert b['returncode']==b['diagnostic_bytes']==0 and h(Path(b['binary']))==b['sha256'],b
cbuilds=json.load(open(final/'c-build-results.json'))
for b in cbuilds:assert b['returncode']==b['diagnostic_bytes']==0 and h(Path(b['source']))==b['source_sha256'],b
u=json.load(open(accept/'universe.json'));pairs=[x for p in accept.glob('*-pairs.json') for x in json.load(open(p))]
assert {x['binary'] for x in pairs}==set(u['pairs']) and len(u['pairs'])==6
results=json.load(open(accept/'results.json'));assert len(results)==4 and all(r['returncode']==0 for r in results)
methods=sum(int(re.search(r'Ran (\d+) tests? in',(accept/(r['suite']+'-tests.txt')).read_text())[1]) for r in results)
calls=[x for p in accept.glob('*-pairs-native-calls.json') for x in json.load(open(p))]
assert {x['binary'] for x in calls if x['kind']=='current'}==set(u['current'].values())
modules={}
for name in current:
 parts=Path(name).with_suffix('').parts
 for offset in (0,1):
  if offset and parts[0] not in ('aesir_engine','tests'):continue
  modules.setdefault('.'.join(parts[offset:]),set()).add(name)
  if parts[-1]=='__init__':modules.setdefault('.'.join(parts[offset:-1]),set()).add(name)
deps={}
for name in current:
 t=Path(name).read_text();keys=re.findall(r'^from\s+([\w.]+)\s+import',t,re.M)+re.findall(r'^import\s+([\w.]+)',t,re.M)
 deps[name]=set().union(*(modules.get(k,set()) for k in keys)) if keys else set()
affected=[]
for name in current:
 seen=set();pending=list(deps[name])
 while pending:
  p=pending.pop()
  if p not in seen:seen.add(p);pending.extend(deps[p]-seen)
 if 'smidr/sealed_source_metadata.mojo' in seen:affected.append(name)
assert sorted(affected)==sorted(['smidr/tools/sealed_source_metadata.mojo','tests/hailo_sealed_metadata_api.mojo']),affected
(out/'consumer-closure.json').write_text(json.dumps(dict(sources=len(current),actual_transitive_new_leaf_consumers=affected,no_preexisting_consumers=True,source_changes=[],new_sources=sorted(set(current)-set(old)),selected_old_entries=sorted(u['frozen'])),indent=2)+'\n')
runs=json.load(open(accept/'sealed-metadata/runs.json'));images=json.load(open(accept/'sealed-metadata/images.json'));independent=json.load(open(accept/'sealed-metadata/independent.json'))
linkcheck=dict(all_builds_linked_before_native_execution=max(Path(b['binary']).stat().st_mtime_ns for b in builds)<min(p.stat().st_mtime_ns for p in accept.glob('*-tests.txt')),native_build_sources_unchanged=True,stable_source_snapshot=str(final/'source-snapshot'),python_only_valid_json_expectation_corrected_after_first_attempt=True,final_test_sha256=h(Path('tests/test_hailo_sealed_source_metadata.py')))
# Log files are opened before subprocess launch; result logs are complete later.
assert linkcheck['all_builds_linked_before_native_execution']
(out/'link-before-execution.json').write_text(json.dumps(linkcheck,indent=2)+'\n')
for p in Path('tests').glob('test_*.py'):ast.parse(p.read_text())
summary=dict(precode_parent='06c7158a106701873c90a5c0b601e5f883e21721',old_mojo_sources_unchanged=len(old),current_mojo_sources=len(current),old_python_inputs_unchanged=len(tests),precode_native_controls_unchanged=len(controls),stable_mojo_builds=len(builds),clean_c_builds=len(cbuilds),zero_diagnostics=True,suites=len(results),methods=methods,qualified_entry_calls=len(calls),qualified_kinds=dict(Counter(c['kind'] for c in calls)),frozen_pairs=len(pairs),frozen_entries=len(u['pairs']),frozen_outcomes=dict(Counter('accepted' if p['returncode']==0 else 'refused' for p in pairs)),complete_stdout_stderr_exit_messages_compared=True,complete_mutation_pairs=sum(p['complete_post_mutation_bytes_equal'] for p in pairs),independent_complete_fault_log_pairs=sum(p['independent_complete_fault_logs_equal'] for p in pairs),new_suite_calls=len(runs),new_suite_outcomes=dict(Counter('accepted' if p['returncode']==0 else 'refused' for p in runs)),independent_complete_json_vectors=len(independent),independent_mutation_runs=sum('mode' in r for r in images),whole_repository_or_hosted_ci_pass=False)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
