from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json,os,subprocess
out=Path('../classic32-source-selected');out.mkdir(exist_ok=False)
pairs=[('smidr/tools/source_classic32_constants.mojo','constants'),('tests/hailo_source_classic32_api.mojo','api'),('smidr/tools/source_weight_tiles.mojo','tiles'),('tests/hailo_source_weight_tiles_api.mojo','tile-api'),('smidr/tools/source_inventory.mojo','inventory'),('smidr/tools/semantic_plan.mojo','semantic')]
def build(x):
 src,name=x
 p=subprocess.run(['mojo','build','-I','.','-I','aesir_engine','-I','tests',src,'-o',str(out/name)],capture_output=True,text=True,env=dict(os.environ,MODULAR_CACHE_DIR='../mojo-cache'),timeout=300)
 (out/(name+'-build.txt')).write_text(p.stdout+p.stderr);print(name,p.returncode,len(p.stdout+p.stderr),flush=True)
 return {'source':src,'binary':str(out/name),'returncode':p.returncode,'diagnostic_bytes':len(p.stdout+p.stderr)}
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(build,pairs))
(out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n');assert all(r['returncode']==0 and r['diagnostic_bytes']==0 for r in results)
cmd=['python3','tests/test_hailo_source_classic32_constants.py','--binary',str(out/'constants'),'--api',str(out/'api'),'--tile',str(out/'tiles'),'--tile-api',str(out/'tile-api'),'--inventory',str(out/'inventory'),'--semantic',str(out/'semantic'),'--reference-library','../ggml-format-study/build/src/libggml-base.so.0.27.0','--strace','/usr/bin/strace','--evidence',str(out/'acceptance')]
p=subprocess.run(cmd,capture_output=True,text=True,timeout=300);(out/'tests.txt').write_text(p.stdout+p.stderr);print('new-suite',p.returncode,flush=True);assert p.returncode==0
