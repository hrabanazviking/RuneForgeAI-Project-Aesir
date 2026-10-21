"""Independent public configuration-only probes, no tensor or model imports."""
import hashlib,itertools,json,sys
from pathlib import Path
from importlib.metadata import version
from transformers import SmolLM3Config
cases=[]
for enabled,window,mask,maxlayers in itertools.product((False,True),(None,1,4),([1,1,1,0],[0,1,0,1]),(None,1,4)):
 d=dict(num_hidden_layers=4,use_sliding_window=enabled,sliding_window=window,no_rope_layers=mask)
 if maxlayers is not None:d['max_window_layers']=maxlayers
 cases.append(d)
for enabled,types in itertools.product((False,True),(['full_attention']*4,['sliding_attention']*4,['full_attention','sliding_attention']*2,None,[])):
 cases.append(dict(num_hidden_layers=4,use_sliding_window=enabled,sliding_window=3,layer_types=types))
rows=[]
for i,d in enumerate(cases):
 try:
  c=SmolLM3Config(**d)
  rows.append(dict(case=i,input=d,result={k:getattr(c,k) for k in ('layer_types','no_rope_layers','use_sliding_window','sliding_window','max_window_layers') if hasattr(c,k)}))
 except Exception as e:rows.append(dict(case=i,input=d,error=type(e).__name__,detail=str(e)))
assert 'torch' not in sys.modules and 'transformers.models.smollm3.modeling_smollm3' not in sys.modules
m=Path(sys.modules[SmolLM3Config.__module__].__file__)
assert hashlib.sha256(m.read_bytes()).hexdigest()=='4fec68b228fec767ddc8f8cd4c40f8eaf374c3c44bf38c0cf1618382c7731cdf'
print(json.dumps(dict(version=version('transformers'),module_sha256=hashlib.sha256(m.read_bytes()).hexdigest(),configuration_only=True,model_execution=False,cases=rows),indent=2))
