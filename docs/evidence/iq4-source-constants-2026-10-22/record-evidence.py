from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path.cwd();build=Path('../iq4-native-final');accept=Path('../iq4-native-reviewed-acceptance');dst=Path('docs/evidence/iq4-source-constants-2026-10-22');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.loads((build/'build-results.json').read_text());assert len(rows)==102 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in rows)
for x in rows:assert sha(x['binary'])==x['sha256']
sources=json.loads((build/'source-hashes.json').read_text());assert len(sources)==649
for p,h in sources.items():assert sha(p)==h==sha(build/'source-snapshot'/p),p
for p,h in json.loads((accept/'input-hashes.json').read_text()).items():assert sha(p)==h,p
for p,h in json.loads((accept/'review-input-hashes.json').read_text()).items():assert sha(p)==h,p
old=json.loads(Path('../iq4-native-baseline/source-hashes.json').read_text());assert len(old)==646
for p,h in old.items():assert sha(Path('../iq4-native-baseline/source-snapshot')/p)==h,p
changed=[p for p,h in old.items() if sha(p)!=h];assert changed==['aesir_engine/loader/packed_gguf.mojo']
oldpy=json.loads(Path('../iq4-native-baseline/test-input-hashes.json').read_text());assert len(oldpy)==65
for p,h in oldpy.items():assert sha(p)==h,p
controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text());assert len(controls)==100
for x in controls:assert sha(x['binary'])==x['sha256']
checks=json.loads((accept/'test-results.json').read_text());assert len(checks)==48 and all(x['returncode']==0 for x in checks)
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
  d=json.loads(files[0].read_text());assert isinstance(d,list);calls=len(d)
 suites.append({'suite':name,'methods':methods,'recorded_primary_child_calls':calls})
assert len(suites)==43
new=json.loads((accept/'iq4/summary.json').read_text());trace=json.loads((accept/'iq4/trace-audit.json').read_text());assert trace['forbidden_access_matches']==0
pairs=[x for p in (accept/'pairs').glob('*.json') for x in json.loads(p.read_text())];covered={x['binary'] for x in pairs};success={x['binary'] for x in pairs if x['returncode']==0};assert len(covered)==100
summary={'pre_code_contract':'efb0ec0a4553a2511e08df731db4ba5371216eaf','clean_current_mojo_builds':102,'source_hashes_and_actual_snapshots':649,'prior_mojo_sources_unchanged':645,'prior_mojo_sources_changed':changed,'old_python_tests_unchanged':65,'controls_frozen_before_production':100,'primary_suites':43,'primary_methods':sum(x['methods'] for x in suites),'recorded_primary_child_calls':sum(x['recorded_primary_child_calls'] for x in suites),'new_methods':next(x['methods'] for x in suites if x['suite']=='iq4'),'new_primary_calls':new['calls'],'new_outcomes':new['outcomes'],'complete_component_comparisons':new['component_checks'],'source_byte_comparisons':new['byte_checks'],'isolated_static_reference_constants':2048,'bit_plane_cases':1200,'complete_bit_plane_component_comparisons':278528,'additional_frozen_calls':len(pairs),'frozen_success_stdout_pairs':sum(x['returncode']==0 for x in pairs),'frozen_nonzero_stdout_exit_error_pairs':sum(x['returncode']!=0 for x in pairs),'unique_comparison_controls':100,'successful_comparison_controls':len(success),'mutation_only_controls':sorted(Path(x).name for x in covered-success),'new_trace_files':len(trace['traces']),'trace_lifecycles':trace['totals'],'intentional_GGUF_admission_delta_calls':6,'old_test_inputs_changed':0,'unrelated_native_comparisons_skipped':0,'source_payload_representation_decoded':True,'production_floating_tensor_product':False,'model_layer_attention_forward':False,'numerical_hailo_execution':False,'device_format_or_fit_verified':False,'source_model_execution':False,'initial_q8_audit_whitespace_failure_retained':True,'native_suites_reexecuted_for_audit_correction':0,'whole_repository_pass':False,'hosted_ci_pass':False}
dst.mkdir(exist_ok=False);receipts=[]
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..').replace(str(Path.home()/'mojo-dev'),'<mojo-runtime>')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copy_json(path,name):
 p=Path(path);(dst/name).write_text(json.dumps(clean(json.loads(p.read_text())),indent=2)+'\n');receipts.append({'source':str(p),'original_sha256':sha(p),'published':name,'published_sha256':sha(dst/name),'normalization':'Work prefix replaced with ../;runtime prefix with <mojo-runtime>. Source/payload hashes unchanged;original full values retained outside.'})
for n in ('source-hashes.json','input-hashes.json','build-results.json','closure-jobs.json'):copy_json(build/n,'build-'+n)
for n in ('test-results.json','input-hashes.json','frozen-pair-summary.json','intentional-admission-deltas.json','linked-controls.json','layout-oracle.json'):copy_json(accept/n,n)
for n in ('fixtures.json','summary.json','trace-audit.json','static-reference.json'):copy_json(accept/'iq4'/n,'iq4-'+n)
for n in ('q2q3','classic32','q8','graph'):copy_json(accept/n/'trace-audit.json',n+'-trace-audit.json')
for n in ('source-hashes.json','test-input-hashes.json','controls.json','consumer-inventory.json'):copy_json(Path('../iq4-native-baseline')/n,'baseline-'+n)
for p in Path('../iq4-native-development').iterdir():
 if p.is_file() and p.suffix in ('.py','.json','.txt','.md'):
  if p.suffix=='.json':copy_json(p,'development-'+p.name)
  else:shutil.copyfile(p,dst/('development-'+p.name))
for x in checks:shutil.copyfile(accept/(x['suite']+'-tests.txt'),dst/(x['suite']+'-tests.txt'))
for p in Path('../iq4-native-selected').glob('*.txt'):shutil.copyfile(p,dst/('selected-'+p.name))
shutil.copyfile('../classic32-source-audit-review/audit-traces.py',dst/'audit-source-traces.py');shutil.copyfile(__file__,dst/'record-evidence.py')
copy_json(accept/'review-input-hashes.json','review-input-hashes.json')
for p in Path('../iq4-native-review').glob('*'):
 if p.is_file():
  if p.suffix=='.json':copy_json(p,'review-'+p.name)
  else:shutil.copyfile(p,dst/('review-'+p.name))
shutil.copyfile('../iq4-native-acceptance/q8-traces-tests.txt',dst/'initial-q8-audit-failure.txt')
copy_json('../iq4-native-acceptance/q8-traces-status.json','initial-q8-audit-status.json')
runs=json.loads((accept/'iq4/runs.json').read_text());call_receipts=[]
for x in runs:
 r=dict(x)
 for k in ('stdout','stderr'):
  v=r.pop(k);r[k+'_bytes']=len(v.encode());r[k+'_sha256']=hashlib.sha256(v.encode()).hexdigest()
  if len(v)<=4096:r[k]=v
 call_receipts.append(r)
(dst/'iq4-call-receipts.json').write_text(json.dumps(clean(call_receipts),indent=2)+'\n')
(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n');(dst/'portable-paths.json').write_text(json.dumps(receipts,indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(x['binary']).name+'-build.txt')).read_text() for x in rows));shutil.copyfile(accept/'layout-build.txt',dst/'layout-build.txt')
(dst/'runtime.json').write_text(json.dumps({'mojo':subprocess.check_output(['mojo','--version'],text=True).strip(),'ggml_cpu_backend':'OFF','static_oracle_functions':['dequantize_row_iq4_nl','dequantize_row_iq4_xs'],'no_external_model_context_graph_forward_API':True},indent=2)+'\n')
archives=[]
for folder in ('iq4-native-baseline','iq4-native-development','iq4-native-selected','iq4-native-final','iq4-native-acceptance','iq4-native-review','iq4-native-reviewed-acceptance'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n');print(json.dumps(summary,indent=2))
