"""Complete old/new outputs for actual source-identified compiler controls."""
from pathlib import Path
import hashlib,json,re,runpy,subprocess,sys
root=Path.cwd();args=sys.argv[1:];report=Path(args.pop(0));script=args.pop(0)
rows=json.loads(Path('../iq4-native-final/build-results.json').read_text())
controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text())
old={x['source']:x for x in controls}
pairs={x['binary']:str((root/old[x['source']]['binary']).resolve()) for x in rows if x['source'] in old}
for x in rows:
 if x['binary'] in pairs:pairs[str(Path('../iq4-native-final')/Path(x['binary']).name)]=pairs[x['binary']]
real=subprocess.run;records=[]
def pair(cmd,*a,**kw):
 p=real(cmd,*a,**kw)
 if isinstance(cmd,(tuple,list)):
  c=list(map(str,cmd));found=next(((i,v) for i,v in enumerate(c) if v in pairs),None)
  if found and (found[0] == 0 or Path(c[0]).name == "strace"):
   i,key=found;opts=dict(kw);opts.pop('stdout',None);opts.pop('stderr',None);opts['capture_output']=True
   control=real([pairs[key],*c[i+1:]],*a,**opts)
   assert p.returncode==control.returncode,('exit',c,p.stderr,control.stderr)
   assert p.stdout==control.stdout,('complete stdout',c)
   msg=None
   if p.returncode:
    pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
    actual=p.stderr.decode() if isinstance(p.stderr,bytes) else p.stderr
    expected=control.stderr.decode() if isinstance(control.stderr,bytes) else control.stderr
    n=re.search(pattern,actual or '');o=re.search(pattern,expected or '')
    assert bool(n)==bool(o),('error routing',c,actual,expected)
    if n:assert n[1]==o[1],('handled message',c,n[1],o[1]);msg=n[1]
   output=p.stdout.encode() if isinstance(p.stdout,str) else p.stdout
   records.append({'binary':str(Path(key).resolve()),'control_binary':pairs[key],'arguments':c[i+1:],'returncode':p.returncode,'stdout_sha256':hashlib.sha256(output).hexdigest(),'handled_error':msg})
 return p
subprocess.run=pair;sys.argv=[script,*args];sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(records,indent=2)+'\n')
