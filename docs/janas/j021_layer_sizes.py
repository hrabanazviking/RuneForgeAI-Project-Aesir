#!/usr/bin/env python3
"""J-021: directory-true dense layer sizes for a GGUF file.

Header/directory parse only -- reads no tensor data. Computes exactly
what core/dense_residency.mojo's dense_layer_bytes /
dense_always_resident_bytes compute from PackedGGUF: per-layer byte
sums over the dense GQA suffix list, and the always-resident sum
(token embedding + rope factors + final norm + untied output head,
each only where the directory carries it). The type table is the
J-015 parser's, as corrected and verified against gguf-py in J-015
(zero mismatches over 1,123 tensors); this script exists so the
Mojo-side accounting can be cross-checked by an independent reader.
"""
import json, struct, sys, os

TT = {0:("F32",1,4),1:("F16",1,2),2:("Q4_0",32,18),3:("Q4_1",32,20),
6:("Q5_0",32,22),7:("Q5_1",32,24),8:("Q8_0",32,34),9:("Q8_1",32,40),
10:("Q2_K",256,84),11:("Q3_K",256,110),12:("Q4_K",256,144),13:("Q5_K",256,176),
14:("Q6_K",256,210),15:("Q8_K",256,292),16:("IQ2_XXS",256,66),17:("IQ2_XS",256,74),
18:("IQ3_XXS",256,98),19:("IQ1_S",256,50),20:("IQ4_NL",32,18),21:("IQ3_S",256,110),
22:("IQ2_S",256,82),23:("IQ4_XS",256,136),24:("I8",1,1),25:("I16",1,2),
26:("I32",1,4),27:("I64",1,8),28:("F64",1,8),29:("IQ1_M",256,56),30:("BF16",1,2),
34:("TQ1_0",256,54),35:("TQ2_0",256,66),39:("MXFP4",32,17),40:("NVFP4",64,36),
41:("Q1_0",128,18)}

SUFFIXES = ["attn_norm.weight", "ffn_norm.weight", "attn_q.weight",
            "attn_k.weight", "attn_v.weight", "attn_output.weight",
            "ffn_gate.weight", "ffn_up.weight", "ffn_down.weight",
            "attn_q_norm.weight", "attn_k_norm.weight", "attn_q.bias",
            "attn_k.bias", "attn_v.bias"]
FRONT = ["token_embd.weight", "rope_freqs.weight"]
TAIL = ["output_norm.weight", "output.weight"]
ALWAYS = FRONT + TAIL


class R:
    def __init__(self, f): self.f = f
    def u8(self): return struct.unpack("<B", self.f.read(1))[0]
    def i8(self): return struct.unpack("<b", self.f.read(1))[0]
    def u16(self): return struct.unpack("<H", self.f.read(2))[0]
    def i16(self): return struct.unpack("<h", self.f.read(2))[0]
    def u32(self): return struct.unpack("<I", self.f.read(4))[0]
    def i32(self): return struct.unpack("<i", self.f.read(4))[0]
    def u64(self): return struct.unpack("<Q", self.f.read(8))[0]
    def i64(self): return struct.unpack("<q", self.f.read(8))[0]
    def f32(self): return struct.unpack("<f", self.f.read(4))[0]
    def f64(self): return struct.unpack("<d", self.f.read(8))[0]
    def s(self):
        n = self.u64(); return self.f.read(n).decode("utf-8", "replace")


def read_value(r, t):
    if t == 0: return r.u8()
    if t == 1: return r.i8()
    if t == 2: return r.u16()
    if t == 3: return r.i16()
    if t == 4: return r.u32()
    if t == 5: return r.i32()
    if t == 6: return r.f32()
    if t == 7: return bool(r.u8())
    if t == 8: return r.s()
    if t == 10: return r.u64()
    if t == 11: return r.i64()
    if t == 12: return r.f64()
    if t == 9:
        et = r.u32(); n = r.u64()
        if et == 8:
            for _ in range(n): r.s()
            return {"array_of": "string", "len": n}
        vals = [read_value(r, et) for _ in range(n)]
        return {"array_len": n, "values": vals if n <= 16 else vals[:16]}
    raise ValueError(f"bad meta type {t}")


def main():
    path = sys.argv[1]
    with open(path, "rb") as f:
        r = R(f)
        magic = f.read(4)
        assert magic == b"GGUF", magic
        version = r.u32(); n_tensors = r.u64(); n_kv = r.u64()
        meta = {}
        for _ in range(n_kv):
            k = r.s(); t = r.u32(); meta[k] = read_value(r, t)
        tensors = {}
        for _ in range(n_tensors):
            name = r.s(); nd = r.u32()
            dims = [r.u64() for _ in range(nd)]
            tt = r.u32(); off = r.u64()
            _tname, bs, tsz = TT[tt]
            elems = 1
            for d in dims: elems *= d
            tensors[name] = elems // bs * tsz
    block_count = None
    for k, v in meta.items():
        if k.endswith(".block_count"): block_count = v
    layers = []
    for layer in range(block_count):
        total = 0
        for suf in SUFFIXES:
            total += tensors.get(f"blk.{layer}.{suf}", 0)
        layers.append(total)
    always = sum(tensors.get(n, 0) for n in ALWAYS)
    out = {"file": os.path.basename(path), "file_bytes": os.path.getsize(path),
           "block_count": block_count, "layer_bytes": layers,
           "total_layer_bytes": sum(layers),
           "always_resident_bytes": always,
           "front_resident_bytes": sum(tensors.get(n, 0) for n in FRONT),
           "tail_resident_bytes": sum(tensors.get(n, 0) for n in TAIL),
           "token_embd_bytes": tensors.get("token_embd.weight", 0),
           "output_bytes": tensors.get("output.weight", 0),
           "output_norm_bytes": tensors.get("output_norm.weight", 0),
           "tensor_bytes_total": sum(tensors.values()),
           "front31_layer_bytes": sum(layers[:31]),
           "tail_layer_bytes": sum(layers[31:])}
    json.dump(out, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
