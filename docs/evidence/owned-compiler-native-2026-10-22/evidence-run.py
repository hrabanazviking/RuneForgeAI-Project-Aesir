from pathlib import Path
import json,subprocess,hashlib,sys
root=Path('../owned-compiler-native-acceptance-v2');final=Path('../owned-compiler-native-final').resolve()
rows=json.load(open(final/'build-results.json'));b={r['source']:r['binary'] for r in rows};strace='/usr/bin/strace'
assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in rows)
assert all(hashlib.sha256(Path(r['binary']).read_bytes()).hexdigest()==r['sha256'] for r in rows)
def run(name,script,args):
 command=[sys.executable,str(root/'pair-all.py'),str(root/(name+'-pairs.json')),script,*map(str,args),'--strace',strace,'--evidence',str(root/name),'-v']
 with (root/(name+'.txt')).open('w') as log:p=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
 report.append(dict(name=name,script=script,returncode=p.returncode));(root/'test-results.json').write_text(json.dumps(report,indent=2)+'\n')
 print(name,p.returncode,flush=True)
report=[]
run('owned','tests/test_hailo_owned_gguf_compiler.py',['--binary',b['smidr/tools/owned_gguf_compiler.mojo'],'--api',b['tests/hailo_owned_gguf_api.mojo'],'--semantic',b['smidr/tools/semantic_plan.mojo'],'--recipes',b['smidr/tools/primitive_recipes.mojo'],'--expanded',b['smidr/tools/expanded_graph.mojo'],'--sealed-api',b['tests/hailo_sealed_gguf_api.mojo'],'--weight-tiles',b['smidr/tools/source_weight_tiles.mojo'],'--faults',final/'owned_gguf_faults.so'])
run('semantic','tests/test_hailo_semantic_plan.py',['--binary',b['smidr/tools/semantic_plan.mojo']])
run('sealed','tests/test_hailo_sealed_gguf_source.py',['--binary',b['smidr/tools/sealed_gguf_source.mojo'],'--api',b['tests/hailo_sealed_gguf_api.mojo'],'--semantic-api',b['tests/hailo_sealed_semantic_api.mojo'],'--semantic-control',b['smidr/tools/semantic_plan.mojo'],'--faults',final/'sealed_gguf_faults.so','--copy-faults',final/'source_sealed_copy_faults.so'])
assert all(r['returncode']==0 for r in report),report
