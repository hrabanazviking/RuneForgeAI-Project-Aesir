#!/usr/bin/env python3
"""J-120 file-level verifier (pure stdlib, independent).

Re-reads the fixture checkpoint and the converted
GGUF with its own implementations of both formats,
recomputes the LoRA merge the slow way from the
unmerged pair (every intermediate rounded to
Float32), and checks, element for element:

  - the GGUF census (names, GGUF dims, types) equals
    the expected conversion of the fixture census;
  - every merged element equals the slow-way value
    (which is BF16-exact by fixture construction, so
    the stored BF16 must decode to it exactly);
  - every pass-through element equals the BF16
    rounding (round-to-nearest-even, computed here)
    of the base value, and 1-D tensors are stored
    F32 bit-exact;
  - metadata: architecture llama, 19 KV entries,
    alignment 32, vocab 8.

Usage: j120_verify.py <workdir>   (expects
model.safetensors, adapter_model.safetensors,
adapter_config.json, merged.gguf in <workdir>).
Exit 0 and a final ALL PASS line on success.
"""
import json
import struct
import sys

CHECKS = 0
FAILS = []


def check(cond, label):
    global CHECKS
    CHECKS += 1
    if not cond:
        FAILS.append(label)
        print("FAIL:", label)


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


def bf16_bits(x):
    bits = struct.unpack("<I", struct.pack("<f", x))[0]
    lsb = (bits >> 16) & 1
    rounded = (bits + 0x7FFF + lsb) & 0xFFFFFFFF
    return rounded >> 16


def bf16_decode(bits):
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def read_safetensors(path):
    with open(path, "rb") as f:
        data = f.read()
    hlen = struct.unpack("<Q", data[:8])[0]
    header = json.loads(data[8:8 + hlen].decode("utf-8"))
    base = 8 + hlen
    out = {}
    order = []
    for name, meta in header.items():
        if name == "__metadata__":
            continue
        b, e = meta["data_offsets"]
        raw = data[base + b: base + e]
        n = 1
        for d in meta["shape"]:
            n *= d
        vals = list(struct.unpack("<%df" % n, raw))
        out[name] = (meta["shape"], vals)
        order.append(name)
    return out, order


GGUF_NAMES = {
    "model.embed_tokens.weight": "token_embd.weight",
    "lm_head.weight": "output.weight",
    "model.norm.weight": "output_norm.weight",
    "model.layers.0.input_layernorm.weight": "blk.0.attn_norm.weight",
    "model.layers.0.self_attn.q_proj.weight": "blk.0.attn_q.weight",
    "model.layers.0.self_attn.k_proj.weight": "blk.0.attn_k.weight",
    "model.layers.0.self_attn.v_proj.weight": "blk.0.attn_v.weight",
    "model.layers.0.self_attn.o_proj.weight": "blk.0.attn_output.weight",
    "model.layers.0.post_attention_layernorm.weight": "blk.0.ffn_norm.weight",
    "model.layers.0.mlp.gate_proj.weight": "blk.0.ffn_gate.weight",
    "model.layers.0.mlp.up_proj.weight": "blk.0.ffn_up.weight",
    "model.layers.0.mlp.down_proj.weight": "blk.0.ffn_down.weight",
}


def read_gguf(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, nt, nkv = struct.unpack("<IIQQ", data[:24])
    assert magic == 0x46554747, "bad magic"
    assert version == 3, "bad version"
    pos = 24
    meta = {}

    def read_str(p):
        n = struct.unpack("<Q", data[p:p + 8])[0]
        return data[p + 8:p + 8 + n].decode("utf-8"), p + 8 + n

    def skip(p, t):
        if t in (0, 1, 7):
            return p + 1
        if t in (2, 3):
            return p + 2
        if t in (4, 5, 6):
            return p + 4
        if t in (10, 11, 12):
            return p + 8
        if t == 8:
            n = struct.unpack("<Q", data[p:p + 8])[0]
            return p + 8 + n
        if t == 9:
            et = struct.unpack("<I", data[p:p + 4])[0]
            cnt = struct.unpack("<Q", data[p + 4:p + 12])[0]
            q = p + 12
            for _ in range(cnt):
                q = skip(q, et)
            return q
        raise ValueError("bad type %d" % t)

    for _ in range(nkv):
        key, pos = read_str(pos)
        t = struct.unpack("<I", data[pos:pos + 4])[0]
        pos += 4
        start = pos
        pos = skip(pos, t)
        if key == "general.architecture":
            meta["arch"], _ = read_str(start)
        elif key == "general.alignment":
            meta["alignment"] = struct.unpack("<I", data[start:start + 4])[0]
        elif key == "llama.embedding_length":
            meta["hidden"] = struct.unpack("<I", data[start:start + 4])[0]
    tensors = []
    for _ in range(nt):
        name, pos = read_str(pos)
        nd = struct.unpack("<I", data[pos:pos + 4])[0]
        pos += 4
        dims = []
        for _ in range(nd):
            dims.append(struct.unpack("<Q", data[pos:pos + 8])[0])
            pos += 8
        t = struct.unpack("<I", data[pos:pos + 4])[0]
        pos += 4
        off = struct.unpack("<Q", data[pos:pos + 8])[0]
        pos += 8
        tensors.append((name, dims, t, off))
    data_offset = (pos + meta["alignment"] - 1) // meta["alignment"] * meta["alignment"]
    out = {}
    order = []
    for name, dims, t, off in tensors:
        n = 1
        for d in dims:
            n *= d
        start = data_offset + off
        if t == 30:
            raw = struct.unpack("<%dH" % n, data[start:start + 2 * n])
            vals = [bf16_decode(b) for b in raw]
        elif t == 0:
            vals = list(struct.unpack("<%df" % n, data[start:start + 4 * n]))
        else:
            raise ValueError("unexpected type %d" % t)
        out[name] = (dims, t, vals)
        order.append(name)
    return meta, out, order, nkv


def slow_merge(w, shape, a, b, scale):
    rows, cols = shape
    rank = len(a) // cols
    out = []
    for i in range(rows):
        for j in range(cols):
            acc = 0.0
            for k in range(rank):
                acc = f32(acc + f32(b[i * rank + k] * a[k * cols + j]))
            out.append(f32(w[i * cols + j] + f32(scale * acc)))
    return out


def main():
    workdir = sys.argv[1]
    base, base_order = read_safetensors(workdir + "/model.safetensors")
    adapter, _ = read_safetensors(workdir + "/adapter_model.safetensors")
    with open(workdir + "/adapter_config.json") as f:
        cfg = json.load(f)
    scale = f32(cfg["lora_alpha"] / cfg["r"])
    meta, gguf, order, nkv = read_gguf(workdir + "/merged.gguf")
    check(meta.get("arch") == "llama", "arch is llama")
    check(meta.get("alignment") == 32, "alignment is 32")
    check(meta.get("hidden") == 8, "hidden is 8")
    check(nkv == 19, "19 metadata entries")
    check(order == [GGUF_NAMES[n] for n in base_order], "census names/order agree")
    targets = {}
    for name in adapter:
        stem = name
        if stem.startswith("base_model.model."):
            stem = stem[len("base_model.model."):]
        if ".lora_A.default.weight" in stem:
            targets.setdefault(stem.replace(".lora_A.default.weight", ".weight"), {})["A"] = adapter[name]
        elif ".lora_B.default.weight" in stem:
            targets.setdefault(stem.replace(".lora_B.default.weight", ".weight"), {})["B"] = adapter[name]
    check(len(targets) == 2, "two adapter targets in fixtures")
    merged_diffs = 0
    merged_total = 0
    for hf_name in base_order:
        shape, wvals = base[hf_name]
        gname = GGUF_NAMES[hf_name]
        gdims, gtype, gvals = gguf[gname]
        if len(shape) == 2:
            check(gdims == [shape[1], shape[0]], "GGUF dims flipped for " + gname)
            check(gtype == 30, "2-D stored BF16: " + gname)
        else:
            check(gdims == shape, "1-D dims kept for " + gname)
            check(gtype == 0, "1-D stored F32: " + gname)
        if hf_name in targets:
            want = slow_merge(wvals, shape, targets[hf_name]["A"][1],
                              targets[hf_name]["B"][1], scale)
            for i in range(len(want)):
                merged_total += 1
                if gvals[i] != want[i]:
                    merged_diffs += 1
                if bf16_bits(want[i]) != bf16_bits(gvals[i]):
                    merged_diffs += 1
        else:
            for i in range(len(wvals)):
                if len(shape) == 2:
                    if gvals[i] != bf16_decode(bf16_bits(wvals[i])):
                        check(False, "pass-through BF16 value: " + gname)
                        break
                else:
                    if gvals[i] != wvals[i]:
                        check(False, "pass-through F32 value: " + gname)
                        break
            else:
                check(True, "pass-through values agree: " + gname)
    check(merged_diffs == 0,
          "merged == slow way EXACT (%d elements, 0 diffs)" % merged_total)
    print("merged elements verified:", merged_total)
    print("checks:", CHECKS, "fails:", len(FAILS))
    if FAILS:
        print("VERIFY: FAIL")
        sys.exit(1)
    print("VERIFY: ALL PASS (%d checks)" % CHECKS)


if __name__ == "__main__":
    main()
