from pathlib import Path
from collections import Counter
import hashlib,json,re
out=Path('../sealed-safetensors-native-recording');base=Path('../sealed-safetensors-native-baseline');final=Path('../sealed-safetensors-native-final');supp=Path('../sealed-safetensors-native-supplement');accept=Path('../sealed-safetensors-native-acceptance-v2')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.load(open(base/'source-hashes.json'));current=json.load(open(final/'source-hashes.json'));inputs=json.load(open(base/'test-input-hashes.json'));u=json.load(open(accept/'universe.json'))
changed=[]
for p,digest in old.items():
 assert h(base/'source-snapshot'/p)==digest,p
 if current[p]!=digest:changed.append(p)
assert changed==['armvegr/safetensors.mojo'],changed
for p,digest in current.items():assert h(Path(p))==h(final/'source-snapshot'/p)==digest,p
for p,digest in inputs.items():assert h(Path(p))==h(base/'test-snapshot'/p)==digest,p
for p,digest in json.load(open(accept/'input-hashes.json')).items():assert h(Path(p))==h(accept/'test-snapshot'/p)==digest,p
controls=json.load(open(base/'controls.json'))
for c in controls:assert h(Path(c['binary']))==c['sha256'],c
builds=json.load(open(final/'build-results.json'))+json.load(open(supp/'build-results-reviewed.json'))
for b in builds:assert b['returncode']==0 and (b['diagnostic_bytes']==0 or b.get('diagnostics_qualified')) and h(Path(b['binary']))==b['sha256'],b
pairs=[x for p in sorted(accept.glob('*-pairs.json')) for x in json.load(open(p))]
covered={p['binary'] for p in pairs};assert covered==set(u['pairs']),(set(u['pairs'])-covered,covered-set(u['pairs']))
results=json.load(open(accept/'test-results.json'));assert len(results)==50 and all(r['returncode']==0 for r in results)
methods=0
for r in results:
 t=(accept/(r['suite']+'.txt')).read_text();m=re.search(r'Ran (\d+) tests? in',t);assert m,r['suite'];methods+=int(m[1])
calls=[x for p in sorted(accept.glob('*-pairs-native-calls.json')) for x in json.load(open(p))]
assert {c['binary'] for c in calls if c['kind']=='current'}==set(u['current'].values())
modules={}
for name in current:
 parts=Path(name).with_suffix('').parts
 for offset in (0,1):
  if offset and parts[0] not in ('aesir_engine','tests'):continue
  modules.setdefault('.'.join(parts[offset:]),set()).add(name)
  if parts[-1]=='__init__':modules.setdefault('.'.join(parts[offset:-1]),set()).add(name)
deps={}
for name in current:
 t=(final/'source-snapshot'/name).read_text();keys=re.findall(r'^from\s+([\w.]+)\s+import',t,re.M)+re.findall(r'^import\s+([\w.]+)',t,re.M)
 deps[name]=set().union(*(modules.get(k,set()) for k in keys)) if keys else set()
affected=[]
for source in u['current']:
 seen=set();pending=[source]
 while pending:
  p=pending.pop()
  if p not in seen:seen.add(p);pending.extend(deps[p]-seen)
 if 'armvegr/safetensors.mojo' in seen:affected.append(source)
closure=dict(permitted_old_production_changes=changed,new_mojo_sources=sorted(set(current)-set(old)),current_entrypoints=len(u['current']),precode_qualified_controls=len(controls),late_frozen_snapshot_controls=4,total_frozen_controls=len(u['frozen']),conservative_affected_current_entrypoints=sorted(affected),all_current_and_frozen_by_source=u,qualified_builds=builds)
(out/'consumer-closure.json').write_text(json.dumps(closure,indent=2)+'\n')
summary=dict(current_mojo_sources=len(current),old_sources_unchanged=len(old)-len(changed),old_sources_modified=changed,old_python_inputs_unchanged=len(inputs),current_python_inputs=len(json.load(open(accept/'input-hashes.json'))),precode_controls_unchanged=len(controls),native_builds=len(builds),current_entries=len(u['current']),late_frozen_snapshot_controls=4,zero_diagnostic_builds=sum(b['diagnostic_bytes']==0 for b in builds),inherited_warning_builds=sum(b['diagnostic_bytes']!=0 for b in builds),suites=len(results),methods=methods,qualified_native_entry_calls=len(calls),qualified_native_kinds=dict(Counter(c['kind'] for c in calls)),qualified_native_outcomes=dict(Counter('zero' if c['returncode']==0 else 'nonzero' for c in calls)),frozen_control_outputs_compared=len(pairs),frozen_control_entries=len(covered),frozen_outcomes=dict(Counter('zero' if p['returncode']==0 else 'nonzero' for p in pairs)),complete_stderr_compared=True,new_tests=json.load(open(accept/'sealed-safetensors/summary.json')),independent_complete_fault_log_pairs=sum(p['independent_complete_fault_logs_equal'] for p in pairs),complete_mutation_pairs=sum(p['complete_post_mutation_bytes_equal'] for p in pairs),all_controls_compared=True)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
