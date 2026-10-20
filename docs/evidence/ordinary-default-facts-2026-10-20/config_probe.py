"""Test-only public configuration constructors; no tensor/model execution."""
from importlib import metadata
import hashlib,json,sys
from pathlib import Path
from transformers import SmolLM3Config

cases=[('defaults',{}),('explicit_kv',dict(num_hidden_layers=4,num_attention_heads=8,num_key_value_heads=2)),
 ('null_kv',dict(num_hidden_layers=4,num_attention_heads=8,num_key_value_heads=None)),
 ('omitted_kv_with_heads8',dict(num_hidden_layers=4,num_attention_heads=8)),
 ('tie_false',dict(num_hidden_layers=4,tie_word_embeddings=False)),
 ('tie_null',dict(num_hidden_layers=4,tie_word_embeddings=None)),
 ('cache_false',dict(num_hidden_layers=4,use_cache=False,pretraining_tp=2)),
 ('window',dict(num_hidden_layers=4,use_sliding_window=True,sliding_window=128,max_window_layers=2)),
 ('head_extension',dict(num_hidden_layers=4,head_dim=64))]
for heads in (1,2,4,8,16,32):
 cases.append(("omitted_kv_heads_"+str(heads),dict(num_hidden_layers=4,num_attention_heads=heads)))
 cases.append(("null_kv_heads_"+str(heads),dict(num_hidden_layers=4,num_attention_heads=heads,num_key_value_heads=None)))
for layers in (1,2,3,4,7,8):
 cases.append(("layer_count_"+str(layers),dict(num_hidden_layers=layers)))
for mask in ([0,1,0,1],[1,0,1,0],[0,0,0,0],[1,1,1,1]):
 cases.append(("window_mask_"+"".join(map(str,mask)),dict(num_hidden_layers=4,use_sliding_window=True,sliding_window=128,no_rope_layers=mask)))
results=[]
fields=['model_type','vocab_size','hidden_size','intermediate_size','num_hidden_layers','num_attention_heads',
 'num_key_value_heads','head_dim','tie_word_embeddings','use_cache','pretraining_tp','no_rope_layers','no_rope_layer_interval','layer_types','use_sliding_window','sliding_window','max_window_layers','rope_theta','rope_scaling','rope_parameters']
for name,kwargs in cases:
 try:
  config=SmolLM3Config(**kwargs)
  values={key:getattr(config,key) for key in fields if hasattr(config,key)}
  results.append(dict(case=name,input=kwargs,result=values))
 except Exception as error:
  results.append(dict(case=name,input=kwargs,error=type(error).__name__,detail=str(error)))
assert 'torch' not in sys.modules,'metadata-only oracle unexpectedly imported torch'
assert 'transformers.models.smollm3.modeling_smollm3' not in sys.modules
module=sys.modules[SmolLM3Config.__module__]
path=Path(module.__file__)
report=dict(transformers_version=metadata.version('transformers'),configuration_module=SmolLM3Config.__module__,
 module_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),configuration_only=True,torch_imported=False,model_module_imported=False,
 model_instantiated=False,weights_loaded=False,network_or_inference_requested=False,cases=results)
print(json.dumps(report,indent=2))
