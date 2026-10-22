# Execute an existing targeted Python suite, pairing every successful native call
# with the untouched frozen binary on the same fixtures and exact arguments.
from pathlib import Path
import subprocess,runpy,sys,json,hashlib,re
root=Path.cwd();args=sys.argv[1:];report=Path(args.pop(0));script=args.pop(0)
rows=json.loads(Path('../dynamic-graph-baseline/controls.json').read_text())
pairs={}
for r in rows:
 new=root/'../dynamic-graph-final'/Path(r['binary']).name;old=str((root/r['binary']).resolve())
 for alias in (str(new),str(new.resolve()),str(Path('../dynamic-graph-final')/new.name)):pairs[alias]=old
real=subprocess.run;compared=[];diagnostics=[]
def paired(command,*a,**kw):
 result=real(command,*a,**kw)
 if isinstance(command,(list,tuple)):
  cmd=list(map(str,command));found=next(((i,item) for i,item in enumerate(cmd) if item in pairs),None)
  if found:
   i,key=found;control=[pairs[key],*cmd[i+1:]]
   # Ignore strace wrapping for the frozen call, preserving actual native argv.
   options=dict(kw);options.update(capture_output=True,stdout=None,stderr=None)
   # capture_output cannot coexist with explicitly supplied stdout/stderr.
   options.pop('stdout',None);options.pop('stderr',None)
   baseline=real(control,*a,**options)
   assert baseline.returncode==result.returncode,('frozen exit differs',cmd,result.stderr,baseline.stderr)
   assert result.stdout==baseline.stdout,('complete frozen stdout differs',cmd)
   if result.returncode==0:
    compared.append(dict(binary=key,arguments=cmd[i+1:],stdout_sha256=hashlib.sha256(result.stdout.encode() if isinstance(result.stdout,str) else result.stdout).hexdigest()))
   else:
    actual=result.stderr.decode() if isinstance(result.stderr,bytes) else result.stderr
    expected=baseline.stderr.decode() if isinstance(baseline.stderr,bytes) else baseline.stderr
    pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
    message=re.search(pattern,actual or '');old_message=re.search(pattern,expected or '')
    assert (message is None)==(old_message is None),('frozen handled-error boundary differs',cmd,actual,expected)
    if message:
     assert message[1]==old_message[1],('frozen handled diagnostic differs',cmd,message[1],old_message[1])
     diagnostics.append(dict(binary=key,arguments=cmd[i+1:],message=message[1],returncode=result.returncode))
 return result
subprocess.run=paired
sys.argv=[script,*args]
sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:
 report.write_text(json.dumps(dict(complete_stdout_pairs=len(compared),binary_count=len(set(r['binary'] for r in compared)),handled_diagnostic_pairs=len(diagnostics),diagnostics=diagnostics,calls=compared),indent=2)+'\n')
