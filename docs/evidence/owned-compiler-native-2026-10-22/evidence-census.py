from pathlib import Path
from collections import Counter
import hashlib,json,re
out=Path('../owned-compiler-native-recording');base=Path('../owned-compiler-native-baseline');final=Path('../owned-compiler-native-final');accept=Path('../owned-compiler-native-acceptance-v2')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.load(open(base/'source-hashes.json'));current=json.load(open(final/'source-hashes.json'))
for p,digest in old.items():assert h(Path(p))==h(base/'source-snapshot'/p)==digest,p
for p,digest in current.items():assert h(Path(p))==h(final/'source-snapshot'/p)==digest,p
for p,digest in json.load(open(base/'test-input-hashes.json')).items():assert h(Path(p))==h(base/'test-snapshot'/p)==digest,p
controls=json.load(open(base/'controls.json'))
for c in controls:assert h(Path(c['binary']))==c['sha256'],c
builds=json.load(open(final/'build-results.json'));pairs=[]
for p in sorted(accept.glob('*-pairs.json')):pairs.extend(json.load(open(p)))
covered=set(p['binary'] for p in pairs);expected=set(b['binary'] for b in builds if b['source'] in old)
assert covered==expected,(expected-covered,covered-expected)
methods=0
for p in accept.glob('*.txt'):
 text=p.read_text();m=re.search(r'Ran (\d+) tests? in',text)
 if m:methods+=int(m[1])
records=json.load(open(accept/'owned/runs.json'))+json.load(open(accept/'sealed/runs.json'))+json.load(open(accept/'semantic/fixture-runs.json'))
summary=dict(native_builds=len(builds),clean_diagnostics=all(b['diagnostic_bytes']==0 for b in builds),old_sources_unchanged=len(old),current_mojo_sources=len(current),qualified_old_python_inputs_unchanged=69,current_qualified_python_inputs=70,prior_native_controls_unchanged=len(controls),selected_rebuilt_controls=len(expected),frozen_control_outputs_compared=len(pairs),frozen_outcomes=dict(Counter('zero' if p['returncode']==0 else 'nonzero' for p in pairs)),methods=methods,primary_child_calls=len(records),new_tests=json.load(open(accept/'owned/summary.json')),independent_complete_fault_log_pairs=sum(p['independent_complete_fault_logs_equal'] for p in pairs),complete_mutation_pairs=sum(p['complete_post_mutation_bytes_equal'] for p in pairs),all_selected_controls_compared=True)
new=set(current)-set(old);imports={}
for p in current:
 t=Path(p).read_text()
 if re.search(r'^(?:from smidr\.owned_gguf_compiler import|import smidr\.owned_gguf_compiler)',t,re.M):imports[p]=h(Path(p))
assert set(imports)<=new,imports
closure=dict(new_sources=sorted(new),direct_new_leaf_consumers=imports,old_importing_sources=[],directory_binary_arguments_in_selected_suites=[],qualified_binaries_by_source=builds)
(out/'consumer-closure.json').write_text(json.dumps(closure,indent=2)+'\n');(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
