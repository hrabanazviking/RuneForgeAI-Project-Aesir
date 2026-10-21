"""Public isolated boolean-index oracle. No tensors, attention or model forward."""
import os,sys,hashlib,inspect,json
from pathlib import Path
os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',USE_TORCH='1',USE_TF='0',USE_FLAX='0')
torch_license=Path('/home/pi/.local/lib/python3.11/site-packages/torch-2.11.0+cpu.dist-info/licenses/LICENSE')
assert hashlib.sha256(torch_license.read_bytes()).hexdigest()=='a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4'
sys.path.append('/home/pi/.local/lib/python3.11/site-packages')
import torch
sys.path.remove('/home/pi/.local/lib/python3.11/site-packages')
sys.path.insert(0,str(Path('../ordinary-modifier-study/torch-only-imports').resolve()))
def excluded(*args,**kwargs):raise AssertionError('No module or attention forward permitted')
hook=torch.nn.modules.module.register_module_forward_pre_hook(excluded)
torch.nn.functional.scaled_dot_product_attention=excluded
from transformers.masking_utils import causal_mask_function,sliding_window_overlay
identities=[]
for fn in (causal_mask_function,sliding_window_overlay):
 p=Path(inspect.getfile(fn));identities.append(dict(name=fn.__name__,signature=str(inspect.signature(fn)),doc=inspect.getdoc(fn),module_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
rows=[]
for window in (1,2,3,4,8,64,9223372036854775807):
 f=sliding_window_overlay(window)
 for q in range(17):
  admitted=[]
  for k in range(20):
   a=bool(causal_mask_function(0,0,q,k));b=bool(f(0,0,q,k))
   assert a==(k<=q) and b==(k>q-window)
   if a and b:admitted.append(k)
  assert admitted==list(range(max(0,q-window+1),q+1))
  rows.append(dict(window=window,query=q,admitted=admitted))
assert not any(k.startswith('transformers.models.smollm3.modeling') for k in sys.modules)
hook.remove()
print(json.dumps(dict(primitive='isolated causal/window boolean index predicates',predicate_checks=7*17*20*2,rows=rows,identities=identities,no_tensors_created=True,model_or_attention_forward=False,device_access=False),indent=2))
