"""Public pinned configuration metadata only. No tensor/model/layer imports."""
import copy,hashlib,json,sys
from pathlib import Path
from importlib.metadata import version
lic=Path('../ordinary-modifier-study/config-4.57.1-venv/lib/python3.11/site-packages/transformers-4.57.1.dist-info/licenses/LICENSE')
assert hashlib.sha256(lic.read_bytes()).hexdigest()=='77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049'
from transformers import SmolLM3Config
cases=[None,{'rope_type':'default'},{'type':'linear','factor':2.0},{'rope_type':'linear','factor':2.0},{'type':'linear','rope_type':'dynamic','factor':2.0},{'rope_type':'linear','factor':2},{'rope_type':'linear','factor':0.5},{'rope_type':'linear','factor':0.0},{'rope_type':'linear','factor':-1.0},{'rope_type':'linear','factor':'2'},{'rope_type':'future','factor':2.0},{'rope_type':'dynamic','factor':2.0},{'rope_type':'yarn','factor':2.0},{'rope_type':'longrope','factor':2.0,'original_max_position_embeddings':32,'short_factor':[1.0,1.0],'long_factor':[2.0,2.0]},{'rope_type':'llama3','factor':8.0,'original_max_position_embeddings':32,'low_freq_factor':1.0,'high_freq_factor':4.0},{'rope_type':'linear','factor':2.0,'custom':{'retained':'æ'}}]
rows=[]
for i,scale in enumerate(cases):
 for tp in (1,2,None):
  original=dict(num_hidden_layers=4,hidden_size=16,num_attention_heads=4,num_key_value_heads=2,max_position_embeddings=64,rope_scaling=scale,pretraining_tp=tp)
  d=copy.deepcopy(original)
  try:
   c=SmolLM3Config(**d)
   rows.append(dict(case=i,input=original,caller_after=d,result={key:getattr(c,key) for key in ('rope_scaling','rope_theta','pretraining_tp','max_position_embeddings') if hasattr(c,key)}))
  except Exception as e:rows.append(dict(case=i,input=original,caller_after=d,error=type(e).__name__,detail=str(e)))
assert 'torch' not in sys.modules and 'transformers.models.smollm3.modeling_smollm3' not in sys.modules
p=Path(sys.modules[SmolLM3Config.__module__].__file__);assert hashlib.sha256(p.read_bytes()).hexdigest()=='4fec68b228fec767ddc8f8cd4c40f8eaf374c3c44bf38c0cf1618382c7731cdf'
print(json.dumps(dict(version=version('transformers'),configuration_only=True,model_execution=False,torch_imported=False,model_module_imported=False,license_sha256=hashlib.sha256(lic.read_bytes()).hexdigest(),module_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),cases=rows),indent=2))
