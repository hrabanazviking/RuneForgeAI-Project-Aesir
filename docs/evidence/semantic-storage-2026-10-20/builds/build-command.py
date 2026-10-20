import concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
pairs=[["smidr/tools/semantic_plan.mojo","tagged-semantic-plan"],["tests/hailo_typed_decoder_api.mojo","tagged-typed-api"],["smidr/tools/expanded_graph.mojo","tagged-expanded-graph"],["tests/hailo_expanded_api.mojo","tagged-expanded-api"],["smidr/tools/expanded_storage.mojo","tagged-expanded-storage"],["tests/hailo_expanded_storage_api.mojo","tagged-expanded-storage-api"],["smidr/tools/matrix_tiles.mojo","tagged-matrix-tiles"],["tests/hailo_matrix_tiles_api.mojo","tagged-matrix-api"],["smidr/tools/primitive_recipes.mojo","tagged-primitive-recipes"],["tests/hailo_recipe_api.mojo","tagged-primitive-api"],["smidr/tools/cache_layout.mojo","tagged-cache-layout"],["tests/hailo_cache_layout_api.mojo","tagged-cache-api"],["smidr/tools/source_weight_tiles.mojo","tagged-source-weight-tiles"],["tests/hailo_source_weight_tiles_api.mojo","tagged-source-weight-api"],["smidr/tools/storage_estimate.mojo","tagged-storage-estimate"],["tests/hailo_storage_api.mojo","tagged-storage-api"],["smidr/tools/source_inventory.mojo","tagged-source-inventory"],["smidr/tools/typed_decoder.mojo","tagged-typed-decoder"],["smidr/tools/semantic_storage.mojo","tagged-semantic-storage"],["tests/hailo_semantic_storage_api.mojo","tagged-semantic-storage-api"],["smidr/tools/source_float_constants.mojo","tagged-float-constants"],["tests/hailo_source_float_api.mojo","tagged-float-api"],["smidr/tools/source_q4k_constants.mojo","tagged-q4k-constants"],["tests/hailo_source_q4k_api.mojo","tagged-q4k-api"],["smidr/tools/source_q5q6_constants.mojo","tagged-q5q6-constants"],["tests/hailo_source_q5q6_api.mojo","tagged-q5q6-api"]]
out=Path('../semantic-storage-final');out.mkdir(exist_ok=True)
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for root in ('smidr','tests') for p in Path(root).glob('**/*.mojo')}
(out/'source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
def build(pair):
 source,name=pair
 env=os.environ.copy();env['MODULAR_CACHE_DIR']='../mojo-cache'
 with open(out/(name+'-build.txt'),'w') as f:
  r=subprocess.run(['mojo','build','-I','.','-I','aesir_engine',source,'-o',str(out/name)],env=env,stdout=f,stderr=subprocess.STDOUT)
 return {'source':source,'binary':name,'returncode':r.returncode}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 results=list(pool.map(build,pairs))
for item in results:
 p=out/item['binary']
 if p.exists():item['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'build-results.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
