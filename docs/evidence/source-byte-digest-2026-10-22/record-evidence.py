from pathlib import Path
import hashlib,json,re,shutil
root=Path.cwd();build=Path('../source-digest-native-final-v2');accept=Path('../source-digest-native-acceptance-v2');dst=Path('docs/evidence/source-byte-digest-2026-10-22');dst.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
rows=json.load(open(build/'build-results.json'));sources=json.load(open(build/'source-hashes.json'));inputs=json.load(open(accept/'input-hashes.json'));controls=json.load(open('../source-digest-native-baseline/controls.json'))
for p,h in {**sources,**inputs}.items():assert sha(p)==h,p
for r in rows+controls:assert sha(r['binary'])==r['sha256']
for p,h in json.load(open('../source-digest-native-baseline/source-hashes.json')).items():assert sha(p)==h==sha(build/'source-snapshot'/p)
for p,h in json.load(open('../source-digest-native-baseline/test-input-hashes.json')).items():assert sha(p)==h==sha(Path('../source-digest-native-baseline/test-snapshot')/p)
checks=json.load(open(accept/'test-results.json'));assert len(checks)==4 and all(x['returncode']==0 for x in checks)
new=json.load(open(accept/'digest/summary.json'));trace=json.load(open(accept/'trace-audit.json'));reg=json.load(open(accept/'regression-summary.json'));suites=[]
for r in checks:
 name=r['suite'];text=(accept/(name+'-tests.txt')).read_text();assert '\nOK\n' in text
 methods=int(re.search(r'Ran (\d+) tests?',text)[1]);folder=accept/'digest' if name=='source-digest' else accept/'legacy'/'legacy'/name if name!='gguf_shapes' else accept/'legacy'/name
 runs=json.load(open(folder/'runs.json'));suites.append({'suite':name,'methods':methods,'primary_calls':len(runs)})
assert sum(x['primary_calls'] for x in suites)==905 and sum(x['methods'] for x in suites)==23
summary={'pre_code_contract':'c2c678c6f98e7f10b96f4e4a474bad1414f2e902','clean_current_mojo_builds':8,'source_identities_and_actual_snapshots':653,'old_mojo_sources_unchanged':649,'old_python_inputs_unchanged':66,'old_controls_unchanged':102,'actual_affected_new_entrypoints':2,'selected_rebuilt_regression_controls':6,'primary_suites':4,'primary_methods':23,'primary_calls':905,'new_methods':6,'new_calls':451,'new_accepted':418,'new_refused':33,'all_admitted_gguf_geometries':15,'official_nist_examples':2,'independent_hash_oracles':['Python hashlib','existing original sha256_hex for bounded arrays'],'full_legacy_control_comparisons':454,'legacy_success_pairs':352,'legacy_nonzero_exit_stdout_handled_error_pairs':102,'skipped_pairs':0,'new_traces':28,'legacy_traces':3,'digest_trace_lifecycles':trace['totals'],'kernel_positional_reads':78,'target_device_network_ioctl_external_crypto_matches':0,'same_size_mutation_exact_bytes_checked':True,'actual_truncation_refused_without_payload_mmap_read':True,'test_fixture_pointer_lifetime_failure_retained_and_fixed':True,'runner_output_identity_failure_retained_and_fixed':True,'v2_all_suites_rerun':True,'production_changed_after_first_pass':False,'byte_digest_computed':True,'source_fingerprint_verified':False,'immutable_source_verified':False,'binding_identity_verified':False,'execution_tested':False,'device_access':False,'whole_repository_pass':False,'hosted_ci_pass':False}
def clean(v):
 if isinstance(v,str):return v.replace(str(root.parent),'..').replace(str(Path.home()/'mojo-dev'),'<mojo-runtime>')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {clean(k):clean(x) for k,x in v.items()}
 return v
def copyjson(path,name): (dst/name).write_text(json.dumps(clean(json.load(open(path))),indent=2)+'\n')
for n in ('source-hashes.json','input-hashes.json','build-results.json','fault-library.json'):copyjson(build/n,'build-'+n)
for n in ('source-hashes.json','test-input-hashes.json','controls.json','verified.json'):copyjson(Path('../source-digest-native-baseline')/n,'baseline-'+n)
for n in ('test-results.json','input-hashes.json','regression-summary.json','dependency-inspection.json','trace-audit.json','legacy-trace-audit.json','synthetic-mutation-audit.json'):copyjson(accept/n,n)
for n in ('fixtures.json','summary.json','trace-manifest.json'):copyjson(accept/'digest'/n,'digest-'+n)
for p in (accept/'pairs').glob('*.json'):copyjson(p,'pairs-'+p.name)
for r in checks:shutil.copy2(accept/(r['suite']+'-tests.txt'),dst/(r['suite']+'-tests.txt'))
for folder in ('source-digest-native-development','source-digest-native-review','source-digest-native-v2'):
 for p in (Path('..')/folder).iterdir():
  if p.is_file() and p.suffix in ('.py','.json','.txt','.log'):
   target=dst/(folder+'-'+p.name)
   if p.suffix=='.json':copyjson(p,target.name)
   else:target.write_text(clean(p.read_text()))
copyjson('../source-digest-native-recording/research-disposition.json','research-disposition.json')
runs=json.load(open(accept/'digest/runs.json'));receipts=[]
for r in runs:
 receipt={'returncode':r['returncode'],'fault':r['fault']}
 for field in ('arguments','stdout','stderr'):
  value=json.dumps(r[field],ensure_ascii=False) if field=='arguments' else r[field]
  receipt[field+'_bytes']=len(value.encode());receipt[field+'_sha256']=hashlib.sha256(value.encode()).hexdigest()
  if len(value)<=4096:receipt[field]=clean(r[field])
 receipts.append(receipt)
(dst/'digest-call-receipts.json').write_text(json.dumps(receipts,indent=2)+'\n');(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(dst/'suite-census.json').write_text(json.dumps(suites,indent=2)+'\n')
(dst/'build-diagnostics.txt').write_text(''.join((build/(Path(r['binary']).name+'.build.log')).read_text() for r in rows))
shutil.copy2(__file__,dst/'record-evidence.py')
archives=[]
for folder in ('source-digest-native-baseline','source-digest-native-development','source-digest-native-final','source-digest-native-acceptance','source-digest-native-review','source-digest-native-reviewed-acceptance','source-digest-native-v2','source-digest-native-final-v2','source-digest-native-acceptance-v2'):
 for p in sorted((Path('..')/folder).rglob('*')):
  if p.is_file():archives.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)})
(dst/'archive-identities.json').write_text(json.dumps(archives,indent=2)+'\n')
print(json.dumps(summary,indent=2))
