from pathlib import Path
import hashlib,json,os
root=Path(__file__).resolve().parent;final=Path('../sealed-safetensors-native-final').resolve();supp=Path('../sealed-safetensors-native-supplement').resolve()
rows=json.load(open(final/'build-results.json'));extra=json.load(open(supp/'build-results-reviewed.json'));old=json.load(open('../sealed-safetensors-native-baseline/controls.json'))
assert len(rows)==113 and all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
assert len(extra)==8 and all(r['returncode']==0 and r.get('diagnostics_qualified') for r in extra)
current={r['source']:r['binary'] for r in rows};frozen={r['source']:r['binary'] for r in old}
for r in extra:(current if r['kind']=='current' else frozen)[r['source']]=r['binary']
assert len(current)==117 and len(frozen)==115
aliases={}
def add(row):
 if isinstance(row,dict) and 'source' in row and 'binary' in row and row['source'] in current:
  p=Path(row['binary']);key=str(p.resolve())
  if key in aliases:assert aliases[key]==row['source'],row
  aliases[key]=row['source']
for r in old+rows+extra:add(r)
# Earlier canonical commands refer to qualified historical binary aliases.
for p in Path('..').glob('*/build-results.json'):
 data=json.load(open(p))
 if isinstance(data,list):
  for r in data:add(r)
for p in ['../sealed-gguf-native-final/consumer-inventory.json','../sealed-gguf-native-baseline/controls.json']:
 for r in json.load(open(p)):add(r)
pairs={current[s]:frozen[s] for s in frozen}
(root/'universe.json').write_text(json.dumps(dict(current=current,frozen=frozen,aliases=aliases,pairs=pairs),indent=2)+'\n')
def remap(arg):
 return current[aliases[str(Path(arg).resolve())]] if str(Path(arg).resolve()) in aliases else arg
jobs=[]
for row in json.load(open('../sealed-gguf-native-closure/canonical-test-results.json')):
 c=list(row['command']);start=next(i for i,v in enumerate(c) if v.startswith('tests/test_'));script=c[start];args=c[start+1:]
 if '--evidence' in args:args[args.index('--evidence')+1]=str(root/row['suite'])
 else:
  assert row['suite']=='context' and '--result' in args,(row['suite'],args)
  args[args.index('--result')+1]=str(root/(row['suite']+'-report.json'))
 if '--binaries' in args:
  directory=Path(args[args.index('--binaries')+1]);dest=root/'binaries';dest.mkdir(exist_ok=True)
  for p in directory.iterdir():
   if not p.is_file():continue
   resolved=str(p.resolve());assert resolved in aliases,(p,resolved)
   target=Path(current[aliases[resolved]]);link=dest/p.name
   if link.exists():assert link.resolve()==target
   else:link.symlink_to(target)
  args[args.index('--binaries')+1]=str(dest)
 args=[remap(a) for a in args]
 # Keep the qualified standalone C fault shims, except the shared sealed seams.
 for i,a in enumerate(args):
  if a.endswith('/parser-faults.so'):args[i]=str(final/'sealed_gguf_faults.so')
  elif a.endswith('/copy-faults.so'):args[i]=str(final/'source_sealed_copy_faults.so')
 jobs.append(dict(suite=row['suite'],python=c[0],script=script,args=args))
def addjob(name,script,args,python='/usr/bin/python3'):
 jobs.append(dict(suite=name,python=python,script=script,args=list(map(str,args))+['--strace','/usr/bin/strace','--evidence',str(root/name)]))
addjob('owned-compiler','tests/test_hailo_owned_gguf_compiler.py',['--binary',current['smidr/tools/owned_gguf_compiler.mojo'],'--api',current['tests/hailo_owned_gguf_api.mojo'],'--semantic',current['smidr/tools/semantic_plan.mojo'],'--recipes',current['smidr/tools/primitive_recipes.mojo'],'--expanded',current['smidr/tools/expanded_graph.mojo'],'--sealed-api',current['tests/hailo_sealed_gguf_api.mojo'],'--weight-tiles',current['smidr/tools/source_weight_tiles.mojo'],'--faults',final/'owned_gguf_faults.so'])
addjob('safetensors-inventory','tests/test_hailo_safetensors_inventory.py',['--binary',current['smidr/tools/safetensors_inventory.mojo'],'--api',current['tests/hailo_safetensors_inventory_api.mojo'],'--legacy',current['tests/h043_st_check.mojo']])
addjob('safetensors-fd','tests/test_hailo_safetensors_fd.py',['--binary',current['smidr/tools/safetensors_fd.mojo'],'--api',current['tests/hailo_safetensors_fd_api.mojo'],'--inventory',current['smidr/tools/safetensors_inventory.mojo'],'--baseline',frozen['smidr/tools/safetensors_inventory.mojo'],'--faults',supp/'safetensors_fd_io_faults.so'])
addjob('sealed-safetensors','tests/test_hailo_sealed_safetensors_source.py',['--binary',current['smidr/tools/sealed_safetensors_source.mojo'],'--api',current['tests/hailo_sealed_safetensors_api.mojo'],'--constants',current['smidr/tools/safetensors_constants.mojo'],'--inventory',current['smidr/tools/safetensors_inventory.mojo'],'--faults',final/'sealed_gguf_faults.so','--copy-faults',final/'source_sealed_copy_faults.so','--mutation-faults',supp/'sealed_safetensors_mutation.so'])
assert len(jobs)==50
(root/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
print('prepared',len(jobs),'suites',len(current),'current entries',len(frozen),'frozen controls')
