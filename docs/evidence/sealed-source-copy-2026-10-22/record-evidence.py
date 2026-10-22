from pathlib import Path
import hashlib,json,re,shutil
root=Path.cwd();build=Path('../sealed-copy-native-final');accept=Path('../sealed-copy-native-acceptance');dst=Path('docs/evidence/sealed-source-copy-2026-10-22');dst.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(accept/'input-hashes.json'));controls=json.load(open('../sealed-copy-native-baseline/controls.json'))
assert len(rows)==10 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
for r in rows+controls:assert sha(r['binary'])==r['sha256']
for p,h in json.load(open('../sealed-copy-native-baseline/source-hashes.json')).items():assert sha(p)==h==sha(build/'source-snapshot'/p)
for p,h in json.load(open('../sealed-copy-native-baseline/test-input-hashes.json')).items():assert sha(p)==h==sha(Path('../sealed-copy-native-baseline/test-snapshot')/p)
checks=json.load(open(accept/'test-results.json'));assert len(checks)==5 and all(r['returncode']==0 for r in checks)
suites=[]
for r in checks:
 name=r['suite'];text=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in text
 folder=accept/('sealed' if name=='sealed-copy' else 'digest') if name in ('sealed-copy','source-digest') else accept/'legacy'/'legacy'/name if name!='gguf_shapes' else accept/'legacy'/name
 suites.append({'suite':name,'methods':int(re.search(r'Ran (\d+) tests?',text)[1]),'primary_calls':len(json.load(open(folder/'runs.json')))})
assert sum(r['methods'] for r in suites)==28 and sum(r['primary_calls'] for r in suites)==1091
new=json.load(open(accept/'sealed/summary.json'));trace=json.load(open(accept/'sealed/trace-audit.json'));reg=json.load(open(accept/'regression-summary.json'));assert trace['trace_count']==93 and reg['skipped_pairs']==0
summary={'pre_code_contract':'caf324049dc27db7e0a9971f0b9d659ae4cd1205','clean_current_mojo_builds':10,'clean_c_builds':2,'source_identities_and_actual_snapshots':656,'old_mojo_sources_unchanged':653,'old_python_inputs_unchanged':67,'old_controls_unchanged':104,'new_affected_entrypoints':2,'selected_rebuilt_controls':8,'native_suites':5,'native_methods':28,'primary_native_calls':1091,'new_methods':5,'new_calls':186,'new_zero_exit_cases_including_handled_guards':130,'new_nonzero_refusals':56,'complete_copied_byte_comparisons':208069,'complete_legacy_pairs':905,'legacy_success_pairs':770,'legacy_nonzero_pairs':135,'fixture_mutations_restored_for_control_and_final_bytes_equal':2,'skipped_pairs':0,'new_trace_files':93,'new_trace_lifecycles':trace['totals'],'new_kernel_positional_reads':trace['kernel_read_count'],'new_kernel_positional_writes_including_refusals':trace['kernel_write_count'],'old_digest_traces':28,'old_legacy_traces':3,'forbidden_access_matches':0,'opaque_worker_exit_records_retained_without_effect_inference':1,'audit_parser_failures_retained_and_corrected':True,'native_test_or_source_changes_for_audit':False,'new_production_mojo_files':3,'kernel_sealed_copy_qualified':True,'original_atomic_snapshot_verified':False,'source_fingerprint_verified':False,'binding_identity_verified':False,'execution_tested':False,'device_access':False,'whole_repository_pass':False,'hosted_ci_pass':False}
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..').replace(str(Path.home()/'mojo-dev'),'<mojo-runtime>')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copyjson(path,name):(dst/name).write_text(json.dumps(clean(json.load(open(path))),indent=2)+'\n')
for n in ('source-hashes.json','input-hashes.json','build-results.json','c-binaries.json','import-boundary.json'):copyjson(build/n,'build-'+n)
for n in ('source-hashes.json','test-input-hashes.json','controls.json','verified.json'):copyjson(Path('../sealed-copy-native-baseline')/n,'baseline-'+n)
for n in ('test-results.json','input-hashes.json','regression-summary.json','dependency-inspection.json','header-oracle.json','trace-audit.json','legacy-trace-audit.json','synthetic-mutation-audit.json'):copyjson(accept/n,n)
for sub in ('sealed','digest'):
 for n in ('summary.json','fixtures.json','trace-manifest.json','trace-audit.json'):copyjson(accept/n if sub=='digest' and n=='trace-audit.json' else accept/sub/n,sub+'-'+n)
for p in (accept/'pairs').glob('*.json'):copyjson(p,'pairs-'+p.name)
for r in checks:shutil.copy2(accept/(r['suite']+'-tests.txt'),dst/(r['suite']+'-tests.txt'))
for p in Path('../sealed-copy-native-development').iterdir():
 if p.is_file() and p.suffix in ('.py','.json','.txt','.log'):
  if p.suffix=='.json':copyjson(p,'development-'+p.name)
  else:(dst/('development-'+p.name)).write_text(clean(p.read_text()))
for n in ('opaque-termination-records.json','physical-lead-disposition.json','recording-correction.json'):copyjson(Path('../sealed-copy-native-recording')/n,n)
receipts=[]
for r in json.load(open(accept/'sealed/runs.json')):
 receipt={k:v for k,v in r.items() if k not in ('stdout','stderr')}
 for field in ('stdout','stderr'):
  value=r[field];receipt[field+'_bytes']=len(value.encode());receipt[field+'_sha256']=hashlib.sha256(value.encode()).hexdigest()
  if len(value)<=4096:receipt[field]=value
 receipts.append(receipt)
(dst/'native-call-receipts.json').write_text(json.dumps(clean(receipts),indent=2)+'\n');(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(r['binary']).name+'.build.log')).read_text() for r in rows));shutil.copy2(__file__,dst/'record-evidence.py')
for n in ('record-evidence-attempt1.py','evidence-attempt1-status.txt'):shutil.copy2(Path('../sealed-copy-native-recording')/n,dst/n)
archives=[]
for folder in ('sealed-copy-native-baseline','sealed-copy-native-development','sealed-copy-native-final','sealed-copy-native-acceptance'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n');print(json.dumps(summary,indent=2))
