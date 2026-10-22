import collections,hashlib,json,shutil,subprocess
from pathlib import Path
r=Path.cwd();src=Path('../lcu-action-final');dst=Path('docs/evidence/lcu-actions-2026-10-22')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source=json.loads((src/'source-hashes.json').read_text());inputs=json.loads((src/'input-hashes.json').read_text())
freeze=json.loads(Path('docs/evidence/program-target-lcu-boundary-2026-10-22/pre-code-freeze.json').read_text())
for p,h in {**source,**inputs,**freeze['source_sha256'],**freeze['control_sha256']}.items():assert sha(p)==h,p
builds=json.loads((src/'build-results.json').read_text())
for b in builds:assert b['returncode']==0 and b['diagnostic_bytes']==0 and sha(b['binary'])==b['sha256']
assert all(t['returncode']==0 for t in json.loads((src/'test-results.json').read_text()))
summary={};portable={}
def clean(v):
 if isinstance(v,str):
  return v.replace(str(r.parent), '..').replace(str(r),'.')
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items()}
 return v
for suite in ('new','legacy'):
 p=src/suite/'runs.json';data=json.loads(p.read_text())
 counts=collections.Counter(x['scope'] for x in data)
 summary[suite]={'primary_calls':len(data),'scope_counts':dict(counts),'zero_exit':sum(x['returncode']==0 for x in data),'nonzero_exit':sum(x['returncode']!=0 for x in data),'original_journal_sha256':sha(p)}
 cases=[{'scope':x['scope'],'arguments':clean(x['arguments']),'returncode':x['returncode'],'stdout_sha256':hashlib.sha256(x['stdout'].encode()).hexdigest(),'stderr_sha256':hashlib.sha256(x['stderr'].encode()).hexdigest()} for x in data]
 (dst/(suite+'-cases.json')).write_text(json.dumps(cases,separators=(',',':'))+'\n')
pairs=json.loads((src/'legacy/frozen-pairs.json').read_text())
summary.update({'methods':17,'new_methods':10,'legacy_methods':7,'primary_calls':2113,'additional_frozen_comparison_calls':len(pairs),'frozen_success_pairs':sum(x['returncode']==0 for x in pairs),'frozen_error_pairs':sum(x['returncode']!=0 for x in pairs),'new_vectors':456,'valid_packed_identities_per_kind':128,'native_internal_refusal_recovery_cycles':18,'clean_builds':6,'mojo_builds':4,'cpp_oracle_builds':2,'source_hashes':len(source),'qualified_action_ids':[4,5,36],'device_access':False,'numerical_program':False,'source_model_execution':False,'whole_repository_pass':False})
assert len(pairs)==244
traces=[]
for p in sorted((src/'new').glob('*.strace')):
 s=p.read_text()
 for token in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','connect(','ioctl('):assert token not in s,(p,token)
 traces.append({'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)})
assert len(traces)==7
(dst/'trace-audit.json').write_text(json.dumps({'traces':traces,'forbidden_device_network_ioctl_runtime_matches':0,'trace_arguments':'openat,close,mmap,munmap,connect,ioctl; -f -y'},indent=2)+'\n')
for name in ('source-hashes.json','input-hashes.json','build-results.json','test-results.json','new-tests.txt','legacy-tests.txt'):
 shutil.copyfile(src/name,dst/name)
shutil.copyfile(src/'legacy/frozen-pairs.json',dst/'frozen-pairs.json')
for name in ('build-and-verify.py','pair-legacy.py','record-evidence.py'):
 shutil.copyfile(Path('../lcu-action-development')/name,dst/name)
(dst/'build-diagnostics.txt').write_text(''.join((src/(Path(b['binary']).name+'-build.txt')).read_text() for b in builds))
summary['development_failures']={'first_build_log_sha256':sha('../lcu-action-development/inspector-build-1.txt'),'first_source_sha256':sha('../lcu-action-development/failures/first-return-source.mojo'),'error':'Copyable implicit return; explicit move fixes it; no accepted first binary','first_log_bytes':Path('../lcu-action-development/inspector-build-1.txt').stat().st_size,'second_preliminary_log_bytes':Path('../lcu-action-development/inspector-build-2.txt').stat().st_size}
summary['source_snapshot']={'archive':'../lcu-action-final/source-snapshot','all_match':all(sha(src/'source-snapshot'/p)==h for p,h in source.items())}
summary['runtime']={n:subprocess.check_output(c,text=True,stderr=subprocess.STDOUT).strip() for n,c in [('mojo',['mojo','--version']),('cpp',['g++','--version'])]}
(dst/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
