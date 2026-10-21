"""Test-only inverse-frequency constants, never a model/layer/attention forward."""
import os,sys,hashlib,json,inspect,math,struct
from pathlib import Path
os.environ.update(HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',USE_TORCH='1',USE_TF='0',USE_FLAX='0')
pinned=Path('../ordinary-modifier-study/config-4.57.1-venv/lib/python3.11/site-packages')
licenses=[(pinned/'transformers-4.57.1.dist-info/licenses/LICENSE','77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049'),(Path('/home/pi/.local/lib/python3.11/site-packages/torch-2.11.0+cpu.dist-info/licenses/LICENSE'),'a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4')]
for p,h in licenses:assert hashlib.sha256(p.read_bytes()).hexdigest()==h
sys.path.append('/home/pi/.local/lib/python3.11/site-packages')
import torch
sys.path.remove('/home/pi/.local/lib/python3.11/site-packages');sys.path.insert(0,str(Path('../ordinary-modifier-study/torch-only-imports').resolve()))
def excluded(*a,**k):raise AssertionError('Model/module/attention forwards excluded')
hook=torch.nn.modules.module.register_module_forward_pre_hook(excluded);torch.nn.functional.scaled_dot_product_attention=excluded
from transformers import SmolLM3Config
from transformers.modeling_rope_utils import ROPE_INIT_FUNCTIONS
f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
word=lambda x:struct.unpack('<I',struct.pack('<f',x))[0]
rows=[];worst=0.0
for width in (2,4,6,8):
 for theta in (10000.0,2000000.0,5000000.0):
  for factor in (1.0,1.5,2.0,8.0):
   config=SmolLM3Config(hidden_size=width*4,num_attention_heads=4,num_key_value_heads=2,num_hidden_layers=4,rope_theta=theta,rope_scaling={'rope_type':'linear','factor':factor})
   base,a=ROPE_INIT_FUNCTIONS['default'](config,torch.device('cpu'))
   scaled,b=ROPE_INIT_FUNCTIONS['linear'](config,torch.device('cpu'))
   before=base.tolist();after=scaled.tolist();assert a==1.0 and b==1.0
   assert [word(x) for x in after]==[word(f32(x/factor)) for x in before]
   reference=[theta**(-2*j/width)/factor for j in range(width//2)]
   relative=[abs(x-y)/abs(y) for x,y in zip(after,reference)];worst=max(worst,*relative)
   rows.append(dict(width=width,theta=theta,factor=factor,default_f32_words=[word(x) for x in before],linear_f32_words=[word(x) for x in after],reference_real_values=reference,relative_errors=relative,attention_factor=b))
assert 'transformers.models.smollm3.modeling_smollm3' not in sys.modules
hook.remove();identities=[]
for name in ('default','linear'):
 fn=ROPE_INIT_FUNCTIONS[name];p=Path(inspect.getfile(fn));identities.append(dict(name=name,signature=str(inspect.signature(fn)),module_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
print(json.dumps(dict(cases=rows,case_count=len(rows),linear_constant_words=sum(len(r['linear_f32_words']) for r in rows),worst_relative_error_against_real_formula=worst,model_or_attention_forward=False,weights_loaded=False,model_module_imported=False,device_access=False,external_runtime_dependency=False,identities=identities),indent=2))
