from pathlib import Path
p=Path('../owned-ordinary-binding-native-development/prepare-v2.py')
s=p.read_text().replace('owned-ordinary-binding-native-acceptance-v2','owned-ordinary-binding-native-acceptance-v3')
exec(compile(s,str(p),'exec'))
out=Path('../owned-ordinary-binding-native-acceptance-v3');p=out/'pair-all.py';s=p.read_text()
s=s.replace('records=[];native_calls=[]','records=[];native_calls=[];raw_outputs=[]\nraw_folder=report.parent/(report.stem+"-raw");raw_folder.mkdir(exist_ok=False)\ndef save_output(result,kind,arguments):\n number=len(raw_outputs);paths={}\n for field in ("stdout","stderr"):\n  value=getattr(result,field);data=value.encode() if isinstance(value,str) else value or b""\n  path=raw_folder/(f"{number:05d}."+field);path.write_bytes(data);paths[field]=dict(path=str(path),bytes=len(data),sha256=hashlib.sha256(data).hexdigest())\n raw_outputs.append(dict(kind=kind,arguments=arguments,returncode=result.returncode,**paths))')
s=s.replace(" if known and (known[0]==0 or Path(c[0]).name=='strace'):\n  output=", " if known and (known[0]==0 or Path(c[0]).name=='strace'):\n  save_output(p,'primary',c)\n  output=")
s=s.replace("   control=real([pairs[key],*c[i+1:]],*a,**opts)","   control=real([pairs[key],*c[i+1:]],*a,**opts)\n   save_output(control,'frozen_comparison',[pairs[key],*c[i+1:]])")
s+='\n report.with_name(report.stem+"-full-outputs.json").write_text(json.dumps(raw_outputs,indent=2)+"\\n")\n'
# This final statement remains in the existing try/finally indentation.
compile(s,str(p),'exec');p.write_text(s)
p=Path('../owned-ordinary-binding-native-development/run-acceptance-v2.py');Path('../owned-ordinary-binding-native-development/run-acceptance-v3.py').write_text(p.read_text().replace('owned-ordinary-binding-native-acceptance-v2','owned-ordinary-binding-native-acceptance-v3'))
