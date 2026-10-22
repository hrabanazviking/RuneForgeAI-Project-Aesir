from pathlib import Path
import json,sys
build=Path('../q2q3-native-final');out=Path('../q2q3-native-acceptance')
jobs=json.loads((build/'closure-jobs.json').read_text());by_source={s:str((build/n).resolve()) for s,n in jobs['current']}
commands=[]
# Derive prior passing commands and map only their documented rebuilt consumers.
for file in ('../decoder-scaling-regression-accepted/test-results.json','../decoder-scaling-extra-accepted/test-results.json','../decoder-scaling-other-accepted/test-results.json','../decoder-scaling-accepted/test-results.json'):
 for row in json.loads(Path(file).read_text()):
  cmd=[str(build/Path(arg).name) if 'decoder-scaling-final' in arg and Path(arg).name!='decoder-scaling-final' else str(build) if Path(arg).name=='decoder-scaling-final' else arg for arg in row['command']]
  if '--evidence' in cmd:cmd[cmd.index('--evidence')+1]=str(out/'legacy'/row['suite'])
  commands.append((row['suite'],cmd,True))
assert len(commands)==24
for name in ('q8','classic32','q2q3'):
 src='tests/test_hailo_source_'+name+'_constants.py'
 cmd=[sys.executable,src,'--binary',by_source['smidr/tools/source_'+name+'_constants.mojo'],'--api',by_source['tests/hailo_source_'+name+'_api.mojo']]
 for flag,path in [('tile','smidr/tools/source_weight_tiles.mojo'),('tile-api','tests/hailo_source_weight_tiles_api.mojo'),('inventory','smidr/tools/source_inventory.mojo'),('semantic','smidr/tools/semantic_plan.mojo')]:cmd+=['--'+flag,by_source[path]]
 cmd+=['--reference-library','../ggml-format-study/build/src/libggml-base.so.0.27.0','--strace','/usr/bin/strace','--evidence',str(out/name)]
 commands.append((name,cmd,name!='q2q3'))
commands += [('context',[sys.executable,'tests/test_hailo_dynamic_rotary_context.py','--binary',by_source['tests/hailo_dynamic_rotary_context.mojo'],'--result',str(out/'context-report.json')],True),('history',[sys.executable,'tests/test_hailo_dynamic_decoder_history.py','--history',by_source['tests/hailo_dynamic_decoder_history.mojo'],'--source',by_source['tests/hailo_dynamic_decoder_source.mojo'],'--frozen','../decoder-dynamic-baseline/scaling-graph','--evidence',str(out/'history')],True),('graph',[sys.executable,'tests/test_hailo_dynamic_decoder_graph.py','--binary',by_source['smidr/tools/dynamic_decoder_graph.mojo'],'--api',by_source['tests/hailo_dynamic_decoder_graph.mojo'],'--gguf',by_source['tests/hailo_dynamic_graph_gguf.mojo'],'--frozen','../decoder-dynamic-baseline/scaling-graph','--mutations','../dynamic-graph-development/mutations.json','--strace','/usr/bin/strace','--evidence',str(out/'graph')],True)]
for name,tool,api,oracle in [('context-actions','smidr/tools/context_actions.mojo','tests/hailo_context_action_ownership.mojo','old-oracle'),('lcu-actions','smidr/tools/lcu_actions.mojo','tests/hailo_lcu_action_ownership.mojo','oracle')]:commands.append((name,[sys.executable,'tests/test_hailo_'+name.replace('-','_')+'.py','--binary',by_source[tool],'--ownership',by_source[api],'--oracle','../lcu-action-final/'+oracle,'--strace','/usr/bin/strace','--evidence',str(out/name)],True))
def add(name,opts):
 cmd=[sys.executable,'tests/test_hailo_'+name+'.py']
 for k,v in opts.items():cmd+=['--'+k,by_source.get(v,v)]
 cmd+=['--strace','/usr/bin/strace','--evidence',str(out/name)]
 commands.append((name,cmd,True))
add('source_storage',{'binary':'smidr/tools/source_storage.mojo','api':'tests/hailo_source_storage_api.mojo','gguf-inventory':'smidr/tools/source_inventory.mojo','safe-inventory':'smidr/tools/safetensors_inventory.mojo'})
for n in ('gguf_shapes','safetensors_constants'):
 add(n,{'binary':'smidr/tools/'+n+'.mojo','api':'tests/hailo_'+('gguf_shapes' if n=='gguf_shapes' else 'safetensors_constants')+'_api.mojo'})
for n in ('decoder_architecture','decoder_layers','source_config'):
 add(n,{'binary':'smidr/tools/'+n+'.mojo','api':'tests/hailo_'+n+'_api.mojo','public-config':'../ordinary-model-metadata-study/config.json'})
add('source_index',{'binary':'smidr/tools/source_index.mojo','api':'tests/hailo_source_index_api.mojo','faults':'../source-index-study/io-faults.so','public-index':'../ordinary-model-metadata-study/model.safetensors.index.json'})
# API has no packed-source dependency; retain existing explicitly hashed probe.
add('source_root',{'binary':'smidr/tools/source_root.mojo','api':'../source-root-api','faults':'../model-root-study/io-faults.so','layout':'../q2q3-native-development/root-layout.json'})
add('shard_collection',{'binary':'smidr/tools/shard_collection.mojo','api':'tests/hailo_shard_collection_api.mojo','storage':'smidr/tools/source_storage.mojo','faults':'../owned-fd-study/io-faults.so'})
add('unindexed_source',{'binary':'smidr/tools/unindexed_source.mojo','api':'tests/hailo_unindexed_source_api.mojo','indexed':'smidr/tools/shard_collection.mojo','baseline':'../unindexed-baseline-collection','faults':'../owned-fd-study/io-faults.so'})
assert len(commands)==42,len(commands)
Path('../q2q3-native-development/commands.json').write_text(json.dumps(commands,indent=2)+'\n')
for _,cmd,_ in commands:
 for flag in ('--public-config','--public-index','--layout','--faults','--baseline','--frozen','--mutations','--oracle','--reference-library'):
  if flag in cmd:assert Path(cmd[cmd.index(flag)+1]).exists(),(flag,cmd)
print('42 explicit metadata/compiler/control suites planned')
