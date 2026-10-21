"""Test-only constant primitive oracle; no model/layer/attention forward."""
import os
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["USE_TORCH"] = "1"
os.environ["USE_TF"] = "0"
os.environ["USE_FLAX"] = "0"
import sys
sys.path.append("/home/pi/.local/lib/python3.11/site-packages")
import hashlib, inspect, json
from pathlib import Path
from importlib import metadata
import torch
sys.path.remove("/home/pi/.local/lib/python3.11/site-packages")
sys.path.insert(0, str(Path(__file__).resolve().parent / "torch-only-imports"))
forward_calls = []
def reject_forward(module, arguments):
    forward_calls.append(type(module).__name__)
    raise AssertionError("Module.forward is excluded from this static primitive oracle")
hook = torch.nn.modules.module.register_module_forward_pre_hook(reject_forward)
from transformers.models.smollm3.modeling_smollm3 import SmolLM3Attention, SmolLM3MLP, SmolLM3RMSNorm
from transformers import SmolLM3Config
def reject_direct_forward(self,*args,**kwargs):
    forward_calls.append(type(self).__name__)
    raise AssertionError("Direct layer/attention forward is excluded")
for cls in (SmolLM3Attention,SmolLM3MLP,SmolLM3RMSNorm):
    cls.forward=reject_direct_forward
cases=[]
inputs=[("defaults",{}),("head_dim6",dict(head_dim=6)),("attention_bias",dict(attention_bias=True)),
        ("mlp_bias",dict(mlp_bias=True)),("both_bias",dict(attention_bias=True,mlp_bias=True)),
        ("head_and_bias",dict(head_dim=6,attention_bias=True,mlp_bias=True)),
        ("gelu",dict(hidden_act="gelu")),("cache_false_tp2",dict(use_cache=False,pretraining_tp=2)),
        ("hidden10_heads4",dict(hidden_size=10)),
        ("hidden10_heads3",dict(hidden_size=10,num_attention_heads=3,num_key_value_heads=1)),
        ("small_meta_only",dict(hidden_size=1,num_attention_heads=1,num_key_value_heads=1)),
        ("odd_head_meta_only",dict(head_dim=3))]
for name,updates in inputs:
    base=dict(hidden_size=8,intermediate_size=12,num_attention_heads=4,num_key_value_heads=2,num_hidden_layers=4)
    base.update(updates)
    config=SmolLM3Config(**base)
    try:
        with torch.device("meta"):
            attention=SmolLM3Attention(config,layer_idx=0)
            mlp=SmolLM3MLP(config)
            norm=SmolLM3RMSNorm(config.hidden_size,eps=config.rms_norm_eps)
        modules={"attention":attention,"mlp":mlp,"norm":norm}
        headers={}
        for label,module in modules.items():
            headers[label]={}
            for key,param in module.named_parameters():
                assert param.is_meta, "real parameter storage is excluded"
                headers[label][key]=dict(shape=list(param.shape),device=str(param.device),is_meta=param.is_meta,dtype=str(param.dtype))
            for key,buffer in module.named_buffers():
                assert buffer.is_meta, "real buffer storage is excluded"
        attrs={}
        for key in ("head_dim","num_key_value_groups","scaling","is_causal","layer_idx"):
            if hasattr(attention,key):attrs[key]=getattr(attention,key)
        cases.append(dict(case=name,updates=updates,configuration_dimensions={key:getattr(config,key) for key in ("hidden_size","intermediate_size","num_attention_heads","num_key_value_heads")},norm_constructor_dim=config.hidden_size,parameter_headers=headers,attention_attributes=attrs,
                          activation_class=type(mlp.act_fn).__name__,norm_epsilon=norm.variance_epsilon))
    except Exception as error:
        cases.append(dict(case=name,updates=updates,error=type(error).__name__,detail=str(error)))
assert not forward_calls
identities=[]
for cls in (SmolLM3Attention,SmolLM3MLP,SmolLM3RMSNorm):
    p=Path(inspect.getfile(cls))
    identities.append(dict(module=cls.__module__,name=cls.__name__,signature=str(inspect.signature(cls)),module_sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
hook.remove()
print(json.dumps(dict(transformers_version=metadata.version("transformers"),torch_version=torch.__version__,
                     scope="meta-device constructor metadata only",module_forward_calls=forward_calls,
                     full_model_instantiated=False,source_weights_loaded=False,real_parameter_storage=False,
                     layer_or_attention_forward=False,identities=identities,cases=cases),indent=2))
