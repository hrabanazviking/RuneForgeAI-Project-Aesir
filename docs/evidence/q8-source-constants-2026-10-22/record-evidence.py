"""Record only completed final native acceptance, with exact identity gates."""
from collections import Counter
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
root=Path.cwd();build=Path('../q8-source-final');accept=Path(sys.argv[1]);dst=Path('docs/evidence/q8-source-constants-2026-10-22')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
checks=json.loads((accept/'test-results.json').read_text());assert len(checks)==32 and all(x['returncode']==0 for x in checks)
builds=json.loads((build/'build-results.json').read_text());assert len(builds)==76 and all(x['returncode']==0 and x['diagnostic_bytes']==0 for x in builds)
for x in builds:assert sha(x['binary'])==x['sha256']
source=json.loads((build/'source-hashes.json').read_text());assert len(source)==640
for p,h in source.items():assert sha(p)==h and sha(build/'source-snapshot'/p)==h,p
inputs=json.loads((build/'input-hashes.json').read_text())
for p,h in inputs.items():assert sha(p)==h,p
old=json.loads(Path('../q8-source-baseline/source-hashes.json').read_text());assert len(old)==637
changed=[p for p,h in old.items() if sha(p)!=h];assert set(changed)=={'aesir_engine/loader/packed_gguf.mojo','smidr/source_weight_tiles.mojo'}
for p,h in json.loads(Path('../q8-source-baseline/test-input-hashes.json').read_text()).items():assert sha(p)==h,p
controls=json.loads(Path('../q8-source-baseline/controls.json').read_text());assert len(controls)==74
for x in controls:assert sha(x['binary'])==x['sha256']
review=json.loads(Path('../q8-source-audit-review/verification-input-hashes.json').read_text())
for p,h in review.items():assert sha(p)==h,p
context=json.loads((accept/'post-context/result.json').read_text());history=json.loads((accept/'history/runs.json').read_text())
suites=[]
for item in checks:
 name=item['suite']
 if name.endswith('traces'):continue
 log=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in log,(name,log)
 methods=int(re.search(r'Ran (\d+) tests?',log)[1])
 if name=='context':calls=context['native_child_calls']
 elif name=='history':calls=history['native_child_calls']
 else:
  folder=accept/('new' if name=='q8' else name if name in ('graph','context-actions','lcu-actions') else 'legacy/'+name)
  paths=list(folder.glob('*runs.json'));assert len(paths)==1,(name,paths)
  data=json.loads(paths[0].read_text());assert isinstance(data,list);calls=len(data)
 suites.append({'suite':name,'methods':methods,'recorded_primary_child_calls':calls})
assert len(suites)==30 and sum(x['methods'] for x in suites)==200 and sum(x['recorded_primary_child_calls'] for x in suites)==9309,suites
new=json.loads((accept/'new/summary.json').read_text());assert (new['calls'],new['component_checks'],new['byte_checks'])==(137,2098473,3774)
assert new['outcomes']=={'accepted':78,'refused':59}
trace=json.loads((accept/'new/trace-audit.json').read_text());assert len(trace['traces'])==10
assert trace['totals']=={'fixture_opens':13,'fixture_closes':13,'whole_readonly_shared_maps':13,'matching_unmaps':13}
assert trace['forbidden_access_matches']==0 and trace['whole_gguf_fixture_mmaps_include_payload'] is True
pairs=[x for p in (accept/'pairs').glob('*.json') for x in json.loads(p.read_text())]
covered={Path(x['binary']).name for x in pairs};success={Path(x['binary']).name for x in pairs if x['returncode']==0}
assert len(covered)==74 and len(success)==73,(len(covered),len(success))
summary={'pre_code_contract':'9b698947fa1f975dba08bb3d5abd11a8549741e0','clean_mojo_builds':76,'source_hashes_and_actual_snapshots':640,'prior_mojo_sources_unchanged':635,'prior_mojo_sources_changed':changed,'old_tests_unchanged':62,'frozen_controls_unchanged':74,'primary_suites':30,'primary_methods':200,'recorded_primary_child_calls':9309,'new_methods':10,'new_primary_calls':137,'new_accepted':78,'new_expected_refusals':59,'complete_component_comparisons':1321,'exhaustive_digest_component_records':2097152,'exhaustive_scale_word_patterns':65536,'source_byte_comparisons':3774,'additional_repeated_context_methods':4,'additional_repeated_context_primary_calls':122,'additional_repeated_context_frozen_calls':122,'additional_frozen_calls':len(pairs),'frozen_success_stdout_pairs':sum(x['returncode']==0 for x in pairs),'frozen_nonzero_stdout_exit_error_pairs':sum(x['returncode']!=0 for x in pairs),'unique_frozen_controls':74,'successful_frozen_controls':73,'mutation_only_controls':sorted(covered-success),'source_payload_representation_decoded':True,'production_floating_tensor_products':False,'model_layer_attention_forward':False,'numerical_hailo_execution':False,'device_format_or_fit_verified':False,'source_model_execution':False,'whole_repository_pass':False,'hosted_ci_pass':False}
dst.mkdir(exist_ok=False)
# Direct stdout outside archived folders to avoid a self-changing receipt log.
portable=[]
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copy_json(p,name):
 p=Path(p);d=json.loads(p.read_text());(dst/name).write_text(json.dumps(clean(d),indent=2)+'\n')
 portable.append({'source':str(p),'original_sha256':sha(p),'published':name,'published_sha256':sha(dst/name),'path_portability':'absolute work prefix replaced with ../; payload/source hashes unchanged'})
for name in ('source-hashes.json','input-hashes.json','build-results.json','changed-prior-sources.json'):copy_json(build/name,name)
copy_json(accept/'test-results.json','test-results.json');copy_json(accept/'frozen-pair-summary.json','frozen-pair-summary.json')
copy_json(accept/'new/fixtures.json','q8-fixture-identities.json');copy_json(accept/'new/trace-audit.json','q8-trace-audit.json');copy_json(accept/'new/static-reference.json','static-reference.json')
copy_json(accept/'post-context/result.json','repeated-context-result.json');copy_json(accept/'post-context/comparison.json','context-report-collision-review.json');copy_json(accept/'graph/trace-audit.json','graph-trace-audit.json');copy_json('../q8-source-audit-review/verification-input-hashes.json','audit-review-input-hashes.json')
for item in checks:shutil.copyfile(accept/(item['suite']+'-tests.txt'),dst/(item['suite']+'-tests.txt'))
for p in (Path('../q8-source-development').glob('*.py')):shutil.copyfile(p,dst/p.name)
shutil.copyfile('../q8-source-audit-review/audit-q8-traces.py',dst/'audit-q8-traces-reviewed.py')
shutil.copyfile('../q8-source-audit-review/verify-reviewed.py',dst/'verify-reviewed.py');shutil.copyfile(__file__,dst/'record-evidence.py')
(dst/'runtime.json').write_text(json.dumps({'mojo':subprocess.check_output(['mojo','--version'],text=True).strip(),'compiler_environment':'MODULAR_CACHE_DIR=../mojo-cache','model_or_layer_or_attention_execution':False,'numerical_hailo_execution':False},indent=2)+'\n')
(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n')
(dst/'portable-paths.json').write_text(json.dumps(portable,indent=2)+'\n');(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(x['binary']).name+'-build.txt')).read_text() for x in builds))
# Retain identities of all outside artifacts, including preliminary/audit failures.
archives=[]
for folder in ('q8-source-study','q8-source-baseline','q8-source-development','q8-source-selected','q8-source-final','q8-source-acceptance','q8-source-acceptance-reviewed','q8-source-audit-review'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n')
print(json.dumps(summary,indent=2))
