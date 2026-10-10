# TEST-ONLY (PRÓF): GGUF corpus generator for H041 port-diff.
# Deterministic: same bytes on any machine. Run: python3 make_gguf_corpus.py <outdir>
import struct, os, sys

def w_str(buf, s):
    b = s.encode()
    buf += struct.pack("<Q", len(b)) + b
def w_kv(buf, key, vtype, payload):
    w_str(buf, key); buf += struct.pack("<I", vtype) + payload

H, FFN, V, NHEAD, NKV, HD, NB, CTX = 64, 128, 256, 8, 2, 8, 2, 512
QW, KVD = NHEAD*HD, NKV*HD

def build_mixed(path):
    buf = bytearray()
    kvs = []
    def ku32(k, v): kvs.append((k, 4, struct.pack("<I", v)))
    def kf32(k, v): kvs.append((k, 6, struct.pack("<f", v)))
    def kstr(k, v): kvs.append((k, 8, struct.pack("<Q", len(v.encode())) + v.encode()))
    kstr("general.architecture", "llama")
    ku32("llama.context_length", CTX); ku32("llama.embedding_length", H)
    ku32("llama.feed_forward_length", FFN); ku32("llama.block_count", NB)
    ku32("llama.attention.head_count", NHEAD); ku32("llama.attention.head_count_kv", NKV)
    ku32("llama.rope.dimension_count", HD); kf32("llama.rope.freq_base", 10000.0)
    kf32("llama.attention.layer_norm_rms_epsilon", 1e-5)
    toks = [("tok%03d" % i).encode() for i in range(V)]
    toks_arr = struct.pack("<I", 8) + struct.pack("<Q", V)
    for t in toks: toks_arr += struct.pack("<Q", len(t)) + t
    kvs.append(("tokenizer.ggml.tokens", 9, toks_arr))
    kvs.append(("tokenizer.ggml.scores", 9, struct.pack("<I", 6) + struct.pack("<Q", V) + struct.pack("<"+"f"*V, *([0.0]*V))))
    kvs.append(("tokenizer.ggml.token_type", 9, struct.pack("<I", 5) + struct.pack("<Q", V) + struct.pack("<"+"i"*V, *([1]*V))))
    ku32("tokenizer.ggml.bos_token_id", 1); ku32("tokenizer.ggml.eos_token_id", 2)
    ku32("tokenizer.ggml.unknown_token_id", 0)
    kvs.append(("tokenizer.ggml.add_bos_token", 7, b"\x01"))
    tensors = []  # (name, dims(ne0,ne1...), gtype, payload)
    F16, F32, Q40, Q80 = 1, 0, 2, 8
    def add(name, dims, gt, payload):
        tensors.append((name, dims, gt, payload))
    def f16fill(n, val=0.5):
        return struct.pack("<"+"e"*n, *([val]*n))
    def f32fill(n, val=0.25):
        return struct.pack("<"+"f"*n, *([val]*n))
    def q80fill(n):
        blk = struct.pack("<e", 1.0) + bytes(32)
        return blk * (n // 32)
    def q40fill(n):
        blk = struct.pack("<e", 1.0) + struct.pack("<e", 0.0) + bytes(16)
        return blk * (n // 32)
    add("token_embd.weight", [H, V], F16, f16fill(H*V))
    add("output_norm.weight", [H], F32, f32fill(H))
    for i in range(NB):
        p = "blk.%d." % i
        add(p+"attn_norm.weight", [H], F32, f32fill(H))
        add(p+"attn_q.weight", [H, QW], F16, f16fill(H*QW))
        add(p+"attn_k.weight", [H, KVD], F16, f16fill(H*KVD))
        add(p+"attn_v.weight", [H, KVD], F16, f16fill(H*KVD))
        add(p+"attn_output.weight", [QW, H], F16, f16fill(QW*H))
        add(p+"ffn_norm.weight", [H], F32, f32fill(H))
        add(p+"ffn_gate.weight", [H, FFN], F16, f16fill(H*FFN))
        add(p+"ffn_up.weight", [H, FFN], F16, f16fill(H*FFN))
        add(p+"ffn_down.weight", [FFN, H], F16, f16fill(FFN*H))
    add("extra.q80.weight", [64, 32], Q80, q80fill(2048))
    add("extra.q40.weight", [64, 32], Q40, q40fill(2048))
    add("extra.f16.weight", [32, 16], F16, f16fill(512))
    add("extra.f32.weight", [16, 8], F32, f32fill(128))
    buf += struct.pack("<4sIQQ", b"GGUF", 3, len(tensors), len(kvs))
    for k, vt, pay in kvs: w_kv(buf, k, vt, pay)
    off = 0
    infos = []
    for name, dims, gt, pay in tensors:
        infos.append((name, dims, gt, off))
        off = ((off + len(pay) + 31) // 32) * 32
    for name, dims, gt, o in infos:
        w_str(buf, name)
        buf += struct.pack("<I", len(dims))
        for d in dims: buf += struct.pack("<Q", d)
        buf += struct.pack("<IQ", gt, o)
    data_off = ((len(buf) + 31) // 32) * 32
    buf += b"\x00" * (data_off - len(buf))
    for (name, dims, gt, o), (_, _, _, pay) in zip(infos, tensors):
        assert len(buf) == data_off + o, (name, len(buf), data_off+o)
        buf += pay
        pad = ((len(pay) + 31)//32)*32 - len(pay)
        buf += b"\x00" * pad
    open(path, "wb").write(bytes(buf))
    print("wrote", path, len(buf), "bytes,", len(tensors), "tensors")

def build_v2(path):
    buf = bytearray(struct.pack("<4sIQQ", b"GGUF", 2, 1, 1))
    w_kv(buf, "general.architecture", 8, struct.pack("<Q", 5) + b"llama")
    w_str(buf, "t.weight"); buf += struct.pack("<IQ", 1, 1) + struct.pack("<Q", 8) + struct.pack("<IQ", 1, 0)
    open(path, "wb").write(bytes(buf))
    print("wrote", path, len(buf), "bytes")

# --- H041 extended corpus variants (same helper core, different mixes) ---
def _kv_llama(kvs):
    def ku32(k, v): kvs.append((k, 4, struct.pack("<I", v)))
    def kf32(k, v): kvs.append((k, 6, struct.pack("<f", v)))
    def kstr(k, v): kvs.append((k, 8, struct.pack("<Q", len(v.encode())) + v.encode()))
    kstr("general.architecture", "llama")
    ku32("llama.context_length", CTX); ku32("llama.embedding_length", H)
    ku32("llama.feed_forward_length", FFN); ku32("llama.block_count", NB)
    ku32("llama.attention.head_count", NHEAD); ku32("llama.attention.head_count_kv", NKV)
    ku32("llama.rope.dimension_count", HD); kf32("llama.rope.freq_base", 10000.0)
    kf32("llama.attention.layer_norm_rms_epsilon", 1e-5)
    toks = [("tok%03d" % i).encode() for i in range(V)]
    toks_arr = struct.pack("<I", 8) + struct.pack("<Q", V)
    for t in toks: toks_arr += struct.pack("<Q", len(t)) + t
    kvs.append(("tokenizer.ggml.tokens", 9, toks_arr))
    kvs.append(("tokenizer.ggml.scores", 9, struct.pack("<I", 6) + struct.pack("<Q", V) + struct.pack("<"+"f"*V, *([0.0]*V))))
    kvs.append(("tokenizer.ggml.token_type", 9, struct.pack("<I", 5) + struct.pack("<Q", V) + struct.pack("<"+"i"*V, *([1]*V))))
    ku32("tokenizer.ggml.bos_token_id", 1); ku32("tokenizer.ggml.eos_token_id", 2)
    ku32("tokenizer.ggml.unknown_token_id", 0)
    kvs.append(("tokenizer.ggml.add_bos_token", 7, b"\x01"))

def _emit(path, kvs, tensors):
    buf = bytearray()
    buf += struct.pack("<4sIQQ", b"GGUF", 3, len(tensors), len(kvs))
    for k, vt, pay in kvs: w_kv(buf, k, vt, pay)
    off, infos = 0, []
    for name, dims, gt, pay in tensors:
        infos.append((name, dims, gt, off))
        off = ((off + len(pay) + 31) // 32) * 32
    for name, dims, gt, o in infos:
        w_str(buf, name)
        buf += struct.pack("<I", len(dims))
        for d in dims: buf += struct.pack("<Q", d)
        buf += struct.pack("<IQ", gt, o)
    data_off = ((len(buf) + 31) // 32) * 32
    buf += b"\x00" * (data_off - len(buf))
    for (name, dims, gt, o), (_, _, _, pay) in zip(infos, tensors):
        assert len(buf) == data_off + o, (name, len(buf), data_off+o)
        buf += pay
        buf += b"\x00" * (((len(pay) + 31)//32)*32 - len(pay))
    open(path, "wb").write(bytes(buf))
    print("wrote", path, len(buf), "bytes,", len(tensors), "tensors")

def _fills():
    def f16fill(n, val=0.5): return struct.pack("<"+"e"*n, *([val]*n))
    def f32fill(n, val=0.25): return struct.pack("<"+"f"*n, *([val]*n))
    def q80fill(n):
        blk = struct.pack("<e", 1.0) + bytes(32)
        return blk * (n // 32)
    def q40fill(n):
        blk = struct.pack("<e", 1.0) + struct.pack("<e", 0.0) + bytes(16)
        return blk * (n // 32)
    def q41fill(n):
        blk = struct.pack("<e", 1.0) + struct.pack("<e", 0.0) + bytes(16) + bytes(4)
        return blk * (n // 32)
    def q50fill(n):
        blk = struct.pack("<e", 1.0) + struct.pack("<e", 0.0) + bytes(20)
        return blk * (n // 32)
    return f16fill, f32fill, q80fill, q40fill, q41fill, q50fill

def _required_tensors(f16fill, f32fill):
    F16, F32 = 1, 0
    t = []
    t.append(("token_embd.weight", [H, V], F16, f16fill(H*V)))
    t.append(("output_norm.weight", [H], F32, f32fill(H)))
    for i in range(NB):
        p = "blk.%d." % i
        t.append((p+"attn_norm.weight", [H], F32, f32fill(H)))
        t.append((p+"attn_q.weight", [H, QW], F16, f16fill(H*QW)))
        t.append((p+"attn_k.weight", [H, KVD], F16, f16fill(H*KVD)))
        t.append((p+"attn_v.weight", [H, KVD], F16, f16fill(H*KVD)))
        t.append((p+"attn_output.weight", [QW, H], F16, f16fill(QW*H)))
        t.append((p+"ffn_norm.weight", [H], F32, f32fill(H)))
        t.append((p+"ffn_gate.weight", [H, FFN], F16, f16fill(H*FFN)))
        t.append((p+"ffn_up.weight", [H, FFN], F16, f16fill(H*FFN)))
        t.append((p+"ffn_down.weight", [FFN, H], F16, f16fill(FFN*H)))
    return t

def build_mixed_small(path):
    f16fill, f32fill, _, _, _, _ = _fills()
    kvs = []; _kv_llama(kvs)
    t = _required_tensors(f16fill, f32fill)
    t.append(("extra.f16.small", [16, 8], 1, f16fill(128, 0.125)))
    _emit(path, kvs, t)

def build_mixed_qextra(path):
    f16fill, f32fill, q80fill, q40fill, q41fill, q50fill = _fills()
    kvs = []; _kv_llama(kvs)
    t = _required_tensors(f16fill, f32fill)
    t.append(("extra.q80.b", [64, 32], 8, q80fill(2048)))
    t.append(("extra.q40.b", [64, 32], 2, q40fill(2048)))
    t.append(("extra.q41.b", [64, 32], 3, q41fill(2048)))
    t.append(("extra.q50.b", [64, 32], 6, q50fill(2048)))
    t.append(("extra.q81.b", [64, 32], 9, q80fill(2048)))
    _emit(path, kvs, t)

def build_mixed_f32(path):
    f16fill, f32fill, _, _, _, _ = _fills()
    kvs = []; _kv_llama(kvs)
    t = _required_tensors(f16fill, f32fill)
    t.append(("extra.f32.a", [32, 16], 0, f32fill(512, 0.75)))
    t.append(("extra.f32.b", [16, 8], 0, f32fill(128, -0.5)))
    _emit(path, kvs, t)

if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(outdir, exist_ok=True)
    build_mixed(os.path.join(outdir, "h041_mixed.gguf"))
    build_v2(os.path.join(outdir, "h041_v2.gguf"))
    build_mixed_small(os.path.join(outdir, "h041_small.gguf"))
    build_mixed_qextra(os.path.join(outdir, "h041_qextra.gguf"))
    build_mixed_f32(os.path.join(outdir, "h041_f32.gguf"))
