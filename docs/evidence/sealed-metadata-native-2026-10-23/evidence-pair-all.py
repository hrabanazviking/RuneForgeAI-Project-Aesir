from pathlib import Path
import hashlib,json,re,runpy,subprocess,sys
args=sys.argv[1:];report=Path(args.pop(0));script=args.pop(0)
universe=json.load(open(Path(__file__).with_name('universe.json')));pairs=universe['pairs'];real=subprocess.run;records=[];native_calls=[]
identities={str(Path(v).resolve()):{'source':k,'kind':kind} for kind in ('frozen','current') for k,v in universe[kind].items()}
def pair(cmd,*a,**kw):
 c=list(map(str,cmd)) if isinstance(cmd,(tuple,list)) else [];found=next(((i,str(Path(v).resolve())) for i,v in enumerate(c) if str(Path(v).resolve()) in pairs),None)
 qualifies=found and (found[0]==0 or Path(c[0]).name=='strace');before={}
 if qualifies:
  for v in c[found[0]+1:]:
   if len(v)<4096 and v.startswith('/'):
    p=Path(v)
    if p.is_file():before[v]=p.read_bytes()
  # The fd replacement API names the original through root + label and
  # renames away its explicit alternate. Capture both full preimages.
  i,key=found
  if identities[key]['source']=='tests/hailo_safetensors_fd_api.mojo' and c[i+1]=='replace':
   original=Path(c[i+2])/c[i+3];alternate=Path(c[i+4])
   assert original.is_file() and alternate.is_file(),c
   before[str(original)]=original.read_bytes();before[str(alternate)]=alternate.read_bytes()
 p=real(cmd,*a,**kw)
 known=next(((i,str(Path(v).resolve())) for i,v in enumerate(c) if str(Path(v).resolve()) in identities),None)
 if known and (known[0]==0 or Path(c[0]).name=='strace'):
  output=p.stdout.encode() if isinstance(p.stdout,str) else p.stdout or b''
  error=p.stderr.encode() if isinstance(p.stderr,str) else p.stderr or b''
  native_calls.append({'binary':known[1],**identities[known[1]],'arguments':c,'returncode':p.returncode,'stdout_sha256':hashlib.sha256(output).hexdigest(),'stderr_sha256':hashlib.sha256(error).hexdigest(),'stdout_bytes':len(output),'stderr_bytes':len(error)})
 if qualifies:
  i,key=found;after={v:Path(v).read_bytes() if Path(v).is_file() else None for v in before};changed={v for v in before if before[v]!=after[v]}
  def restore(v,data):
   if data is None:Path(v).unlink(missing_ok=True)
   else:Path(v).write_bytes(data)
  opts=dict(kw);opts.pop('stdout',None);opts.pop('stderr',None);opts['capture_output']=True
  control_log_pairs=[]
  if opts.get('env') and 'AESIR_SEAL_FAULT_LOG' in opts['env']:
   control_env=dict(opts['env']);primary_log=Path(control_env['AESIR_SEAL_FAULT_LOG']);control_log=Path(str(primary_log)+'.frozen-control')
   assert primary_log.is_file() and not control_log.exists(),(primary_log,control_log)
   control_env['AESIR_SEAL_FAULT_LOG']=str(control_log);opts['env']=control_env
   control_log_pairs.append((primary_log,control_log,primary_log.read_bytes()))
  for v in changed:restore(v,before[v])
  try:
   control=real([pairs[key],*c[i+1:]],*a,**opts)
   for v in changed:assert (Path(v).read_bytes() if Path(v).is_file() else None)==after[v],('complete post-mutation bytes and deletion state',v)
   for primary_log,control_log,primary_bytes in control_log_pairs:
    assert primary_log.read_bytes()==primary_bytes,('primary diagnostic log changed by control',primary_log)
    assert control_log.read_bytes()==primary_bytes,('complete independent fault logs differ',primary_log,control_log)
  finally:
   for v in changed:restore(v,after[v])
  assert p.returncode==control.returncode,('exit',c,p.stderr,control.stderr)
  assert p.stdout==control.stdout,('COMPLETE stdout',c,p.stdout,control.stdout)
  assert p.stderr==control.stderr,('COMPLETE stderr',c,p.stderr,control.stderr)
  message=None
  if p.returncode:
   pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
   actual=p.stderr.decode() if isinstance(p.stderr,bytes) else p.stderr;expected=control.stderr.decode() if isinstance(control.stderr,bytes) else control.stderr
   n=re.search(pattern,actual or '');o=re.search(pattern,expected or '')
   assert bool(n)==bool(o),('error routing',c,actual,expected)
   if n:assert n[1]==o[1],('handled message',c,n[1],o[1]);message=n[1]
  output=p.stdout.encode() if isinstance(p.stdout,str) else p.stdout
  records.append({'binary':key,'control_binary':pairs[key],'arguments':c[i+1:],'returncode':p.returncode,'complete_stdout_equal':True,'complete_stderr_equal':True,'stdout_sha256':hashlib.sha256(output).hexdigest(),'handled_error':message,'intentional_fixture_mutation_restored_for_control':sorted(changed),'complete_post_mutation_bytes_equal':bool(changed),'complete_mutation_images':[dict(path=v,before_hex=before[v].hex(),after_hex=after[v].hex() if after[v] is not None else None) for v in sorted(changed)],'independent_complete_fault_logs_equal':bool(control_log_pairs),'control_fault_logs':[str(c) for p,c,b in control_log_pairs]})
 return p
subprocess.run=pair;sys.argv=[script,*args];sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:
 report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(records,indent=2)+'\n')
 report.with_name(report.stem+'-native-calls.json').write_text(json.dumps(native_calls,indent=2)+'\n')
