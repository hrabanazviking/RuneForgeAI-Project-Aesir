#!/usr/bin/env python3
"""J-120 fixtures: a synthetic HF checkpoint on disk.

Pure stdlib. Writes, into the directory named by
argv[1]:
  model.safetensors           base checkpoint (F32)
  adapter_model.safetensors   PEFT LoRA adapter (F32)
  adapter_config.json         {"r": 2, "lora_alpha": 4, ...}

The model is a 1-layer llama-shaped toy: vocab 8,
hidden 8, heads 2, KV heads 1, ffn 16 -- the
geometry the J-120 protocol (doc section 0.7)
pre-registered and the convert driver carries. Two tensors are adapter-targeted
(self_attn.q_proj, mlp.gate_proj); the rest pass
through. All values are dyadic rationals with small
denominators, so Float32 arithmetic on them is
exact and their merged results are exact in BF16:
the slow-way verification (j120_verify.py) can
demand exact agreement, element for element.
"""
import json
import struct
import sys


def vals(count, mul, mod, off, denom):
    return [(((i * mul) % mod) + off) / denom for i in range(count)]


def write_safetensors(path, tensors):
    """tensors: list of (name, shape, values)."""
    header = {}
    offset = 0
    blobs = []
    for name, shape, values in tensors:
        data = struct.pack("<%df" % len(values), *values)
        header[name] = {
            "dtype": "F32",
            "shape": list(shape),
            "data_offsets": [offset, offset + len(data)],
        }
        blobs.append(data)
        offset += len(data)
    hj = json.dumps(header, separators=(",", ":")).encode("utf-8")
    with open(path, "wb") as f:
        f.write(struct.pack("<Q", len(hj)))
        f.write(hj)
        for b in blobs:
            f.write(b)


def main():
    outdir = sys.argv[1]
    base = [
        ("model.embed_tokens.weight", [8, 8], vals(64, 3, 9, -4, 8.0)),
        ("model.norm.weight", [8], vals(8, 3, 9, -4, 8.0)),
        ("lm_head.weight", [8, 8], vals(64, 5, 9, -4, 8.0)),
        ("model.layers.0.input_layernorm.weight", [8], vals(8, 5, 9, -4, 8.0)),
        ("model.layers.0.self_attn.q_proj.weight", [8, 8], vals(64, 3, 9, -4, 8.0)),
        ("model.layers.0.self_attn.k_proj.weight", [4, 8], vals(32, 3, 9, -4, 8.0)),
        ("model.layers.0.self_attn.v_proj.weight", [4, 8], vals(32, 5, 9, -4, 8.0)),
        ("model.layers.0.self_attn.o_proj.weight", [8, 8], vals(64, 7, 9, -4, 8.0)),
        ("model.layers.0.post_attention_layernorm.weight", [8], vals(8, 7, 9, -4, 8.0)),
        ("model.layers.0.mlp.gate_proj.weight", [16, 8], vals(128, 3, 9, -4, 8.0)),
        ("model.layers.0.mlp.up_proj.weight", [16, 8], vals(128, 5, 9, -4, 8.0)),
        ("model.layers.0.mlp.down_proj.weight", [8, 16], vals(128, 7, 9, -4, 8.0)),
    ]
    adapter = [
        ("base_model.model.model.layers.0.self_attn.q_proj.lora_A.default.weight",
         [2, 8], vals(16, 5, 5, -2, 4.0)),
        ("base_model.model.model.layers.0.self_attn.q_proj.lora_B.default.weight",
         [8, 2], vals(16, 7, 5, -2, 4.0)),
        ("base_model.model.model.layers.0.mlp.gate_proj.lora_A.default.weight",
         [2, 8], vals(16, 3, 5, -2, 4.0)),
        ("base_model.model.model.layers.0.mlp.gate_proj.lora_B.default.weight",
         [16, 2], vals(32, 5, 5, -2, 4.0)),
    ]
    write_safetensors(outdir + "/model.safetensors", base)
    write_safetensors(outdir + "/adapter_model.safetensors", adapter)
    cfg = {
        "r": 2,
        "lora_alpha": 4,
        "target_modules": ["q_proj", "gate_proj"],
        "task_type": "CAUSAL_LM",
        "bias": "none",
    }
    with open(outdir + "/adapter_config.json", "w") as f:
        f.write(json.dumps(cfg))
    print("fixtures written:", outdir)


if __name__ == "__main__":
    main()
