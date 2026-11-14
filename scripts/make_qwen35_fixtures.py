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


# ---------------------------------------------------------------------------
# Q35-3 forward fixture: PackedGGUF-aligned geometry with deterministic
# seeded pseudo-random weights of sane scale (the Q35-1 tiny fixture's
# zero Q8_0 payloads and 24-col ssm_out cannot exercise the forward).
#   hidden 128, ffn 256, heads 2, kv_heads 1, head_dim 64,
#   groups 2, state 16, dt_rank 4, inner 64, qkv_width 128,
#   conv_kernel 4, blocks 4, interval 4, vocab 1024, context 512.
# Every Q8_0 tensor's input width (GGUF dim0 = cols) is % 32 == 0:
# hidden 128, ffn 256, inner 64, q_width 128 -- all aligned.
# Q8_0 payload: per-32 block, f16 scale + 32 int8 from the seeded RNG.
# ssm_a is kept negative (decay exp(a*dt) < 1) and dt_bias small, so the
# recurrence is stable by construction; norms sit near 1.0.
import random as _random

def build_forward(path):
    H2, FFN2, V2, NB2, CTX2 = 128, 256, 1024, 4, 512
    NHEAD2, NKV2, HD2 = 2, 1, 64
    GROUPS2, STATE2, DT2, KERNEL2 = 2, 16, 4, 4
    INNER2 = DT2 * STATE2
    QKV2 = 2 * GROUPS2 * STATE2 + INNER2
    INTERVAL2 = 4
    QW2, KVD2 = NHEAD2 * HD2, NKV2 * HD2
    rng = _random.Random(20261114)
    def q80rand(n, scale, amp):
        assert n % 32 == 0, n
        out = bytearray()
        for _ in range(n // 32):
            out += struct.pack("<e", scale)
            out += bytes((rng.randint(-amp, amp) & 0xFF) for _ in range(32))
        return bytes(out)
    def f32rand(n, lo, hi):
        return struct.pack("<" + "f" * n, *([rng.uniform(lo, hi) for _ in range(n)]))
    kvs = []
    def ku32(k, v): kvs.append((k, 4, struct.pack("<I", v)))
    def kf32(k, v): kvs.append((k, 6, struct.pack("<f", v)))
    def kstr(k, v): kvs.append((k, 8, struct.pack("<Q", len(v.encode())) + v.encode()))
    kstr("general.architecture", "qwen35")
    ku32("qwen35.context_length", CTX2); ku32("qwen35.embedding_length", H2)
    ku32("qwen35.feed_forward_length", FFN2); ku32("qwen35.block_count", NB2)
    ku32("qwen35.attention.head_count", NHEAD2); ku32("qwen35.attention.head_count_kv", NKV2)
    ku32("qwen35.attention.key_length", HD2); ku32("qwen35.rope.dimension_count", 64)
    kf32("qwen35.rope.freq_base", 10000.0); kf32("qwen35.attention.layer_norm_rms_epsilon", 1e-5)
    ku32("qwen35.ssm.conv_kernel", KERNEL2); ku32("qwen35.ssm.state_size", STATE2)
    ku32("qwen35.ssm.group_count", GROUPS2); ku32("qwen35.ssm.time_step_rank", DT2)
    ku32("qwen35.ssm.inner_size", INNER2); ku32("qwen35.full_attention_interval", INTERVAL2)
    # Q35-4a toy tokenizer (byte-level, no merges): id 0/1/2 are
    # <unk>/<s>/</s>, id 3 is newline, ids 4..98 are the printable
    # ASCII characters 0x20..0x7E in order, and ids 99..1023 keep
    # the tok%04d spellings (reachable only as generated output).
    # RuneWeaver's SentencePiece path splits text into per-codepoint
    # pieces, so ordinary text encodes one token per character and
    # every generated id decodes to its own spelling.
    toks = []
    for i in range(V2):
        if i == 0: t = "<unk>"
        elif i == 1: t = "<s>"
        elif i == 2: t = "</s>"
        elif i == 3: t = "\n"
        elif 4 <= i <= 98: t = chr(0x20 + (i - 4))
        else: t = "tok%04d" % i
        toks.append(t.encode())
    arr = struct.pack("<I", 8) + struct.pack("<Q", V2)
    for tk in toks: arr += struct.pack("<Q", len(tk)) + tk
    kvs.append(("tokenizer.ggml.tokens", 9, arr))
    kvs.append(("tokenizer.ggml.scores", 9, struct.pack("<I", 6) + struct.pack("<Q", V2) + struct.pack("<" + "f" * V2, *([0.0] * V2))))
    kvs.append(("tokenizer.ggml.token_type", 9, struct.pack("<I", 5) + struct.pack("<Q", V2) + struct.pack("<" + "i" * V2, *([1] * V2))))
    ku32("tokenizer.ggml.bos_token_id", 1); ku32("tokenizer.ggml.eos_token_id", 2); ku32("tokenizer.ggml.unknown_token_id", 0)
    tensors = []
    def add(name, dims, gt, payload): tensors.append((name, dims, gt, payload))
    def mat(name, cols, rows, scale=0.03, amp=24):
        add(name, [cols, rows], Q8_0, q80rand(cols * rows, scale, amp))
    def vec(name, n, lo, hi):
        add(name, [n], F32, f32rand(n, lo, hi))
    mat("token_embd.weight", H2, V2, 0.02, 32); vec("output_norm.weight", H2, 0.9, 1.1); mat("output.weight", H2, V2)
    for i in range(NB2):
        pfx = "blk.%d." % i
        vec(pfx + "attn_norm.weight", H2, 0.9, 1.1); vec(pfx + "post_attention_norm.weight", H2, 0.9, 1.1)
        mat(pfx + "ffn_gate.weight", H2, FFN2); mat(pfx + "ffn_up.weight", H2, FFN2); mat(pfx + "ffn_down.weight", FFN2, H2)
        if (i + 1) % INTERVAL2 == 0:
            mat(pfx + "attn_q.weight", H2, 2 * QW2); mat(pfx + "attn_k.weight", H2, KVD2); mat(pfx + "attn_v.weight", H2, KVD2)
            mat(pfx + "attn_output.weight", QW2, H2); vec(pfx + "attn_q_norm.weight", HD2, 0.9, 1.1); vec(pfx + "attn_k_norm.weight", HD2, 0.9, 1.1)
        else:
            mat(pfx + "attn_qkv.weight", H2, QKV2)
            mat(pfx + "attn_gate.weight", H2, INNER2)
            mat(pfx + "ssm_alpha.weight", H2, DT2); mat(pfx + "ssm_beta.weight", H2, DT2)
            vec(pfx + "ssm_a", DT2, -3.0, -0.5)
            add(pfx + "ssm_conv1d.weight", [KERNEL2, QKV2], F32, f32rand(KERNEL2 * QKV2, -0.25, 0.25))
            vec(pfx + "ssm_dt.bias", DT2, -0.5, 0.5); vec(pfx + "ssm_norm.weight", STATE2, 0.9, 1.1)
            mat(pfx + "ssm_out.weight", INNER2, H2)
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
    print("wrote", path, len(buf), "bytes,", len(tensors), "tensors, qkv_width", QKV2)

if __name__ == "__main__":
    build(OUT / "qwen35_tiny.gguf")
    build(OUT / "qwen35_tiny_bad_qkv.gguf", bad_qkv=True)
    build(OUT / "qwen35_tiny_type_probe.gguf", type_probe=True)
    build_forward(OUT / "qwen35_forward.gguf")
