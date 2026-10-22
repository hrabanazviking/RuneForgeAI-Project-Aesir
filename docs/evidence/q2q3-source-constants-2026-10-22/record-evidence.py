from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path.cwd();build=Path('../q2q3-native-final');accept=Path('../q2q3-native-reviewed-acceptance');dst=Path('docs/evidence/q2q3-source-constants-2026-10-22')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==117 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
for x in rows:assert sha(x['binary'])==x['sha256']
source=json.loads((build/'source-hashes.json').read_text());assert len(source)==646
for p,h in source.items():assert sha(p)==h==sha(build/'source-snapshot'/p),p
inputs=json.loads((accept/'input-hashes.json').read_text())
for p,h in inputs.items():assert sha(p)==h,p
for p,h in json.loads((accept/'review-input-hashes.json').read_text()).items():assert sha(p)==h,p
old=json.loads(Path('../q2q3-native-baseline/source-hashes.json').read_text());assert len(old)==643
for p,h in old.items():assert sha(Path('../q2q3-native-baseline/source-snapshot')/p)==h,p
changed=[p for p,h in old.items() if sha(p)!=h];assert changed==['aesir_engine/loader/packed_gguf.mojo']
oldpy=json.loads(Path('../q2q3-native-baseline/test-input-hashes.json').read_text());assert len(oldpy)==64
for p,h in oldpy.items():assert sha(p)==h,p
controls=json.loads(Path('../q2q3-native-baseline/controls.json').read_text());assert len(controls)==81
for x in controls:assert sha(x['binary'])==x['sha256']
checks=json.loads((accept/'test-results.json').read_text());assert len(checks)==46 and all(x['returncode']==0 for x in checks),(len(checks),checks)
suites=[]
for x in checks:
 name=x['suite']
 if name.endswith('traces'):continue
 log=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in log,(name,log)
 methods=int(re.search(r'Ran (\d+) tests?',log)[1])
 if name=='context':calls=json.loads((accept/'context-report.json').read_text())['native_child_calls']
 elif name=='history':calls=json.loads((accept/'history/runs.json').read_text())['native_child_calls']
 else:
  folder=accept/name
  if not folder.exists():folder=accept/'legacy'/name
  files=list(folder.glob('*runs.json'));assert len(files)==1,(name,files)
  data=json.loads(files[0].read_text());assert isinstance(data,list);calls=len(data)
 suites.append({'suite':name,'methods':methods,'recorded_primary_child_calls':calls})
assert len(suites)==42
new=json.loads((accept/'q2q3/summary.json').read_text());assert new['calls']==530 and new['component_checks']==439026 and new['byte_checks']==32248
pairs=[x for p in (accept/'pairs').glob('*.json') for x in json.loads(p.read_text())]
covered={x['binary'] for x in pairs};success={x['binary'] for x in pairs if x['returncode']==0};assert len(covered)==98
trace=json.loads((accept/'q2q3/trace-audit.json').read_text());assert trace['forbidden_access_matches']==0
summary={'pre_code_contract':'5ec7420225c6400f31b3f79b3b98ebd4a7dae960','clean_current_mojo_builds':100,'clean_late_precode_snapshot_baseline_builds':17,'total_clean_mojo_builds':117,'source_hashes_and_actual_snapshots':646,'prior_mojo_sources_unchanged':642,'prior_mojo_sources_changed':changed,'old_python_tests_unchanged':64,'controls_frozen_before_production':81,'late_snapshot_controls':17,'primary_suites':42,'primary_methods':sum(x['methods'] for x in suites),'recorded_primary_child_calls':sum(x['recorded_primary_child_calls'] for x in suites),'new_methods':13,'new_primary_calls':530,'new_accepted':339,'new_expected_refusals':191,'complete_component_comparisons':439026,'source_byte_comparisons':32248,'isolated_static_reference_constants':2048,'bit_plane_cases':1504,'complete_bit_plane_component_comparisons':385024,'additional_frozen_calls':len(pairs),'frozen_success_stdout_pairs':sum(x['returncode']==0 for x in pairs),'frozen_nonzero_stdout_exit_error_pairs':sum(x['returncode']!=0 for x in pairs),'unique_comparison_controls':98,'successful_comparison_controls':len(success),'mutation_only_controls':sorted(Path(x).name for x in covered-success),'new_trace_files':len(trace['traces']),'trace_lifecycles':trace['totals'],'intentional_GGUF_admission_delta_calls':4,'initial_safetensors_runner_ldd_misclassification':True,'safetensors_native_checks_passed_before_runner_error':97,'reviewed_safetensors_methods':9,'reviewed_safetensors_native_calls':97,'old_test_inputs_changed':0,'unrelated_comparisons_skipped':0,'source_payload_representation_decoded':True,'production_floating_tensor_product_or_subtraction':False,'model_layer_attention_forward':False,'numerical_hailo_execution':False,'device_format_or_fit_verified':False,'source_model_execution':False,'whole_repository_pass':False,'hosted_ci_pass':False}
dst.mkdir(exist_ok=False);portable=[]
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..').replace(str(Path.home() / 'mojo-dev'),'<mojo-runtime>')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copy_json(path,name):
 p=Path(path);v=json.loads(p.read_text());(dst/name).write_text(json.dumps(clean(v),indent=2)+'\n');portable.append({'source':str(p),'original_sha256':sha(p),'published':name,'published_sha256':sha(dst/name),'normalization':'Absolute work prefix replaced with ../; source/payload hashes unchanged.'})
for name in ('source-hashes.json','input-hashes.json','build-results.json','closure-jobs.json'):copy_json(build/name,'build-'+name)
for name in ('test-results.json','input-hashes.json','frozen-pair-summary.json','intentional-admission-deltas.json'):copy_json(accept/name,name)
for name in ('fixtures.json','summary.json','trace-audit.json','static-reference.json'):copy_json(accept/'q2q3'/name,'q2q3-'+name)
for name in ('classic32','q8','graph'):copy_json(accept/name/'trace-audit.json',name+'-trace-audit.json')
for name in ('source-hashes.json','test-input-hashes.json','controls.json','consumer-inventory.json'):copy_json(Path('../q2q3-native-baseline')/name,'baseline-'+name)
for p in Path('../q2q3-native-development').iterdir():
 if p.is_file() and p.suffix in ('.py','.json','.txt','.cpp'):
  if p.suffix=='.json':copy_json(p,'development-'+p.name)
  else:shutil.copyfile(p,dst/('development-'+p.name))
for x in checks:shutil.copyfile(accept/(x['suite']+'-tests.txt'),dst/(x['suite']+'-tests.txt'))
shutil.copyfile('../classic32-source-audit-review/audit-traces.py',dst/'audit-source-traces.py')
shutil.copyfile(__file__,dst/'record-evidence.py')
for name in ('review-input-hashes.json','safetensors-linked-controls.json'):copy_json(accept/name,name)
copy_json('../q2q3-native-acceptance/safetensors_constants-status.json','initial-safetensors-runner-failure-status.json')
shutil.copyfile('../q2q3-native-acceptance/safetensors_constants-tests.txt',dst/'initial-safetensors-runner-failure.txt')
for p in Path('../q2q3-native-review').glob('*'):
 if p.is_file():
  if p.suffix=='.json':copy_json(p,'review-'+p.name)
  else:shutil.copyfile(p,dst/('review-'+p.name))
for p in Path('../q2q3-native-selected').glob('*.txt'):shutil.copyfile(p,dst/('selected-'+p.name))
# Preserve complete source outputs outside Git, publish per-call output receipts.
# Every component was compared in full before these receipts are generated.
runs=json.loads((accept/'q2q3/runs.json').read_text());receipts=[]
for x in runs:
 r=dict(x)
 for key in ('stdout','stderr'):
  value=r.pop(key);r[key+'_bytes']=len(value.encode());r[key+'_sha256']=hashlib.sha256(value.encode()).hexdigest()
  if len(value)<=4096:r[key]=value
 receipts.append(r)
(dst/'q2q3-call-receipts.json').write_text(json.dumps(clean(receipts),indent=2)+'\n')
(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n');(dst/'portable-paths.json').write_text(json.dumps(portable,indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(x['binary']).name+'-build.txt')).read_text() for x in rows))
(dst/'runtime.json').write_text(json.dumps({'mojo':subprocess.check_output(['mojo','--version'],text=True).strip(),'ggml_cpu_backend':'OFF','static_oracle_functions':['dequantize_row_q2_K','dequantize_row_q3_K'],'no_model_context_graph_forward_API':True},indent=2)+'\n')
archives=[]
for folder in ('q2q3-source-study','q2q3-native-baseline','q2q3-native-development','q2q3-native-selected','q2q3-native-final','q2q3-native-acceptance','q2q3-native-review','q2q3-native-reviewed-acceptance'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n')
print(json.dumps(summary,indent=2))
