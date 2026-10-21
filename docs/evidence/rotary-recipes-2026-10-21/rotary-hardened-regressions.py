from pathlib import Path
import concurrent.futures
import json
import subprocess
import time

root = Path.cwd()
bins = Path('../rotary-hardened').resolve()
evidence = Path('../rotary-hardened-verification').resolve()
evidence.mkdir(exist_ok=True)
results = json.loads((bins/'build-results.json').read_text())
if any(item['returncode'] for item in results):
 print(json.dumps(results));raise SystemExit('a final build failed')

def tool(name):return str(bins/('tagged-'+name))
strace = '/usr/bin/strace'
def common(name, binary, api_name=None, **kwargs):
 command = ['python3', 'tests/test_hailo_'+name+'.py', '--binary', tool(binary)]
 if api_name:kwargs['api-binary']=tool(api_name)
 kwargs.update(strace=strace,evidence=str(evidence/name))
 for key, value in kwargs.items():command += ['--'+key,str(value)]
 return name,command
commands = [
 common('source_inventory','source-inventory'),
 common('semantic_plan','semantic-plan'),
 common('typed_decoder','semantic-plan',baseline='../semantic-storage-baseline/semantic-plan',typed=tool('typed-decoder'),api=tool('typed-api')),
 common('storage_estimate','storage-estimate','storage-api',**{'graph-binary':tool('semantic-plan')}),
 common('primitive_recipes','primitive-recipes','primitive-api',**{'graph-binary':tool('semantic-plan')}),
 common('expanded_graph','expanded-graph','expanded-api',**{'source-binary':tool('semantic-plan'),'recipe-binary':tool('primitive-recipes')}),
 common('expanded_storage','expanded-storage','expanded-storage-api',**{'graph-binary':tool('expanded-graph')}),
 common('matrix_tiles','matrix-tiles','matrix-api'),
 common('source_weight_tiles','source-weight-tiles','source-weight-api'),
 common('cache_layout','cache-layout','cache-api'),
 common('source_float_constants','float-constants','float-api'),
 common('source_q4k_constants','q4k-constants','q4k-api',**{'reference-library':'../ggml-format-study/build/src/libggml-base.so'}),
 common('source_q5q6_constants','q5q6-constants','q5q6-api',**{'reference-library':'../ggml-format-study/build/src/libggml-base.so'}),
 common('semantic_storage','semantic-storage',api=tool('semantic-storage-api'),binaries=bins,baseline='../decoder-graph-baseline'),
]
# common()'s optional positional API parameter is named api, so direct --api
# suites are constructed separately to retain each test's actual CLI.
for name,command in commands:
 if name in ('typed_decoder','semantic_storage'):
  for i,item in enumerate(command):
   if item=='--api-binary':command[i]='--api'

def run(item):
 name,command=item
 with (evidence/(name+'-test.txt')).open('w') as log:
  result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
 return {'suite':name,'returncode':result.returncode,'command':command}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 outcomes=list(pool.map(run,commands))
(evidence/'test-results.json').write_text(json.dumps(outcomes,indent=2)+'\n')
print([(x["suite"],x["returncode"]) for x in outcomes])
