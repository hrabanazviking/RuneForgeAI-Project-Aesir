"""Record completed original classic32 source acceptance and retained failures."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path.cwd();build=Path('../classic32-source-final');accept=Path(sys.argv[1]);dst=Path('docs/evidence/classic32-source-constants-2026-10-22')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
extra=Path('../classic32-source-extra');extra_accept=extra/'acceptance'
extra_builds=json.loads((extra/'build/build-results.json').read_text())
assert len(extra_builds)==6 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in extra_builds)
for x in extra_builds:assert sha(x['binary'])==x['sha256']
for p,h in json.loads((extra/'input-hashes.json').read_text()).items():assert sha(p)==h,p
assert json.loads((extra_accept/'status.json').read_text())['returncode']==0
checks=json.loads((accept/'test-results.json').read_text());assert len(checks)==34 and all(x['returncode']==0 for x in checks)
builds=json.loads((build/'build-results.json').read_text());assert len(builds)==78 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in builds)
for x in builds:assert sha(x['binary'])==x['sha256']
source=json.loads((build/'source-hashes.json').read_text());assert len(source)==643
for p,h in source.items():assert sha(p)==h and sha(build/'source-snapshot'/p)==h,p
inputs=json.loads((build/'input-hashes.json').read_text())
for p,h in inputs.items():assert sha(p)==h,p
old=json.loads(Path('../classic32-source-baseline/source-hashes.json').read_text());assert len(old)==640
for p,h in old.items():assert sha(Path('../q8-source-final/source-snapshot')/p)==h,p
changed=[p for p,h in old.items() if sha(p)!=h];assert set(changed)=={'aesir_engine/loader/packed_gguf.mojo','smidr/source_weight_tiles.mojo'}
oldpy=json.loads(Path('../classic32-source-baseline/test-input-hashes.json').read_text());assert len(oldpy)==63
assert [p for p,h in oldpy.items() if sha(p)!=h]==['tests/test_hailo_source_storage.py']
assert Path('tests/test_hailo_source_storage.py').read_bytes()==Path('../classic32-source-baseline/python-snapshot/tests/test_hailo_source_storage.py').read_bytes().replace(b'("gguf",2,[256])',b'("gguf",9,[256])')
controls=json.loads(Path('../classic32-source-baseline/controls.json').read_text());assert len(controls)==76
for x in controls:assert sha(x['binary'])==x['sha256']
review=json.loads(Path('../classic32-source-audit-review/review-input-hashes.json').read_text())
for p,h in review.items():assert sha(p)==h,p
qualified=json.loads(Path('../classic32-source-audit-review/qualified-source-input-hashes.json').read_text())
for p,h in qualified.items():assert sha(p)==h,p
context=json.loads((accept/'context-report.json').read_text());history=json.loads((accept/'history/runs.json').read_text());suites=[]
for item in checks:
 name=item['suite']
 if name.endswith('traces'):continue
 log=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in log,(name,log)
 methods=int(re.search(r'Ran (\d+) tests?',log)[1])
 if name=='context':calls=context['native_child_calls']
 elif name=='history':calls=history['native_child_calls']
 else:
  folder=accept/('new' if name=='classic32' else 'q8' if name=='q8' else name if name in ('graph','context-actions','lcu-actions') else 'legacy/'+name)
  paths=list(folder.glob('*runs.json'));assert len(paths)==1,(name,paths)
  data=json.loads(paths[0].read_text());assert isinstance(data,list);calls=len(data)
 suites.append({'suite':name,'methods':methods,'recorded_primary_child_calls':calls})
assert len(suites)==31 and sum(x['methods'] for x in suites)==212 and sum(x['recorded_primary_child_calls'] for x in suites)==10097,suites
extra_log=(extra_accept/'tests.txt').read_text();assert '\nOK\n' in extra_log
extra_methods=int(re.search(r'Ran (\d+) tests?',extra_log)[1]);assert extra_methods==7
extra_runs=json.loads((extra_accept/'source-storage/runs.json').read_text());extra_calls=len(extra_runs)
suites.append({'suite':'source_storage_extra','methods':extra_methods,'recorded_primary_child_calls':extra_calls})
new=json.loads((accept/'new/summary.json').read_text());assert (new['calls'],new['component_checks'],new['byte_checks'])==(788,26611,11322)
assert new['outcomes']=={'accepted':488,'refused':300}
trace=json.loads((accept/'new/trace-audit.json').read_text());assert len(trace['traces'])==45
assert trace['totals']=={'fixture_opens':60,'fixture_closes':60,'whole_readonly_shared_maps':60,'matching_unmaps':60}
assert trace['forbidden_access_matches']==0 and trace['whole_gguf_fixture_mmaps_include_payload'] is True
pairs=[x for p in (accept/'pairs').glob('*.json') for x in json.loads(p.read_text())]
pairs+=json.loads((extra_accept/'frozen-pairs.json').read_text())
covered={Path(x['binary']).name for x in pairs};success={Path(x['binary']).name for x in pairs if x['returncode']==0}
assert len(covered)==79 and len(success)==78,(len(covered),len(success))
delta=json.loads((extra_accept/'intentional-admission-delta.json').read_text());assert delta['unrelated_comparisons_skipped']==0 and delta['old_returncode']!=0 and delta['new_returncode']==0
assert json.loads(delta['new_stdout'])=={'elements':256,'bytes':144}
summary={'pre_code_contract':'5b8c132b1eacbeecc980fa87150c7fe99f6a550f','clean_current_mojo_builds':81,'clean_precode_snapshot_baseline_builds':3,'total_clean_mojo_builds':84,'source_hashes_and_actual_snapshots':643,'prior_mojo_sources_unchanged':638,'prior_mojo_sources_changed':changed,'old_python_tests_unchanged':62,'old_python_tests_one_unsupported_sentinel_changed':1,'frozen_controls_unchanged':76,'primary_suites':32,'primary_methods':219,'recorded_primary_child_calls':10097+extra_calls,'supplemental_source_storage_methods':7,'supplemental_source_storage_calls':extra_calls,'inherited_driver_wiring_assertion_failed':True,'all_inherited_suites_passed':True,'new_methods':12,'new_primary_calls':788,'new_accepted':488,'new_expected_refusals':300,'complete_component_comparisons':26611,'source_byte_comparisons':11322,'isolated_static_reference_constants':2048,'additional_frozen_calls':len(pairs),'frozen_success_stdout_pairs':sum(x['returncode']==0 for x in pairs),'frozen_nonzero_stdout_exit_error_pairs':sum(x['returncode']!=0 for x in pairs),'unique_comparison_controls':79,'controls_frozen_before_production':76,'additional_baseline_controls_built_later_from_frozen_precode_sources':3,'successful_comparison_controls':78,'mutation_only_controls':sorted(covered-success),'intentional_original_sentinel_delta_calls':2,'unrelated_comparisons_skipped':0,'source_payload_representation_decoded':True,'production_floating_tensor_products_or_additions':False,'model_layer_attention_forward':False,'numerical_hailo_execution':False,'device_format_or_fit_verified':False,'source_model_execution':False,'whole_repository_pass':False,'hosted_ci_pass':False}
dst.mkdir(exist_ok=False);portable=[]
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copy_json(p,name):
 p=Path(p);d=json.loads(p.read_text());(dst/name).write_text(json.dumps(clean(d),indent=2)+'\n')
 portable.append({'source':str(p),'original_sha256':sha(p),'published':name,'published_sha256':sha(dst/name),'path_portability':'absolute work prefix replaced with ../; payload/source hashes unchanged'})
for name in ('source-hashes.json','input-hashes.json','build-results.json','changed-prior-sources.json'):copy_json(build/name,name)
for name in ('test-results.json','frozen-pair-summary.json','layout-oracle.json'):copy_json(accept/name,name)
for name in ('fixtures.json','trace-audit.json','static-reference.json'):copy_json(accept/'new'/name,'classic32-'+name)
copy_json(accept/'q8/trace-audit.json','q8-trace-audit.json');copy_json(accept/'graph/trace-audit.json','graph-trace-audit.json')
copy_json('../classic32-source-audit-review/review-input-hashes.json','audit-review-input-hashes.json')
copy_json('../classic32-source-audit-review/qualified-source-input-hashes.json','qualified-source-input-hashes.json')
copy_json('../classic32-source-baseline/former-sentinel.json','wrong-tool-baseline-usage-failure.json')
copy_json(extra_accept/'intentional-admission-delta.json','intentional-admission-delta.json')
copy_json(extra/'build/build-results.json','additional-build-results.json')
copy_json(extra/'wiring-failure.json','runner-wiring-failure.json')
copy_json(extra/'input-hashes.json','additional-input-hashes.json')
copy_json(extra_accept/'source-storage/runs.json','source-storage-extra-runs.json')
copy_json(extra_accept/'frozen-pairs.json','source-storage-extra-pairs.json')
copy_json(extra_accept/'status.json','source-storage-extra-status.json')
shutil.copyfile(extra_accept/'tests.txt',dst/'source-storage-extra-tests.txt')
for item in checks:shutil.copyfile(accept/(item['suite']+'-tests.txt'),dst/(item['suite']+'-tests.txt'))
for p in Path('../classic32-source-development').glob('*.py'):shutil.copyfile(p,dst/p.name)
for name in ('audit-traces.py','verify-reviewed.py','original-audit-failure.txt','original-audit-reproduced.txt','preparation-failure-note.txt'):shutil.copyfile(Path('../classic32-source-audit-review')/name,dst/('reviewed-'+name))
shutil.copyfile(__file__,dst/'record-evidence.py')
(dst/'runtime.json').write_text(json.dumps({'mojo':subprocess.check_output(['mojo','--version'],text=True).strip(),'compiler_environment':'MODULAR_CACHE_DIR=../mojo-cache','public_header_oracle_compiler':'c++ -std=c++17 -Wall -Wextra -Werror','ggml_cpu_backend':'OFF','model_or_layer_or_attention_execution':False,'numerical_hailo_execution':False},indent=2)+'\n')
(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n');(dst/'portable-paths.json').write_text(json.dumps(portable,indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(x['binary']).name+'-build.txt')).read_text() for x in builds)+''.join((extra/'build'/(Path(x['binary']).name+'-build.txt')).read_text() for x in extra_builds))
archives=[]
for p in extra.glob('*.py'):shutil.copyfile(p,dst/('extra-'+p.name))
for folder in ('classic32-source-extra','classic32-source-contract','classic32-source-baseline','classic32-source-development','classic32-source-selected','classic32-source-final','classic32-source-acceptance','classic32-source-reviewed-acceptance','classic32-source-audit-review'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n');print(json.dumps(summary,indent=2))
