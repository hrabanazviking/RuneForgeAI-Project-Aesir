# Record only completed final acceptance; never execute before every gate below.
from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path.cwd();work=root.parent;build=work/'dynamic-graph-final';accept=work/'dynamic-graph-acceptance';reg=work/'dynamic-graph-regressions'
hashof=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
checks=json.loads((accept/'test-results.json').read_text());assert len(checks)==5 and all(r['returncode']==0 for r in checks)
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==70 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
for r in rows:assert hashof(r['binary'])==r['sha256']
source=json.loads((build/'source-hashes.json').read_text());assert len(source)==208
for n,h in source.items():assert hashof(root/n)==h
inputs=json.loads((build/'final-test-input-hashes.json').read_text());assert len(inputs)>=74
for n,h in inputs.items():assert hashof(root/n)==h
extra=json.loads((build/'additional-unchanged-tracked-mojo.json').read_text());assert len(extra['files'])==426
for n,r in extra['files'].items():assert hashof(root/n)==r['sha256']
oracles=json.loads((build/'oracle-and-control-input-hashes.json').read_text())
for n,h in oracles.items():assert hashof(root/n)==h,n
controls=json.loads((work/'dynamic-graph-baseline/controls.json').read_text());assert len(controls)==67
for r in controls:assert hashof(r['binary'])==r['sha256']
regresults=json.loads((reg/'test-results.json').read_text());assert len(regresults)==24 and all(r['returncode']==0 for r in regresults)
suites=[]
for r in regresults:
 name=r['suite'];log=(reg/(name+'-test.txt')).read_text();assert '\nOK\n' in log,(name,log)
 methods=int(re.search(r'Ran (\d+) tests?',log)[1]);files=list((reg/name).glob('*runs.json'));assert len(files)==1,(name,files)
 calls=json.loads(files[0].read_text());assert isinstance(calls,list)
 suites.append(dict(suite=name,methods=methods,recorded_primary_calls=len(calls),returncode=0))
assert sum(s['methods'] for s in suites)==161 and sum(s['recorded_primary_calls'] for s in suites)==6387,suites
context=json.loads((accept/'context-result.json').read_text());history=json.loads((accept/'history/runs.json').read_text());graph=json.loads((accept/'graph/runs.json').read_text())
assert (context['methods'],context['failures'],context['errors'],context['native_child_calls'])==(4,0,0,122)
assert (history['methods'],history['failures'],history['errors'],history['native_child_calls'])==(4,0,0,244)
assert len(graph)==306 and sum(r['returncode']==0 for r in graph)==171 and sum(r['returncode']!=0 for r in graph)==135
log=(accept/'graph-test.txt').read_text();assert 'Ran 4 tests' in log and '\nOK\n' in log
trace=json.loads((accept/'graph/trace-audit.json').read_text());assert (trace['traces'],trace['fixture_opens'],trace['fixture_closes'],trace['weight_header_reads'],trace['fixture_files'])==(8,19,19,20,121)
gguf=json.loads((accept/'gguf-owner/audit.json').read_text());assert gguf['native_calls']==2 and gguf['readonly_whole_file_mappings']==1 and gguf['matching_unmaps']==1
post=json.loads((accept/'additional-frozen/test-results.json').read_text());assert len(post)==2 and all(r['returncode']==0 for r in post)
paired=[]
for p in [*reg.glob('*-frozen-pairs.json'),*(accept/'additional-frozen').glob('*-frozen-pairs.json')]:
 d=json.loads(p.read_text());paired.append(dict(path=str(p),sha256=hashof(p),complete_stdout_pairs=d['complete_stdout_pairs'],handled_diagnostic_pairs=d['handled_diagnostic_pairs'],binary_count=d['binary_count'],binaries=sorted(set(str(Path(r['binary']).resolve()) for r in d['calls'])),diagnostic_binaries=sorted(set(str(Path(r['binary']).resolve()) for r in d['diagnostics']))))
success=set(n for r in paired for n in r['binaries']);covered=success|set(n for r in paired for n in r['diagnostic_binaries']);assert len(covered)==67 and len(success)==66,(len(covered),len(success),covered)
summary=dict(pre_code_contract='68ea3ffd9f9bfdfd171d5f9740177ac5e8d67534',relevant_mojo_sources=208,additional_unchanged_tracked_mojo_sources=426,zero_diagnostic_builds=70,oracle_and_baseline_input_files=len(oracles),frozen_controls_unchanged=67,primary_suites=27,primary_methods=173,recorded_primary_native_calls=7059,new_graph_methods=4,new_graph_native_calls=306,new_graph_accepted=171,new_graph_expected_refusals=135,new_graph_mutation_fields=84,complete_frozen_stdout_pairs=sum(r['complete_stdout_pairs'] for r in paired),frozen_handled_diagnostic_pairs=sum(r['handled_diagnostic_pairs'] for r in paired),unique_frozen_controls_with_complete_stdout_comparisons=len(covered),unique_successful_frozen_controls=len(success),mutation_only_frozen_controls=sorted(covered-success),additional_repeated_context_history_methods=8,additional_repeated_context_history_primary_calls=366,additional_gguf_owner_calls=2,new_safetensors_traces=8,new_safetensors_fixture_opens=19,new_safetensors_fixture_closes=19,new_safetensors_weight_header_reads=20,new_graph_fixture_files=121,gguf_readonly_whole_file_mappings=1,gguf_matching_unmaps=1,native_tensor_payload_evaluation=False,model_layer_attention_execution=False,inference_proxy=False,numerical_hailo_execution=False,ordinary_model_admitted=False,whole_repository_pass=False,hosted_ci_pass=False)
out=root/'docs/evidence/dynamic-graph-lowering-2026-10-21';out.mkdir(exist_ok=False)
def save(name,value):(out/name).write_text(json.dumps(value,indent=2)+'\n')
for name in ['build-results.json','source-hashes.json','test-input-hashes.json','final-test-input-hashes.json','additional-unchanged-tracked-mojo.json','oracle-and-control-input-hashes.json']:shutil.copy2(build/name,out/name)
for name in ['source-hashes.json','controls.json','baseline.json']:shutil.copy2(work/'dynamic-graph-baseline'/name,out/('pre-code-'+name))
save('summary.json',summary);save('suite-census.json',suites);save('frozen-comparison-summary.json',paired)
shutil.copy2(accept/'graph/trace-audit.json',out/'safetensors-trace-audit.json');shutil.copy2(accept/'gguf-owner/audit.json',out/'gguf-owner-audit.json');shutil.copy2(accept/'graph/fixture-identities.json',out/'graph-fixture-identities.json')
for name in ['build-closure.py','final-verify.py','regressions.py','run-frozen-pairs.py','pair-history-context.py','audit-traces.py','audit-gguf-owner.py','archive-snapshots.py','record-evidence.py']:
 shutil.copy2(work/'dynamic-graph-development'/name,out/name)
shutil.copy2(work/'dynamic-graph-development/mutations.json',out/'mutation-fields.json')
for r in regresults:shutil.copy2(reg/(r['suite']+'-test.txt'),out/(r['suite']+'-tests.txt'))
for name in ['context','history','graph','trace_audit']:shutil.copy2(accept/(name+'-test.txt'),out/(name+'-final-tests.txt'))
(out/'build-diagnostics.txt').write_text('')
archives=[]
for name in ['dynamic-graph-development','dynamic-graph-selected','dynamic-graph-selected-tests','dynamic-graph-selected-tests-2','dynamic-graph-final-pre-compatibility','dynamic-graph-acceptance-pre-compatibility','dynamic-graph-final-pre-diagnostics','dynamic-graph-acceptance-pre-diagnostics','dynamic-graph-final','dynamic-graph-acceptance','dynamic-graph-regressions','dynamic-graph-regressions-import-path-failure','dynamic-graph-acceptance-import-path-failure','dynamic-graph-regressions-pre-audit-review','dynamic-graph-acceptance-pre-audit-review']:
 path=work/name
 for p in sorted(path.rglob('*')):
  if p.is_file():archives.append(dict(path=str(p),bytes=p.stat().st_size,mode=oct(p.stat().st_mode&0o777),sha256=hashof(p)))
save('archive-identities.json',archives)
version=subprocess.check_output(['mojo','--version'],text=True).strip();save('runtime.json',dict(mojo=version,compiler_environment='MODULAR_CACHE_DIR=../mojo-cache',build_arguments=['mojo','build','-I','.','-I','aesir_engine','-I','tests','SOURCE','-o','BINARY'],full_models_executed=0))
print(json.dumps(summary,indent=2))
