from pathlib import Path
import json,runpy,subprocess,sys
out=Path(sys.argv[1]);script=sys.argv[2];args=sys.argv[3:];out.mkdir(exist_ok=False);meta=json.loads(Path(__file__).with_name('meta.json').read_text());real=subprocess.run;records=[]
def raw(v):return v.encode() if isinstance(v,str) else v or b''
def save(p,prefix):
 for ch in ['stdout','stderr']:(out/(prefix+'.'+ch)).write_bytes(raw(getattr(p,ch)))
def run(cmd,*a,**kw):
 c=list(map(str,cmd));found=next(((i,b) for i,b in enumerate(c) if b in meta['known']),None)
 if not found or (found[0]!=0 and Path(c[0]).name!='strace'):return real(cmd,*a,**kw)
 i,b=found;n=len(records);actual=c
 if b in meta['traced']:actual=['strace','-f','-yy','-s','300','-o',str(out/f'{n}.strace'),*c]
 p=real(actual,*a,**kw);save(p,str(n)+'.current');r=dict(source=meta['known'][b],arguments=c,returncode=p.returncode,traced=b in meta['traced'])
 if b in meta['pairs']:
  other=c.copy();other[i]=meta['pairs'][b];q=real(other,*a,**kw);save(q,str(n)+'.frozen');r.update(frozen_arguments=other,frozen_returncode=q.returncode,equal=(p.returncode,raw(p.stdout),raw(p.stderr))==(q.returncode,raw(q.stdout),raw(q.stderr)));records.append(r);assert r['equal'],r
 else:records.append(r)
 return p
subprocess.run=run;sys.argv=[script,*args];sys.path.insert(0,str(Path(script).resolve().parent))
try:runpy.run_path(script,run_name='__main__')
finally:(out/'records.json').write_text(json.dumps(records,indent=2)+'\n')
