"""Isolated activation primitive and selector metadata oracle; no model forward."""
import os
os.environ.update(HF_HUB_OFFLINE="1",TRANSFORMERS_OFFLINE="1",USE_TORCH="1",USE_TF="0",USE_FLAX="0")
import sys,hashlib,json,inspect,math
from pathlib import Path
from importlib import metadata
licenses=[]
for name,location,expected in [
    ("transformers",Path(__file__).resolve().parent/"config-4.57.1-venv/lib/python3.11/site-packages/transformers-4.57.1.dist-info/licenses/LICENSE","77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049"),
    ("torch",Path("/home/pi/.local/lib/python3.11/site-packages/torch-2.11.0+cpu.dist-info/licenses/LICENSE"),"a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4")]:
    raw=location.read_bytes();actual=hashlib.sha256(raw).hexdigest();assert actual==expected
    licenses.append(dict(package=name,path=str(location),bytes=len(raw),sha256=actual))
sys.path.append("/home/pi/.local/lib/python3.11/site-packages")
import torch
sys.path.remove("/home/pi/.local/lib/python3.11/site-packages")
sys.path.insert(0,str(Path(__file__).resolve().parent/"torch-only-imports"))
from transformers.activations import get_activation
forward_calls=[]
def reject_forward(module,args):
    forward_calls.append(type(module).__name__)
    raise AssertionError("Module.forward is excluded; functional activation primitives only")
hook=torch.nn.modules.module.register_module_forward_pre_hook(reject_forward)
selectors=[]
for name in ("silu","gelu","gelu_new","gelu_fast","quick_gelu","relu","relu2","unknown_activation"):
    try:
        activation=get_activation(name)
        original=activation.forward
        def reject_direct(*args,**kwargs):
            raise AssertionError("Direct module activation forward excluded from metadata probe")
        activation.forward=reject_direct
        metadata_only={key:str(value) for key,value in activation.__dict__.items() if key in ("act","approximate","inplace")}
        path=Path(inspect.getfile(type(activation)))
        selectors.append(dict(selector=name,class_name=type(activation).__name__,constructor_signature=str(inspect.signature(type(activation))),act_is_functional_gelu=getattr(activation,"act",None) is torch.nn.functional.gelu,metadata=metadata_only,module_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    except KeyError as error:
        selectors.append(dict(selector=name,error=type(error).__name__))
values=[-20.0,-8.0,-4.0,-3.0,-2.0,-1.0,-0.5,-0.0,0.0,0.125,0.5,1.0,2.0,3.0,4.0,8.0,20.0]
records=[]
torch.set_num_threads(1)
with torch.no_grad():
    for dtype in (torch.float32,torch.float64):
        x=torch.tensor(values,dtype=dtype)
        for name,call in (("silu",torch.nn.functional.silu),("gelu_none",lambda x:torch.nn.functional.gelu(x,approximate="none")),("gelu_tanh",lambda x:torch.nn.functional.gelu(x,approximate="tanh")),("relu",torch.nn.functional.relu)):
            output=call(x).tolist()
            if name=="silu":expected=[v/(1+math.exp(-v)) for v in values]
            elif name=="gelu_none":expected=[0.5*v*(1+math.erf(v/math.sqrt(2))) for v in values]
            elif name=="gelu_tanh":expected=[0.5*v*(1+math.tanh(math.sqrt(2/math.pi)*(v+0.044715*v**3))) for v in values]
            else:expected=[max(0.0,v) for v in values]
            errors=[abs(a-b) for a,b in zip(output,expected)]
            tolerance=2e-6 if dtype==torch.float32 else 2e-14
            assert max(errors)<tolerance,(name,dtype,max(errors))
            records.append(dict(primitive=name,dtype=str(dtype),input=values,output=output,real_identity_oracle=expected,max_absolute_error=max(errors),tolerance=tolerance))
assert not forward_calls
assert metadata.version("transformers")=="4.57.1" and torch.__version__=="2.11.0+cpu"
assert next(x for x in selectors if x["selector"]=="gelu")["act_is_functional_gelu"]
separation=[]
for dtype in ("torch.float32","torch.float64"):
    a=next(x for x in records if x["dtype"]==dtype and x["primitive"]=="gelu_none")["output"]
    b=next(x for x in records if x["dtype"]==dtype and x["primitive"]=="gelu_tanh")["output"]
    difference=max(abs(x-y) for x,y in zip(a,b));assert difference>0.0004
    separation.append(dict(dtype=dtype,max_absolute_difference=difference))
hook.remove()
print(json.dumps(dict(transformers_version=metadata.version("transformers"),torch_version=torch.__version__,scope="selector metadata plus isolated functional activation primitives only",model_instantiated=False,model_layer_or_attention_forward=False,module_forward_calls=forward_calls,source_weights_loaded=False,licenses=licenses,selectors=selectors,primitive_vectors=records,gelu_none_tanh_separation=separation,finite_real_scope_only=True,signed_zero_nan_infinity_device_semantics_verified=False),indent=2))
