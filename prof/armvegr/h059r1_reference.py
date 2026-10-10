# H059R1 — NumPy TEXTBOOK reference forward pass for TinyLlama-1.1B-Chat-v1.0 (Q4_0).
# TEST-ONLY. Implements the well-known Llama forward pass independently of
# armvegr/infer.mojo: embedding -> 22 x [rmsnorm -> GQA attn (RoPE) -> resid
# -> rmsnorm -> SwiGLU -> resid] -> rmsnorm -> LM head. All math in float32
# (more precise than the fp16 Mojo path, so it is a valid reference).
# Usage: python3 prof/armvegr/h059r1_reference.py <gguf> [ntokens] [out.npz]

import numpy as np
import struct
import sys

GGML_F32, GGML_F16, GGML_Q4_0, GGML_Q8_0, GGML_Q6_K = 0, 1, 2, 8, 14


def _skip_val(f, t):
    if t in (0, 1):
        f.seek(1, 1)
    elif t in (2, 3):
        f.seek(2, 1)
    elif t in (4, 5, 6):
        f.seek(4, 1)
    elif t == 7:
        f.seek(1, 1)
    elif t == 8:
        (l,) = struct.unpack('<Q', f.read(8)); f.seek(l, 1)
    elif t == 9:
        (et,) = struct.unpack('<I', f.read(4)); (n,) = struct.unpack('<Q', f.read(8))
        for _ in range(n):
            _skip_val(f, et)
    elif t in (10, 11, 12):
        f.seek(8, 1)
    else:
        raise ValueError(f'unknown meta type {t}')


def load_gguf(path):
    f = open(path, 'rb')
    assert f.read(4) == b'GGUF', 'bad magic'
    version = struct.unpack('<I', f.read(4))[0]
    n_tensors = struct.unpack('<Q', f.read(8))[0]
    n_kv = struct.unpack('<Q', f.read(8))[0]
    for _ in range(n_kv):
        (kl,) = struct.unpack('<Q', f.read(8)); f.seek(kl, 1)
        (t,) = struct.unpack('<I', f.read(4)); _skip_val(f, t)
    infos = []
    for _ in range(n_tensors):
        (nl,) = struct.unpack('<Q', f.read(8)); name = f.read(nl).decode()
        (nd,) = struct.unpack('<I', f.read(4))
        dims = [struct.unpack('<Q', f.read(8))[0] for _ in range(nd)]
        (dtype,) = struct.unpack('<I', f.read(4))
        (off,) = struct.unpack('<Q', f.read(8))
        infos.append((name, dims, dtype, off))
    data_start = (f.tell() + 31) // 32 * 32
    f.close()
    raw = np.memmap(path, dtype=np.uint8, mode='r')  # paged, not resident
    tensors = {}
    CH = 65536  # blocks per chunk
    for (name, dims, dtype, off) in infos:
        n = 1
        for d in dims:
            n *= d
        base = data_start + off
        if dtype == GGML_F32:
            arr = np.frombuffer(raw, dtype='<f4', count=n, offset=base).astype(np.float32)
        elif dtype == GGML_F16:
            arr = np.frombuffer(raw, dtype='<f2', count=n, offset=base).astype(np.float32)
        elif dtype == GGML_Q4_0:
            # GGML layout: byte j holds element j (low nibble), element j+16 (high).
            assert n % 32 == 0
            nb = n // 32
            arr = np.empty(n, dtype=np.float32)
            for c in range(0, nb, CH):
                ce = min(c + CH, nb)
                blk = np.frombuffer(raw, dtype=np.uint8, count=(ce - c) * 18,
                                    offset=base + c * 18).reshape(ce - c, 18)
                dd = blk[:, 0:2].view('<f2').astype(np.float32)
                qs = blk[:, 2:]
                lo = (qs & 0xF).astype(np.float32)
                hi = ((qs >> 4) & 0xF).astype(np.float32)
                seg = arr[c * 32:ce * 32].reshape(ce - c, 32)
                seg[:, 0:16] = lo
                seg[:, 16:32] = hi
                seg -= 8.0
                seg *= dd.reshape(ce - c, 1)
        elif dtype == GGML_Q6_K:
            # GGML layout per ggml-quants.c dequantize_row_q6_K.
            assert n % 256 == 0
            nb = n // 256
            arr = np.empty(n, dtype=np.float32)
            CHK = 8192
            for c in range(0, nb, CHK):
                ce = min(c + CHK, nb)
                m = ce - c
                blk = np.frombuffer(raw, dtype=np.uint8, count=m * 210,
                                    offset=base + c * 210).reshape(m, 210)
                dd = blk[:, 208:210].view('<f2').astype(np.float32).reshape(m)
                sc = blk[:, 192:208].astype(np.int8).astype(np.float32)
                ql = blk[:, 0:128].astype(np.int32)
                qh = blk[:, 128:192].astype(np.int32)
                seg = arr[c * 256:ce * 256].reshape(m, 256)
                for j in (0, 128):
                    ql_s = ql[:, j // 2:j // 2 + 64]
                    qh_s = qh[:, j // 4:j // 4 + 32]
                    sc_s = sc[:, j // 16:j // 16 + 8]
                    for l in range(32):
                        is_ = l // 16
                        b0 = ql_s[:, l]
                        b1 = ql_s[:, l + 32]
                        hb = qh_s[:, l]
                        q1 = (b0 & 0xF) | ((hb & 0x3) << 4)
                        q2 = (b1 & 0xF) | (((hb >> 2) & 0x3) << 4)
                        q3 = ((b0 >> 4) & 0xF) | (((hb >> 4) & 0x3) << 4)
                        q4 = ((b1 >> 4) & 0xF) | (((hb >> 6) & 0x3) << 4)
                        seg[:, j + l] = dd * sc_s[:, is_] * (q1 - 32)
                        seg[:, j + l + 32] = dd * sc_s[:, is_ + 2] * (q2 - 32)
                        seg[:, j + l + 64] = dd * sc_s[:, is_ + 4] * (q3 - 32)
                        seg[:, j + l + 96] = dd * sc_s[:, is_ + 6] * (q4 - 32)
        else:
            raise ValueError(f'unsupported dtype {dtype} for {name}')
        # GGUF stores dims with dims[0] = minor (contiguous). Row-major [outer..inner]
        # i.e. shape reversed: numpy shape = dims[::-1].
        arr = arr.reshape(tuple(dims[::-1]))
        tensors[name] = arr
        print(f'  {name}: dims={dims} dtype={dtype} shape={arr.shape}', flush=True)
    return tensors


def rmsnorm(x, w, eps=1e-5):
    return x / np.sqrt(np.mean(x ** 2) + eps) * w


def rope(x, pos, theta=10000.0):
    # x: (..., head_dim); GPT-NeoX interleaved pairs.
    hd = x.shape[-1]
    out = np.empty_like(x)
    for i in range(hd // 2):
        ang = pos * theta ** (-2.0 * i / hd)
        c, s = np.cos(ang), np.sin(ang)
        x0, x1 = x[..., 2 * i], x[..., 2 * i + 1]
        out[..., 2 * i] = x0 * c - x1 * s
        out[..., 2 * i + 1] = x0 * s + x1 * c
    return out


def silu(x):
    return x / (1.0 + np.exp(-x))


def forward(t, token_ids, dump=None):
    DIM, N_L, NH, NKV, HD, FFD = 2048, 22, 32, 4, 64, 5632
    n_tok = len(token_ids)
    k_cache = np.zeros((N_L, n_tok, NKV, HD), np.float32)
    v_cache = np.zeros((N_L, n_tok, NKV, HD), np.float32)
    logits_all = []
    for pos, tok in enumerate(token_ids):
        x = t['token_embd.weight'][tok].copy()  # (2048,)
        if dump is not None and pos == dump['pos']:
            dump['emb'] = x.copy()
        for L in range(N_L):
            p = f'blk.{L}.'
            h = rmsnorm(x, t[p + 'attn_norm.weight'])
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['attn_norm'] = h.copy()
            q = (t[p + 'attn_q.weight'] @ h).reshape(NH, HD)
            k = (t[p + 'attn_k.weight'] @ h).reshape(NKV, HD)
            v = (t[p + 'attn_v.weight'] @ h).reshape(NKV, HD)
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['q_pre'] = q.copy(); dump['k_pre'] = k.copy(); dump['v'] = v.copy()
            q = rope(q, pos); k = rope(k, pos)
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['q_post'] = q.copy(); dump['k_post'] = k.copy()
            k_cache[L, pos] = k; v_cache[L, pos] = v
            # GQA: q head hq -> kv head hq//8; causal over 0..pos
            attn = np.empty((NH, HD), np.float32)
            for hq in range(NH):
                kh = hq // 8
                sc = (q[hq][None, :] @ k_cache[L, :pos + 1, kh].T) / np.sqrt(HD)
                sc = sc - sc.max()
                e = np.exp(sc); w = e / e.sum()
                attn[hq] = w @ v_cache[L, :pos + 1, kh]
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['attn_out'] = attn.reshape(-1).copy()
            o = t[p + 'attn_output.weight'] @ attn.reshape(-1)
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['o_proj'] = o.copy()
            x = x + o
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['x_attn_resid'] = x.copy()
            h = rmsnorm(x, t[p + 'ffn_norm.weight'])
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['ffn_norm'] = h.copy()
            g = t[p + 'ffn_gate.weight'] @ h
            u = t[p + 'ffn_up.weight'] @ h
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['gate'] = g.copy(); dump['up'] = u.copy()
            fg = silu(g) * u
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['ffn_mid'] = fg.copy()
            fd = t[p + 'ffn_down.weight'] @ fg
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['ffn_down'] = fd.copy()
            x = x + fd
            if dump is not None and pos == dump['pos'] and L == dump['layer']:
                dump['x_ffn_resid'] = x.copy()
        h = rmsnorm(x, t['output_norm.weight'])
        if dump is not None and pos == dump['pos']:
            dump['final_norm'] = h.copy()
        logits = t['output.weight'] @ h
        logits_all.append(logits)
        if dump is not None and pos == dump['pos']:
            dump['logits'] = logits.copy()
    return logits_all


def main():
    path = sys.argv[1]
    ntok_extra = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    out = sys.argv[3] if len(sys.argv) > 3 else None
    print('loading', path, flush=True)
    t = load_gguf(path)
    # token 15043 = "Hello" (verified by H059 tokenizer work)
    ids = [15043] + [15043] * ntok_extra
    dump = {'pos': len(ids) - 1, 'layer': 0}
    logits_all = forward(t, ids, dump=dump)
    for pos, logits in enumerate(logits_all):
        top = np.argsort(logits)[-8:][::-1]
        e = np.exp(logits - logits.max()); e /= e.sum()
        ent = -(e * np.log(e + 1e-30)).sum()
        print(f'pos {pos}: top8={top.tolist()} entropy={ent:.3f}', flush=True)
    if out:
        np.savez(out, **{k: v for k, v in dump.items() if isinstance(v, np.ndarray)})
        print('dumped', out, flush=True)


if __name__ == '__main__':
    main()
