from pathlib import Path
import hashlib,json,re,shutil
repo=Path.cwd();build=Path('../sealed-gguf-native-final');accept=Path('../sealed-gguf-native-acceptance-v2');baseline=Path('../sealed-gguf-native-baseline');recording=Path('../sealed-gguf-native-recording');development=Path('../sealed-gguf-native-development');dst=Path('docs/evidence/sealed-gguf-source-2026-10-22')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(accept/'input-hashes.json'));controls=json.load(open(baseline/'controls.json'));old=json.load(open(baseline/'source-hashes.json'));oldtests=json.load(open(baseline/'test-input-hashes.json'))
assert len(rows)==109 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
assert len(sources)==660 and len(old)==656 and len(oldtests)==68 and len(controls)==106
for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
for r in rows+controls:assert sha(r['binary'])==r['sha256'],r['binary']
for p,h in sources.items():assert sha(build/'source-snapshot'/p)==h,p
changed=[p for p,h in old.items() if sha(p)!=h];assert set(changed)=={'aesir_engine/loader/gguf.mojo','aesir_engine/loader/packed_gguf.mojo','hailbru/source_sealed_copy.mojo'}
for p,h in old.items():assert sha(baseline/'source-snapshot'/p)==h,p
for p,h in oldtests.items():assert sha(p)==h==sha(baseline/'test-snapshot'/p),p
for r in json.load(open(recording/'auxiliary-input-continuity.json')):assert sha(r['path'])==r['sha256'],r['path']
assert json.load(open(recording/'final-qualification.json'))['qualified']==True
checks=json.load(open('../sealed-gguf-native-closure/canonical-test-results.json'));assert len(checks)==46 and all(r['returncode']==0 for r in checks)
suites=[]
for r in checks:
 name=r['suite'];text=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in text,name
 cmd=r['command']
 if '--result' in cmd:
  manifest=Path(cmd[cmd.index('--result')+1]);report=json.load(open(manifest));calls=report['calls'];assert len(calls)==report['native_child_calls']
 else:
  folder=Path(cmd[cmd.index('--evidence')+1]);manifests=[p for p in (folder/'runs.json',folder/'fixture-runs.json') if p.exists()];assert len(manifests)==1,(name,manifests)
  manifest=manifests[0];calls=json.load(open(manifest))
  if isinstance(calls,dict):
   report=calls;calls=report['calls'];assert len(calls)==report['native_child_calls']
  assert isinstance(calls,list)
 suites.append({'suite':name,'methods':int(re.search(r'Ran (\d+) tests?',text)[1]),'primary_native_child_calls':len(calls),'call_manifest':str(manifest),'sha256':sha(manifest)})
new=json.load(open(accept/'sealed/summary.json'));trace=json.load(open(accept/'sealed/trace-audit.json'));copy=json.load(open(accept/'copy/trace-audit.json'));digest=json.load(open(accept/'trace-audit.json'));legacy=json.load(open(accept/'all-legacy-trace-audit.json'));reg=json.load(open('../sealed-gguf-native-closure/regression-summary.json'));assert reg['controls']==106 and reg['skipped_pairs']==0
pairfiles=[Path(p) for p in json.load(open('../sealed-gguf-native-closure/canonical-pair-files.json'))];pairs=[r for p in pairfiles for r in json.load(open(p))];expected={r['binary'] for r in rows if r['source'] in {r['source'] for r in controls}};assert {r['binary'] for r in pairs}==expected
assert len(pairs)==reg['success_pairs']+reg['nonzero_pairs'];assert reg['complete_mutation_pairs']==6
assert trace['trace_count']==95 and new['calls']==221
summary={'pre_code_contract':'39d187d201fadcb9b547f5cac53683398773e24a','route_clarification_and_native_parent':'f2084727ce857230feb0a3de935584dd6be7d046','clean_current_mojo_builds':109,'clean_c_fault_shim_builds':2,'source_identities_and_actual_snapshots':660,'prior_sources':656,'old_mojo_sources_unchanged':653,'old_mojo_sources_changed':changed,'new_mojo_sources':4,'new_production_mojo_sources':2,'new_test_api_mojo_sources':2,'old_python_inputs_unchanged':68,'old_current_controls_unchanged_and_rebuilt':106,'old_import_affected_controls':100,'conservatively_rebuilt_unaffected_controls':6,'native_suites':len(suites),'native_methods':sum(r['methods'] for r in suites),'primary_native_child_calls':sum(r['primary_native_child_calls'] for r in suites),'new_methods':6,'new_suite_child_calls':221,'new_zero_exits_including_handled_guards':156,'new_nonzero_refusals':65,'new_complete_comparisons':new['complete_comparisons'],'complete_legacy_pairs':len(pairs),'legacy_success_pairs':reg['success_pairs'],'legacy_nonzero_pairs':reg['nonzero_pairs'],'complete_fixture_mutation_pairs':6,'skipped_pairs':0,'supplemental_current_directory_suite_reruns':3,'initial_directory_coverage_refusal_retained':True,'initial_shared_fault_log_harness_failure_retained':True,'final_control_fault_logs_independent_and_complete_equal':sum(bool(r.get('independent_complete_fault_logs_equal')) for r in pairs),'new_traces':95,'new_trace_lifetimes':trace['totals'],'new_readonly_sealed_maps':trace['readonly_sealed_maps'],'new_readonly_path_maps':trace['readonly_path_maps'],'new_exact_extent_unmaps':trace['exact_capacity_unmaps'],'new_kernel_reads':trace['kernel_reads'],'new_kernel_writes':trace['kernel_writes'],'old_copy_traces':copy['trace_count'],'old_digest_traces':digest['trace_count'],'all_legacy_traces':legacy['trace_count'],'opaque_records_retained_without_inferred_effects':len(trace['opaque_records'])+len(legacy['opaque_records']),'forbidden_access_matches':0,'scoped_sealed_input_bytes_bound':True,'original_atomic_snapshot_verified':False,'source_fingerprint_verified':False,'immutable_source_verified':False,'compiled_artifact_identity_verified':False,'binding_identity_verified':False,'execution_tested':False,'device_access':False,'source_model_execution':False,'whole_repository_pass':False,'hosted_ci_pass':False}
assert summary['native_methods']==322

def clean(v):
 if isinstance(v,str):return v.replace(str(repo.parent),'..').replace(str(Path.home()/'mojo-dev'),'<mojo-runtime>')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copyjson(path,name):(dst/name).write_text(json.dumps(clean(json.load(open(path))),indent=2)+'\n')
dst.mkdir(exist_ok=False)
for n in ('source-hashes.json','build-results.json','broad-build-results.json','semantic-build-result.json','consumer-inventory.json'):copyjson(build/n,'build-'+n)
for n in ('source-hashes.json','test-input-hashes.json','controls.json','consumer-inventory.json','qualification.json','git.json'):copyjson(baseline/n,'baseline-'+n)
for n in ('test-results.json','input-hashes.json','c-binaries.json','dependency-inspection.json','trace-audit.json','synthetic-mutation-audit.json','all-legacy-trace-audit.json'):copyjson(accept/n,n)
for sub in ('sealed','copy','digest'):
 for n in ('summary.json','fixtures.json','trace-manifest.json'):
  copyjson(accept/sub/n,sub+'-'+n)
 if sub!='digest':copyjson(accept/sub/'trace-audit.json',sub+'-trace-audit.json')
copyjson(Path('../sealed-gguf-native-closure/regression-summary.json'),'regression-summary.json')
copyjson(Path('../sealed-gguf-native-closure/canonical-test-results.json'),'canonical-test-results.json')
copyjson(Path('../sealed-gguf-native-closure/canonical-pair-files.json'),'canonical-pair-files.json')
for p in pairfiles:copyjson(p,'pairs-'+p.name)
for r in checks:
 logroot=Path(r['command'][2]).parent.parent if r['suite']!='sealed-gguf' else accept
 shutil.copy2(logroot/(r['suite']+'-tests.txt'),dst/(r['suite']+'-tests.txt'))
for p in sorted(development.iterdir()):
 if p.is_file() and p.suffix in ('.py','.json','.txt','.log'):
  if p.suffix=='.json':copyjson(p,'development-'+p.name)
  else:(dst/('development-'+p.name)).write_text(clean(p.read_text()))
for n in ('auxiliary-input-continuity.json','bounded-public-lead-search.json','doc-drift-before-status.json','harness-failure-and-correction.json','previous-archive-continuity.json','directory-coverage-correction.json','trace-parser-correction.json','final-qualification.json'):copyjson(recording/n,n)
for p in sorted(Path('../sealed-gguf-native-reviewed').iterdir()):
 if p.is_file() and p.suffix in ('.py','.json','.txt','.log'):
  if p.suffix=='.json':copyjson(p,'reviewed-'+p.name)
  else:(dst/('reviewed-'+p.name)).write_text(clean(p.read_text()))
copyjson(Path('../sealed-gguf-native-acceptance/test-results.json'),'retained-initial-test-results.json')
shutil.copy2(Path('../sealed-gguf-native-acceptance/sealed-copy-tests.txt'),dst/'retained-initial-sealed-copy-tests.txt')
for p in sorted(Path('../sealed-gguf-native-closure').iterdir()):
 if p.is_file() and p.suffix in ('.py','.json','.log'):
  if p.suffix=='.json':copyjson(p,'closure-'+p.name)
  else:(dst/('closure-'+p.name)).write_text(clean(p.read_text()))
for name in ('record-evidence-attempt1.py','record-evidence-attempt1.log','audit-old-digest-reviewed2.py','audit-all-legacy-reviewed2.py','v2-old-digest-audit.txt','v2-old-digest-audit-reviewed2.txt','v2-all-legacy-audit-reviewed2.txt'):
 (dst/name).write_text(clean((recording/name).read_text()))
receipts=[]
for r in json.load(open(accept/'sealed/runs.json')):
 receipt={k:v for k,v in r.items() if k not in ('stdout','stderr')}
 for field in ('stdout','stderr'):
  text=r[field];receipt[field+'_bytes']=len(text.encode());receipt[field+'_sha256']=hashlib.sha256(text.encode()).hexdigest()
  if len(text)<=4096:receipt[field]=text
 receipts.append(receipt)
(dst/'native-call-receipts.json').write_text(json.dumps(clean(receipts),indent=2)+'\n');(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(clean(suites),indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(r['binary']).name+'.build.log')).read_text() for r in rows));shutil.copy2(__file__,dst/'record-evidence.py')
archives=[]
for folder in ('sealed-gguf-native-baseline','sealed-gguf-native-development','sealed-gguf-native-final','sealed-gguf-native-acceptance','sealed-gguf-native-reviewed','sealed-gguf-native-acceptance-v2','sealed-gguf-native-closure'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n');print(json.dumps(summary,indent=2))
