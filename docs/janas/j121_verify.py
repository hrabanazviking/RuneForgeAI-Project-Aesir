#!/usr/bin/env python3
"""J-121 file-level verifier (pure stdlib, independent).

Re-reads the MTP-carrying fixture checkpoint and the
converted GGUF with its own implementations of both
formats, and checks the J-121 protocol section 0.4
census-agreement rule in full, element for element:

  - the GGUF census (names, GGUF dims, types) is the
    expected conversion of the fixture census: mapped
    names for ordinary tensors, VERBATIM names for
    prediction-head tensors, in source order;
  - every element agrees after the storage rule
    (2-D: stored BF16 decodes to the round-to-nearest-
    even BF16 of the source value, computed here;
    1-D: F32 bit-exact) -- head tensors included,
    with no merging or re-derivation anywhere;
  - the labels: 21 metadata entries, aesir.mtp.
    head_count == 4, aesir.mtp.head_tensors == the
    four head names in census order;
  - the head census agrees as a census: per-kind
    counts (nextn/mtp/assistant, this script's own
    implementation of J-076's substring rules) over
    the source names equal those over the converted
    names, WITH_MTP on both sides;
  - block.gguf (the extracted MTP block) has exactly
    the head census, values agreeing with the source
    head tensors.

Usage: j121_verify.py <workdir>   (expects
model.safetensors, converted.gguf, block.gguf in
<workdir>). Exit 0 and a final ALL PASS line on
success.
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


def bf16_bits(x):
    bits = struct.unpack("<I", struct.pack("<f", x))[0]
    lsb = (bits >> 16) & 1
    rounded = (bits + 0x7FFF + lsb) & 0xFFFFFFFF
    return rounded >> 16


def bf16_decode(bits):
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def head_kind(name):
    """J-076's rules, this script's own implementation:
    first match in the order nextn, mtp, assistant."""
    if "nextn" in name:
        return "nextn"
    if "mtp" in name:
        return "mtp"
    if "assistant" in name:
        return "assistant"
    return "none"


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
        elif key == "aesir.mtp.head_count":
            meta["head_count"] = struct.unpack("<I", data[start:start + 4])[0]
        elif key == "aesir.mtp.head_tensors":
            et = struct.unpack("<I", data[start:start + 4])[0]
            assert et == 8, "head_tensors must be a string array"
            cnt = struct.unpack("<Q", data[start + 4:start + 12])[0]
            q = start + 12
            names = []
            for _ in range(cnt):
                s, q = read_str(q)
                names.append(s)
            meta["head_tensors"] = names
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


def census_counts(names):
    counts = {"nextn": 0, "mtp": 0, "assistant": 0}
    for n in names:
        k = head_kind(n)
        if k in counts:
            counts[k] += 1
    return counts


def values_agree(shape, wvals, gvals, gname):
    for i in range(len(wvals)):
        if len(shape) == 2:
            if gvals[i] != bf16_decode(bf16_bits(wvals[i])):
                check(False, "value agreement (BF16 rule): " + gname)
                return
        else:
            if gvals[i] != wvals[i]:
                check(False, "value agreement (F32 exact): " + gname)
                return
    check(True, "value agreement: " + gname)


def main():
    workdir = sys.argv[1]
    base, base_order = read_safetensors(workdir + "/model.safetensors")
    meta, gguf, order, nkv = read_gguf(workdir + "/converted.gguf")
    check(meta.get("arch") == "llama", "arch is llama")
    check(meta.get("alignment") == 32, "alignment is 32")
    check(meta.get("hidden") == 8, "hidden is 8")
    check(nkv == 21, "21 metadata entries")
    expected_order = [GGUF_NAMES.get(n, n) for n in base_order]
    check(order == expected_order, "census names/order agree (mapped + verbatim heads)")
    check(len(order) == len(base_order) == 16, "tensor counts agree (16 == 16)")
    head_names = [n for n in base_order if head_kind(n) != "none"]
    check(len(head_names) == 4, "source carries 4 head tensors")
    check(meta.get("head_count") == 4, "aesir.mtp.head_count == 4")
    check(meta.get("head_tensors") == head_names,
          "aesir.mtp.head_tensors == head names in census order")
    src_counts = census_counts(base_order)
    dst_counts = census_counts(order)
    check(src_counts == {"nextn": 2, "mtp": 1, "assistant": 1},
          "source head census nextn 2 / mtp 1 / assistant 1")
    check(dst_counts == src_counts, "converted head census == source head census")
    head_elements = 0
    total_elements = 0
    for hf_name in base_order:
        shape, wvals = base[hf_name]
        gname = GGUF_NAMES.get(hf_name, hf_name)
        gdims, gtype, gvals = gguf[gname]
        total_elements += len(wvals)
        if head_kind(hf_name) != "none":
            head_elements += len(wvals)
            check(gname == hf_name, "head name verbatim: " + hf_name)
        if len(shape) == 2:
            check(gdims == [shape[1], shape[0]], "GGUF dims flipped for " + gname)
            check(gtype == 30, "2-D stored BF16: " + gname)
        else:
            check(gdims == shape, "1-D dims kept for " + gname)
            check(gtype == 0, "1-D stored F32: " + gname)
        values_agree(shape, wvals, gvals, gname)
    # The extracted block: exactly the head census, values intact.
    bmeta, block, border, bnkv = read_gguf(workdir + "/block.gguf")
    check(border == head_names, "block census == head census (names + order)")
    check(bnkv == 21, "block file carries the label (21 metadata entries)")
    check(bmeta.get("head_tensors") == head_names, "block label names the heads")
    for hf_name in head_names:
        shape, wvals = base[hf_name]
        gdims, gtype, gvals = block[hf_name]
        values_agree(shape, wvals, gvals, "block " + hf_name)
    print("head elements verified:", head_elements)
    print("total elements verified:", total_elements)
    print("checks:", CHECKS, "fails:", len(FAILS))
    if FAILS:
        print("VERIFY: FAIL")
        sys.exit(1)
    print("VERIFY: ALL PASS (%d checks)" % CHECKS)


if __name__ == "__main__":
    main()
