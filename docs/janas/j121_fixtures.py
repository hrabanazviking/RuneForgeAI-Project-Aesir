#!/usr/bin/env python3
"""J-121 fixtures: a synthetic MTP-carrying HF checkpoint on disk.

Pure stdlib. Writes, into the directory named by
argv[1]:
  model.safetensors           checkpoint (F32)

The model is J-120's 1-layer llama-shaped toy
(vocab 8, hidden 8, heads 2, KV heads 1, ffn 16 --
the geometry the J-121 protocol, doc section 0.7,
pre-registered) PLUS four prediction-head tensors
exercising all three J-076 classes:

  model.nextn.eh_proj.weight             [8, 16]  NEXTN, 2-D
  model.nextn.shared_head_norm.weight    [8]      NEXTN, 1-D
  model.mtp.fc.weight                    [8, 8]   MTP, 2-D
  model.assistant.head_norm.weight       [8]      ASSISTANT, 1-D

16 source tensors in all; per-kind source census
nextn 2 / mtp 1 / assistant 1, verdict WITH_MTP.
The head names are synthetic, in J-076's
pre-registered forms (J-077's SIMULATED sense): no
real MTP-carrying checkpoint exists in any filed
census. All values are dyadic rationals with small
denominators, so Float32 arithmetic on them is
exact and their BF16 roundings are unambiguous:
the census-agreement verification (j121_verify.py)
can demand exact agreement, element for element.
No adapter is written: the adapter x MTP
combination is outside J-121's proven scope
(protocol section 0.2).
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
        # The prediction-head block (J-121 protocol section 0.7).
        ("model.nextn.eh_proj.weight", [8, 16], vals(128, 3, 9, -4, 8.0)),
        ("model.nextn.shared_head_norm.weight", [8], vals(8, 5, 9, -4, 8.0)),
        ("model.mtp.fc.weight", [8, 8], vals(64, 7, 9, -4, 8.0)),
        ("model.assistant.head_norm.weight", [8], vals(8, 3, 9, -4, 8.0)),
    ]
    write_safetensors(outdir + "/model.safetensors", base)
    print("fixtures written: %s (16 tensors, 4 head)" % outdir)


if __name__ == "__main__":
    main()
