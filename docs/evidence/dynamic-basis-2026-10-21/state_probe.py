"""Isolated public frequency-state decorator; callback reads constants only."""
import hashlib
import inspect
import json
import math
import os
from pathlib import Path
import struct
import sys
from types import SimpleNamespace

os.environ.update(HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1", USE_TORCH="1", USE_TF="0", USE_FLAX="0")
pinned = Path("../ordinary-modifier-study/config-4.57.1-venv/lib/python3.11/site-packages")
licenses = [
    (pinned / "transformers-4.57.1.dist-info/licenses/LICENSE", "77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049"),
    (Path("/home/pi/.local/lib/python3.11/site-packages/torch-2.11.0+cpu.dist-info/licenses/LICENSE"), "a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4"),
]
for path, expected in licenses:
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
sys.path.append("/home/pi/.local/lib/python3.11/site-packages")
import torch
sys.path.remove("/home/pi/.local/lib/python3.11/site-packages")
sys.path.insert(0, str(Path("../ordinary-modifier-study/torch-only-imports").resolve()))

def excluded(*args, **kwargs):
    raise AssertionError("Model/module/attention execution excluded")

hook = torch.nn.modules.module.register_module_forward_pre_hook(excluded)
torch.nn.functional.scaled_dot_product_attention = excluded
from transformers import SmolLM3Config
from transformers.modeling_rope_utils import ROPE_INIT_FUNCTIONS, dynamic_rope_update

word = lambda x: struct.unpack("<I", struct.pack("<f", x))[0]
class ConstantState:
    """Not a torch Module or model; holds only tiny inverse-frequency constants."""
    def __init__(self, config):
        self.config = config
        self.rope_type = "dynamic"
        self.max_seq_len_cached = config.max_position_embeddings
        self.original_max_seq_len = config.max_position_embeddings
        self.rope_init_fn = ROPE_INIT_FUNCTIONS["dynamic"]
        self.inv_freq, self.attention_scaling = self.rope_init_fn(config, torch.device("cpu"))
        self.original_inv_freq = self.inv_freq
        self.callbacks = 0
    def register_buffer(self, name, value, persistent=False):
        assert name == "inv_freq" and not persistent
        self.inv_freq = value

def observe_constants(state, token, positions):
    assert isinstance(token, SimpleNamespace) and token.device == torch.device("cpu")
    state.callbacks += 1
    return [word(x) for x in state.inv_freq.tolist()]

observe = dynamic_rope_update(observe_constants)
rows = []
worst = 0.0
for context in (8, 16):
    lengths = [1, context, context+1, context, context+4, context+2, context, context-1, context+8, context+2, context, context-1]
    selected = [context, context, context+1, context+1, context+4, context+4, context+4, context, context+8, context+8, context+8, context]
    for theta in (10000.0, 2000000.0):
        for factor in (1.0, 2.0):
            for fraction in (0.5, 0.75, 1.0):
                width = int(8*fraction)
                for original in (None, 4):
                    scaling = {"rope_type": "dynamic", "factor": factor}
                    if original is not None:
                        scaling["original_max_position_embeddings"] = original
                    config = SmolLM3Config(hidden_size=32, num_attention_heads=4, num_key_value_heads=2, num_hidden_layers=4, head_dim=8, partial_rotary_factor=fraction, rope_theta=theta, max_position_embeddings=context, rope_scaling=scaling)
                    state = ConstantState(config)
                    initial_words = [word(x) for x in state.inv_freq.tolist()]
                    steps = []
                    for index, (length, expected_context) in enumerate(zip(lengths, selected)):
                        positions = [0, length-1] if index == 8 else [length-1]
                        words = observe(state, SimpleNamespace(device=torch.device("cpu")), torch.tensor([positions], dtype=torch.int64))
                        assert state.max_seq_len_cached == expected_context
                        gain = factor*expected_context/context-(factor-1)
                        candidate = [theta**(-2*j/width)*gain**(-2*j/(width-2)) for j in range(width//2)]
                        actual = state.inv_freq.tolist()
                        relative = [abs(x-y)/abs(y) for x, y in zip(actual, candidate)]
                        assert len(actual) == width//2 and max(relative) < 1e-6
                        assert state.attention_scaling == 1.0
                        if expected_context == context:
                            assert words == initial_words
                        worst = max(worst, *relative)
                        steps.append(dict(positions=positions, expected_context=expected_context, observed_context=int(state.max_seq_len_cached), frequency_f32_words=words, independent_candidate=candidate, relative_errors=relative))
                    assert state.callbacks == 12
                    rows.append(dict(configured_context=context, nested_original_context=original, head_dim=8, rotary_fraction=fraction, rotary_width=width, theta=theta, factor=factor, steps=steps))
assert len(rows) == 48
assert not any(name.startswith("transformers.models.smollm3.modeling_") for name in sys.modules)
hook.remove()
module = Path(inspect.getfile(dynamic_rope_update))
print(json.dumps(dict(scenarios=rows, scenario_count=len(rows), callback_calls=sum(len(row["steps"]) for row in rows), constant_words=sum(len(step["frequency_f32_words"]) for row in rows for step in row["steps"]), worst_relative_error=worst, module_sha256=hashlib.sha256(module.read_bytes()).hexdigest(), external_model_module_imported=False, model_or_layer_or_attention_forward=False, external_rotary_forward=False, cache_update_called=False, source_payload_loaded=False, device_access=False), indent=2, allow_nan=False))
