from pathlib import Path
import hashlib,json,re,runpy,subprocess,sys
args=sys.argv[1:];report=Path(args.pop(0));script=args.pop(0)
rows=json.load(open('../sealed-gguf-native-final/build-results.json'));old={r['source']:r for r in json.load(open('../sealed-gguf-native-baseline/controls.json'))}
pairs={r['binary']:old[r['source']]['binary'] for r in rows if r['source'] in old};real=subprocess.run;records=[]
def pair(cmd,*a,**kw):
 c=list(map(str,cmd)) if isinstance(cmd,(tuple,list)) else [];found=next(((i,v) for i,v in enumerate(c) if v in pairs),None)
 qualifies=found and (found[0]==0 or Path(c[0]).name=='strace');before={}
 if qualifies:
  for v in c[found[0]+1:]:
   if len(v)<4096 and v.startswith('/'):
    p=Path(v)
    if p.is_file():before[v]=p.read_bytes()
 p=real(cmd,*a,**kw)
 if qualifies:
  i,key=found;after={v:Path(v).read_bytes() for v in before};changed={v for v in before if before[v]!=after[v]}
  opts=dict(kw);opts.pop('stdout',None);opts.pop('stderr',None);opts['capture_output']=True
  control_log_pairs=[]
  if opts.get('env') and 'AESIR_SEAL_FAULT_LOG' in opts['env']:
   control_env=dict(opts['env']);primary_log=Path(control_env['AESIR_SEAL_FAULT_LOG']);control_log=Path(str(primary_log)+'.frozen-control')
   assert primary_log.is_file() and not control_log.exists(),(primary_log,control_log)
   control_env['AESIR_SEAL_FAULT_LOG']=str(control_log);opts['env']=control_env
   control_log_pairs.append((primary_log,control_log,primary_log.read_bytes()))
  for v in changed:Path(v).write_bytes(before[v])
  try:
   control=real([pairs[key],*c[i+1:]],*a,**opts)
   for v in changed:assert Path(v).read_bytes()==after[v],('complete post-mutation bytes',v)
   for primary_log,control_log,primary_bytes in control_log_pairs:
    assert primary_log.read_bytes()==primary_bytes,('primary diagnostic log changed by control',primary_log)
    assert control_log.read_bytes()==primary_bytes,('complete independent fault logs differ',primary_log,control_log)
  finally:
   for v in changed:Path(v).write_bytes(after[v])
  assert p.returncode==control.returncode,('exit',c,p.stderr,control.stderr)
  assert p.stdout==control.stdout,('COMPLETE stdout',c,p.stdout,control.stdout)
  message=None
  if p.returncode:
   pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
   actual=p.stderr.decode() if isinstance(p.stderr,bytes) else p.stderr;expected=control.stderr.decode() if isinstance(control.stderr,bytes) else control.stderr
   n=re.search(pattern,actual or '');o=re.search(pattern,expected or '')
   assert bool(n)==bool(o),('error routing',c,actual,expected)
   if n:assert n[1]==o[1],('handled message',c,n[1],o[1]);message=n[1]
  output=p.stdout.encode() if isinstance(p.stdout,str) else p.stdout
  records.append({'binary':key,'control_binary':pairs[key],'arguments':c[i+1:],'returncode':p.returncode,'complete_stdout_equal':True,'stdout_sha256':hashlib.sha256(output).hexdigest(),'handled_error':message,'intentional_fixture_mutation_restored_for_control':sorted(changed),'complete_post_mutation_bytes_equal':bool(changed),'independent_complete_fault_logs_equal':bool(control_log_pairs),'control_fault_logs':[str(c) for p,c,b in control_log_pairs]})
 return p
subprocess.run=pair;sys.argv=[script,*args];sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(records,indent=2)+'\n')
