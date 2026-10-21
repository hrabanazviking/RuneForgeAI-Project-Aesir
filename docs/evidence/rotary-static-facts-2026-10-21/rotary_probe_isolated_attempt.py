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
from transformers.models.smollm3.modeling_smollm3 import rotate_half, apply_rotary_pos_emb
from transformers import SmolLM3Config
from transformers.modeling_rope_utils import ROPE_INIT_FUNCTIONS
cases = []
for width in (2, 4, 6, 8, 16):
    x = torch.arange(1, width + 1, dtype=torch.float32).reshape(1, 1, 1, width)
    rotation = rotate_half(x)
    cosine = torch.zeros((1, 1, width), dtype=torch.float32)
    sine = torch.ones_like(cosine)
    q, k = apply_rotary_pos_emb(x, x * 2, cosine, sine)
    cases.append(dict(width=width, input=x.flatten().tolist(), rotated=rotation.flatten().tolist(),
                      query=q.flatten().tolist(), key=k.flatten().tolist()))
frequency_cases = []
for width in (2, 4, 6, 8, 16, 128):
    for theta in (10000.0, 2000000.0, 5000000.0):
        config = SmolLM3Config(hidden_size=width * 4, num_attention_heads=4,
                              num_key_value_heads=2, rope_theta=theta)
        frequency, scale = ROPE_INIT_FUNCTIONS["default"](config, torch.device("cpu"))
        frequency_cases.append(dict(width=width, theta=theta, inverse_frequencies=frequency.tolist(),
                                    attention_factor=scale))
assert not forward_calls
functions = [rotate_half, apply_rotary_pos_emb, ROPE_INIT_FUNCTIONS["default"]]
identities = []
for function in functions:
    path = Path(inspect.getfile(function))
    identities.append(dict(module=function.__module__, name=function.__name__,
                           signature=str(inspect.signature(function)),
                           module_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
hook.remove()
print(json.dumps(dict(transformers_version=metadata.version("transformers"),
                      torch_version=torch.__version__, identities=identities,
                      static_primitive_only=True, module_forward_calls=forward_calls,
                      model_instantiated=False, weights_loaded=False,
                      model_layer_attention_forward=False, cases=cases,
                      frequencies=frequency_cases), indent=2))
