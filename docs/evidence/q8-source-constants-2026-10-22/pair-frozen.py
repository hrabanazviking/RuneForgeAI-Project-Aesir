"""Pair every existing native result against the current pre-code controls."""
from pathlib import Path
import hashlib,json,re,runpy,subprocess,sys
root=Path.cwd();args=sys.argv[1:];report=Path(args.pop(0));script=args.pop(0)
controls=json.loads(Path('../q8-source-baseline/controls.json').read_text())
pairs={str((root/'../q8-source-final'/Path(x['binary']).name).resolve()):str((root/x['binary']).resolve()) for x in controls}
for x in controls:
 new=str(Path('../q8-source-final')/Path(x['binary']).name);pairs[new]=str((root/x['binary']).resolve())
real=subprocess.run;rows=[]
def pair(cmd,*a,**kw):
 p=real(cmd,*a,**kw)
 if isinstance(cmd,(tuple,list)):
  c=list(map(str,cmd));found=next(((i,v) for i,v in enumerate(c) if v in pairs),None)
  if found:
   i,key=found;opts=dict(kw);opts.pop('stdout',None);opts.pop('stderr',None);opts['capture_output']=True
   old=real([pairs[key],*c[i+1:]],*a,**opts)
   assert p.returncode==old.returncode,('frozen exit',c,p.stderr,old.stderr)
   assert p.stdout==old.stdout,('complete stdout',c)
   msg=None
   if p.returncode:
    pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
    actual=p.stderr.decode() if isinstance(p.stderr,bytes) else p.stderr
    expected=old.stderr.decode() if isinstance(old.stderr,bytes) else old.stderr
    n=re.search(pattern,actual or '');o=re.search(pattern,expected or '')
    assert bool(n)==bool(o),('error routing',c,actual,expected)
    if n:assert n[1]==o[1],('error message',c,n[1],o[1]);msg=n[1]
   output=p.stdout.encode() if isinstance(p.stdout,str) else p.stdout
   rows.append({'binary':str(Path(key).resolve()),'arguments':c[i+1:],'returncode':p.returncode,'stdout_sha256':hashlib.sha256(output).hexdigest(),'handled_error':msg})
 return p
subprocess.run=pair;sys.argv=[script,*args];sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:report.parent.mkdir(parents=True,exist_ok=True);report.write_text(json.dumps(rows,indent=2)+'\n')
