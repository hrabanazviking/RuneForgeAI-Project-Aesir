"""Run the unchanged old action suite with complete frozen-success/error pairs."""
import hashlib,json,re,runpy,subprocess,sys
from pathlib import Path
r=Path.cwd();out=Path('../lcu-action-final/legacy');out.mkdir(exist_ok=True)
pairs={str((r/'../lcu-action-final'/n).resolve()):str((r/'..'/b).resolve()) for n,b in [('old-inspector','context-actions'),('old-ownership','context-action-ownership'),('old-oracle','context-action-oracle')]}
real=subprocess.run;records=[]
def pair(cmd,*args,**kw):
 result=real(cmd,*args,**kw)
 if isinstance(cmd,(tuple,list)):
  c=list(map(str,cmd));found=next(((i,s) for i,s in enumerate(c) if s in pairs),None)
  if found:
   i,key=found;frozen=[pairs[key],*c[i+1:]];opts=dict(kw)
   opts.pop('stdout',None);opts.pop('stderr',None);opts['capture_output']=True
   old=real(frozen,*args,**opts)
   assert result.returncode==old.returncode,(c,'exit')
   assert result.stdout==old.stdout,(c,'stdout')
   if result.returncode:
    pattern=r'Unhandled exception caught during execution:\s*([^\n]+)'
    a=re.search(pattern,result.stderr or '');b=re.search(pattern,old.stderr or '')
    assert bool(a)==bool(b),(c,'error routing')
    if a:assert a[1]==b[1],(c,'error message')
   records.append({'binary':Path(key).name,'arguments':c[i+1:],'returncode':result.returncode,'stdout_sha256':hashlib.sha256(result.stdout.encode()).hexdigest()})
 return result
subprocess.run=pair
script='tests/test_hailo_context_actions.py';sys.path.insert(0,str(r/'tests'))
sys.argv=[script,'--binary',str((r/'../lcu-action-final/old-inspector').resolve()),'--ownership',str((r/'../lcu-action-final/old-ownership').resolve()),'--oracle',str((r/'../lcu-action-final/old-oracle').resolve()),'--strace','strace','--evidence',str(out)]
try:runpy.run_path(script,run_name='__main__')
finally:(out/'frozen-pairs.json').write_text(json.dumps(records,indent=2)+'\n')
