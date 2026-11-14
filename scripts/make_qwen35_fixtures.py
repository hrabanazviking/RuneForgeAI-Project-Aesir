#!/usr/bin/env python3
"""Q35-1: deterministic synthetic qwen35 GGUF fixtures (tiny, correct SSM geometry).

Writes three GGUF v3 files into aesir_engine/tests/fixtures/:
  qwen35_tiny.gguf        -- correct geometry (synthetic)
  qwen35_tiny_bad_qkv.gguf -- mutated: attn_qkv rows = qkv_width + 32 (malformed)
  qwen35_tiny_type_probe.gguf -- same shapes as the good fixture, but
                             blk.*.attn_gate.weight is stored F16 while the
                             validator records Q8_0 (U2 type-enforcement probe)

Geometry (formula-driven, mirrors the real 27B layout at tiny scale):
  hidden=32, ffn=64, vocab=16, block_count=4, full_attention_interval=4
  (layers 0-2 SSM, layer 3 full attention), head_count=4, head_count_kv=2,
  head_dim=8, ssm groups=2, state=8, dt_rank=3, inner=dt_rank*state=24,
  qkv_width = 2*groups*state + inner = 56, ssm.conv_kernel=4, context=64.
Tensor types mirror the real file census: weight matrices Q8_0, norms /
ssm_a / ssm_conv1d / ssm_dt.bias / ssm_norm F32.
GGUF dims are [cols, rows] (dim0 is the fastest axis); the loader folds
them to rows x cols. Q8_0 payloads: one 34-byte block per 32 elements
(f16 scale 1.0 + 32 zero int8 values). Deterministic: fixed fills only.
Note: *.gguf is gitignored repo-wide, so these bytes are generated
artifacts (regenerate with this script); they are not registered in
fixture_manifest.json, whose checker requires tracked fixture paths.
"""
import struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "aesir_engine" / "tests" / "fixtures"
H, FFN, V, NB, CTX = 32, 64, 16, 4, 64
NHEAD, NKV, HD = 4, 2, 8
GROUPS, STATE, DT, KERNEL = 2, 8, 3, 4
INNER = DT * STATE
QKV = 2 * GROUPS * STATE + INNER
INTERVAL = 4
QW, KVD = NHEAD * HD, NKV * HD
F32, F16, Q8_0 = 0, 1, 8

def w_str(buf, s):
    b = s.encode(); buf += struct.pack("<Q", len(b)) + b
def f16fill(n, val=0.5): return struct.pack("<" + "e" * n, *([val] * n))
def f32fill(n, val=0.25): return struct.pack("<" + "f" * n, *([val] * n))
def q80fill(n):
    assert n % 32 == 0, n
    return (struct.pack("<e", 1.0) + bytes(32)) * (n // 32)

def build(path, bad_qkv=False, type_probe=False):
    kvs = []
    def ku32(k, v): kvs.append((k, 4, struct.pack("<I", v)))
    def kf32(k, v): kvs.append((k, 6, struct.pack("<f", v)))
    def kstr(k, v): kvs.append((k, 8, struct.pack("<Q", len(v.encode())) + v.encode()))
    kstr("general.architecture", "qwen35")
    ku32("qwen35.context_length", CTX); ku32("qwen35.embedding_length", H)
    ku32("qwen35.feed_forward_length", FFN); ku32("qwen35.block_count", NB)
    ku32("qwen35.attention.head_count", NHEAD); ku32("qwen35.attention.head_count_kv", NKV)
    ku32("qwen35.attention.key_length", HD); ku32("qwen35.rope.dimension_count", HD)
    kf32("qwen35.rope.freq_base", 10000.0); kf32("qwen35.attention.layer_norm_rms_epsilon", 1e-5)
    ku32("qwen35.ssm.conv_kernel", KERNEL); ku32("qwen35.ssm.state_size", STATE)
    ku32("qwen35.ssm.group_count", GROUPS); ku32("qwen35.ssm.time_step_rank", DT)
    ku32("qwen35.ssm.inner_size", INNER); ku32("qwen35.full_attention_interval", INTERVAL)
    toks = [("<unk>" if i == 0 else "<s>" if i == 1 else "</s>" if i == 2 else "tok%02d" % i).encode() for i in range(V)]
    arr = struct.pack("<I", 8) + struct.pack("<Q", V)
    for t in toks: arr += struct.pack("<Q", len(t)) + t
    kvs.append(("tokenizer.ggml.tokens", 9, arr))
    kvs.append(("tokenizer.ggml.scores", 9, struct.pack("<I", 6) + struct.pack("<Q", V) + struct.pack("<" + "f" * V, *([0.0] * V))))
    kvs.append(("tokenizer.ggml.token_type", 9, struct.pack("<I", 5) + struct.pack("<Q", V) + struct.pack("<" + "i" * V, *([1] * V))))
    ku32("tokenizer.ggml.bos_token_id", 1); ku32("tokenizer.ggml.eos_token_id", 2); ku32("tokenizer.ggml.unknown_token_id", 0)
    tensors = []
    def add(name, dims, gt, payload): tensors.append((name, dims, gt, payload))
    # explicit tensors: dims are [cols, rows]
    def mat(name, cols, rows, gt=Q8_0):
        pay = q80fill(cols * rows) if gt == Q8_0 else f16fill(cols * rows) if gt == F16 else f32fill(cols * rows)
        add(name, [cols, rows], gt, pay)
    def vec(name, n, gt=F32):
        pay = f32fill(n) if gt == F32 else f16fill(n)
        add(name, [n], gt, pay)
    mat("token_embd.weight", H, V); vec("output_norm.weight", H); mat("output.weight", H, V)
    qkv_rows = QKV + 32 if bad_qkv else QKV
    for i in range(NB):
        p = "blk.%d." % i
        vec(p + "attn_norm.weight", H); vec(p + "post_attention_norm.weight", H)
        mat(p + "ffn_gate.weight", H, FFN); mat(p + "ffn_up.weight", H, FFN); mat(p + "ffn_down.weight", FFN, H)
        if (i + 1) % INTERVAL == 0:
            mat(p + "attn_q.weight", H, 2 * QW); mat(p + "attn_k.weight", H, KVD); mat(p + "attn_v.weight", H, KVD)
            mat(p + "attn_output.weight", QW, H); vec(p + "attn_q_norm.weight", HD); vec(p + "attn_k_norm.weight", HD)
        else:
            mat(p + "attn_qkv.weight", H, qkv_rows)
            if type_probe: mat(p + "attn_gate.weight", H, INNER, F16)
            else: mat(p + "attn_gate.weight", H, INNER)
            mat(p + "ssm_alpha.weight", H, DT); mat(p + "ssm_beta.weight", H, DT)
            vec(p + "ssm_a", DT); add(p + "ssm_conv1d.weight", [KERNEL, QKV], F32, f32fill(KERNEL * QKV))
            vec(p + "ssm_dt.bias", DT); vec(p + "ssm_norm.weight", STATE); mat(p + "ssm_out.weight", INNER, H)
    buf = bytearray(); buf += struct.pack("<4sIQQ", b"GGUF", 3, len(tensors), len(kvs))
    for k, vt, pay in kvs: w_str(buf, k); buf += struct.pack("<I", vt) + pay
    off, infos = 0, []
    for name, dims, gt, pay in tensors:
        infos.append((name, dims, gt, off)); off = ((off + len(pay) + 31) // 32) * 32
    for name, dims, gt, o in infos:
        w_str(buf, name); buf += struct.pack("<I", len(dims))
        for d in dims: buf += struct.pack("<Q", d)
        buf += struct.pack("<IQ", gt, o)
    data_off = ((len(buf) + 31) // 32) * 32; buf += b"\x00" * (data_off - len(buf))
    for (name, dims, gt, o), (_, _, _, pay) in zip(infos, tensors):
        assert len(buf) == data_off + o, name
        buf += pay; buf += b"\x00" * (((len(pay) + 31) // 32) * 32 - len(pay))
    path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(bytes(buf))
    print("wrote", path, len(buf), "bytes,", len(tensors), "tensors, qkv_width", QKV)

if __name__ == "__main__":
    build(OUT / "qwen35_tiny.gguf")
    build(OUT / "qwen35_tiny_bad_qkv.gguf", bad_qkv=True)
    build(OUT / "qwen35_tiny_type_probe.gguf", type_probe=True)
