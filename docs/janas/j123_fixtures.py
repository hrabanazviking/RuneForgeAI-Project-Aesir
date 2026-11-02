#!/usr/bin/env python3
"""J-123 fixtures: synthetic qwen3next GGUFs, pure stdlib.

Geometry (doc section 0.5, scaled, stated): 4 blocks, interval 4
(blocks 0-2 Gated-DeltaNet SSM, block 3 gated attention), hidden 16,
Q heads 2, KV heads 1, head dim 8, experts 4, top-2, expert width 8,
shared width 8, SSM inner 16, groups 2, state 8, dt-rank 2, conv
kernel 4, vocab 16, context 128.

Variants (argv[2]): main (separate-gate attention, 73 tensors),
fused (fused-gate attention, 72), miss_ssm_out (main minus
blk.1.ssm_out.weight), miss_shexp (main minus
blk.2.ffn_gate_shexp.weight), impostor (arch qwen3next but every
block dense-shaped: attn_q/k/v/output + dense ffn, no SSM, no MoE).
Storage: 2-D/3-D BF16, 1-D and router F32, alignment 32, values
deterministic dyadic rationals. No inference is run on any fixture.
Usage: j123_fixtures.py <out.gguf> [variant]
"""
import struct, sys

def bf16(x):
    bits = struct.unpack("<I", struct.pack("<f", x))[0]
    # round to nearest even on the dropped 16 bits
    lsb = (bits >> 16) & 1
    if (bits & 0xFFFF) > 0x8000 or ((bits & 0xFFFF) == 0x8000 and lsb):
        bits += 0x10000
    return (bits >> 16) & 0xFFFF

def vals(n, seed):
    return [(((i * (seed + 3)) % 9) - 4) / 8.0 for i in range(n)]

H, QW, KVW, HD = 16, 16, 8, 8
EXP, FFN, SH = 4, 8, 8
INNER, STATE, DTR = 16, 8, 2

def block_tensors(i, kind, variant):
    p = f"blk.{i}."
    t = [(p + "attn_norm.weight", [H], 0), (p + "post_attention_norm.weight", [H], 0),
         (p + "ffn_gate_inp.weight", [H, EXP], 0),
         (p + "ffn_gate_exps.weight", [H, FFN, EXP], 30),
         (p + "ffn_up_exps.weight", [H, FFN, EXP], 30),
         (p + "ffn_down_exps.weight", [FFN, H, EXP], 30),
         (p + "ffn_gate_shexp.weight", [H, SH], 30),
         (p + "ffn_up_shexp.weight", [H, SH], 30),
         (p + "ffn_down_shexp.weight", [SH, H], 30)]
    if kind == "ssm":
        t += [(p + "attn_qkv.weight", [H, 3 * INNER], 30),
              (p + "attn_gate.weight", [H, INNER], 30),
              (p + "ssm_alpha.weight", [H, DTR], 30),
              (p + "ssm_beta.weight", [H, DTR], 30),
              (p + "ssm_a", [DTR], 0),
              (p + "ssm_conv1d.weight", [3 * INNER, 4], 0),
              (p + "ssm_dt.bias", [DTR], 0),
              (p + "ssm_norm.weight", [STATE], 0),
              (p + "ssm_out.weight", [INNER, H], 30)]
    else:
        if variant == "fused":
            t += [(p + "attn_q.weight", [H, 2 * QW], 30)]
        else:
            t += [(p + "attn_q.weight", [H, QW], 30),
                  (p + "attn_gate.weight", [H, QW], 30)]
        t += [(p + "attn_k.weight", [H, KVW], 30),
              (p + "attn_v.weight", [H, KVW], 30),
              (p + "attn_output.weight", [QW, H], 30),
              (p + "attn_q_norm.weight", [HD], 0),
              (p + "attn_k_norm.weight", [HD], 0)]
    return t

def dense_block(i):
    p = f"blk.{i}."
    return [(p + "attn_norm.weight", [H], 0), (p + "attn_q.weight", [H, QW], 30),
            (p + "attn_k.weight", [H, KVW], 30), (p + "attn_v.weight", [H, KVW], 30),
            (p + "attn_output.weight", [QW, H], 30), (p + "ffn_norm.weight", [H], 0),
            (p + "ffn_gate.weight", [H, FFN], 30), (p + "ffn_up.weight", [H, FFN], 30),
            (p + "ffn_down.weight", [FFN, H], 30)]

def build(variant):
    tensors = [("token_embd.weight", [H, 16], 30), ("output_norm.weight", [H], 0),
               ("output.weight", [H, 16], 30)]
    if variant == "impostor":
        for i in range(4): tensors += dense_block(i)
    else:
        for i in range(4):
            tensors += block_tensors(i, "ssm" if i < 3 else "attn", variant)
        if variant == "miss_ssm_out":
            tensors = [t for t in tensors if t[0] != "blk.1.ssm_out.weight"]
        if variant == "miss_shexp":
            tensors = [t for t in tensors if t[0] != "blk.2.ffn_gate_shexp.weight"]
    tokens = ["<unk>", "<bos>", "<eos>"] + [f"t{i}" for i in range(13)]
    meta = [("general.architecture", 8, "qwen3next"), ("general.name", 8, "j123-synthetic"),
            ("general.alignment", 4, 32),
            ("qwen3next.context_length", 4, 128), ("qwen3next.embedding_length", 4, H),
            ("qwen3next.feed_forward_length", 4, FFN), ("qwen3next.block_count", 4, 4),
            ("qwen3next.attention.head_count", 4, 2), ("qwen3next.attention.head_count_kv", 4, 1),
            ("qwen3next.attention.key_length", 4, HD),
            ("qwen3next.rope.dimension_count", 4, 2), ("qwen3next.rope.freq_base", 6, 10000.0),
            ("qwen3next.attention.layer_norm_rms_epsilon", 6, 1e-5),
            ("qwen3next.expert_count", 4, EXP), ("qwen3next.expert_used_count", 4, 2),
            ("qwen3next.expert_shared_feed_forward_length", 4, SH),
            ("qwen3next.full_attention_interval", 4, 4),
            ("qwen3next.ssm.conv_kernel", 4, 4), ("qwen3next.ssm.state_size", 4, STATE),
            ("qwen3next.ssm.group_count", 4, 2), ("qwen3next.ssm.time_step_rank", 4, DTR),
            ("qwen3next.ssm.inner_size", 4, INNER),
            ("tokenizer.ggml.model", 8, "llama"), ("tokenizer.ggml.tokens", 9, tokens),
            ("tokenizer.ggml.scores", 9, [0.0] * 16), ("tokenizer.ggml.token_type", 9, [0] * 16),
            ("tokenizer.ggml.unknown_token_id", 4, 0), ("tokenizer.ggml.bos_token_id", 4, 1),
            ("tokenizer.ggml.eos_token_id", 4, 2)]
    return meta, tensors

def s(x):
    b = x.encode(); return struct.pack("<Q", len(b)) + b

def write(path, variant):
    meta, tensors = build(variant)
    out = bytearray()
    out += b"GGUF" + struct.pack("<IQQ", 3, len(tensors), len(meta))
    for k, t, v in meta:
        out += s(k) + struct.pack("<I", t)
        if t == 8: out += s(v)
        elif t == 4: out += struct.pack("<I", v)
        elif t == 6: out += struct.pack("<f", v)
        elif t == 9:
            if k.endswith("tokens"):
                out += struct.pack("<IQ", 8, len(v))
                for tok in v: out += s(tok)
            elif k.endswith("scores"):
                out += struct.pack("<IQ", 6, len(v)) + struct.pack(f"<{len(v)}f", *v)
            else:
                out += struct.pack("<IQ", 5, len(v)) + struct.pack(f"<{len(v)}i", *v)
    # tensor directory with offsets
    blobs = []
    offset = 0
    infos = []
    for idx, (name, dims, tt) in enumerate(tensors):
        n = 1
        for d in dims: n *= d
        data_vals = vals(n, idx)
        if tt == 30: blob = struct.pack(f"<{n}H", *[bf16(x) for x in data_vals])
        else: blob = struct.pack(f"<{n}f", *data_vals)
        infos.append((name, dims, tt, offset))
        blobs.append(blob)
        offset += len(blob)
        pad = (-offset) % 32
        blobs.append(b"\x00" * pad); offset += pad
    for name, dims, tt, off in infos:
        out += s(name) + struct.pack("<I", len(dims))
        for d in dims: out += struct.pack("<Q", d)
        out += struct.pack("<IQ", tt, off)
    pad = (-len(out)) % 32
    out += b"\x00" * pad
    for b in blobs: out += b
    with open(path, "wb") as f: f.write(bytes(out))
    print(f"wrote {path} variant {variant} tensors {len(tensors)} bytes {len(out)}")

if __name__ == "__main__":
    write(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "main")
