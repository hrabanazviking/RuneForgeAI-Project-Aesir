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
 for theta in (10000.0,2000000.0):
  for factor in (1.0,2.0):
   for original in (None,8):
    scale={'rope_type':'dynamic','factor':factor}
    if original is not None:scale['original_max_position_embeddings']=original
    config=SmolLM3Config(hidden_size=width*4,num_attention_heads=4,num_key_value_heads=2,num_hidden_layers=4,rope_theta=theta,max_position_embeddings=16,rope_scaling=scale)
    for length in (None,0,15,16,17,32):
     row=dict(width=width,theta=theta,factor=factor,configured_context=16,original_field=original,length=length)
     try:
      frequencies,attention=ROPE_INIT_FUNCTIONS['dynamic'](config,torch.device('cpu'),seq_len=length)
     except Exception as exc:
      row.update(error=type(exc).__name__,detail=str(exc),error_stage='public_initializer')
     else:
      values=frequencies.tolist()
      row.update(frequency_f32_words=[word(x) for x in values],attention_factor=attention)
      assert width>2, 'Independent candidate has not been qualified at width2'
      effective=max(16,16 if length is None else length)
      gain=factor*effective/16-(factor-1)
      candidate=[theta**(-2*j/width)*gain**(-2*j/(width-2)) for j in range(width//2)]
      relative=[abs(x-y)/abs(y) for x,y in zip(values,candidate)]
      row.update(independent_real_candidate=candidate,relative_errors=relative,candidate_validated=True)
      worst=max(worst,*relative)
      assert attention==1.0 and max(relative)<1e-6
     rows.append(row)
assert 'transformers.models.smollm3.modeling_smollm3' not in sys.modules
hook.remove();identities=[]
for name in ('dynamic',):
 fn=ROPE_INIT_FUNCTIONS[name];p=Path(inspect.getfile(fn));identities.append(dict(name=name,signature=str(inspect.signature(fn)),module_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
assert len(rows)==192
assert all('error' in r for r in rows if r['width']==2)
assert all('error' not in r for r in rows if r['width']>2)
print(json.dumps(dict(cases=rows,case_count=len(rows),accepted=sum('error' not in r for r in rows),refused=sum('error' in r for r in rows),constant_words=sum(len(r.get('frequency_f32_words',[])) for r in rows),worst_relative_error_against_independent_candidate=worst,model_or_attention_forward=False,weights_loaded=False,model_module_imported=False,device_access=False,external_runtime_dependency=False,identities=identities),indent=2,allow_nan=False))
