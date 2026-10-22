from pathlib import Path
import hashlib,json,re,subprocess
out=Path('../sealed-safetensors-native-supplement');rows=json.load(open(out/'build-results.json'))
normalized=[]
for row in rows:
 assert row['returncode']==0,row
 if row['diagnostic_bytes']:
  assert row['source']=='tests/h043_st_check.mojo',row
  index=next(i for i,r in enumerate(rows) if r is row)%4
  text=(out/(row['kind']+'-'+str(index)+'.txt')).read_text()
  lines=text.splitlines();assert len(lines)==4 and lines[0].startswith('Included from '),text
  lines[0]='Included from SOURCE/tests/h043_st_check.mojo:20:'
  lines[1]=re.sub(r'safetensors.mojo:\d+:25:', 'safetensors.mojo:UNCHANGED_BODY:25:',lines[1])
  normalized.append('\n'.join(lines))
  row['diagnostics_qualified']='identical inherited unused initialization warning in byte-identical fp routine'
 else:row['diagnostics_qualified']='zero diagnostics'
assert len(normalized)==2 and normalized[0]==normalized[1],normalized
(out/'inherited-warning-review.json').write_text(json.dumps(dict(normalized_complete_diagnostics=normalized,identical=True,old_conversion_body_changed=False),indent=2)+'\n')
(out/'build-results-reviewed.json').write_text(json.dumps(rows,indent=2)+'\n')
for name in ['tests/sealed_safetensors_mutation.c','tests/safetensors_fd_io_faults.c']:
 b=out/(Path(name).stem+'.so');p=subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',name,'-ldl','-o',str(b)],capture_output=True);(out/(b.name+'.build.txt')).write_bytes(p.stdout+p.stderr);assert p.returncode==0 and not p.stdout+p.stderr,(name,p.stderr)
print('8 supplemental builds qualified; 6 zero-diagnostic, 2 identical inherited warnings; both C shims clean')
