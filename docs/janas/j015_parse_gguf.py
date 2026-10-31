#!/usr/bin/env python3
"""J-015 GGUF anatomy parser: header/metadata/tensor-directory only.
Reads no tensor data. Emits a JSON summary: routing metadata, tensor map,
expert vs resident byte split, offset layout / contiguity analysis.
GGUF dims are recorded as stored (ne order, fastest-varying first)."""
import json, struct, sys, os
from collections import defaultdict

TT = {0:("F32",1,4),1:("F16",1,2),2:("Q4_0",32,18),3:("Q4_1",32,20),
6:("Q5_0",32,22),7:("Q5_1",32,24),8:("Q8_0",32,34),9:("Q8_1",32,40),
10:("Q2_K",256,84),11:("Q3_K",256,110),12:("Q4_K",256,144),13:("Q5_K",256,176),
14:("Q6_K",256,210),15:("Q8_K",256,292),16:("IQ2_XXS",256,66),17:("IQ2_XS",256,74),
18:("IQ3_XXS",256,98),19:("IQ1_S",256,50),20:("IQ4_NL",32,18),21:("IQ3_S",256,110),
22:("IQ2_S",256,82),23:("IQ4_XS",256,136),24:("I8",1,1),25:("I16",1,2),
26:("I32",1,4),27:("I64",1,8),28:("F64",1,8),29:("IQ1_M",256,56),30:("BF16",1,2),
34:("TQ1_0",256,54),35:("TQ2_0",256,66),39:("MXFP4",32,17),40:("NVFP4",64,36),
41:("Q1_0",128,18)}
# TT corrected 2026-10-31 (J-015): ids 9,18-35,39-41 previously mis-keyed
# (e.g. id 20 was labelled I16; it is IQ4_NL, 18 B/block). Verified entry by
# entry against gguf-py's GGMLQuantizationType + GGML_QUANT_SIZES on
# purplelongship, and by reproducing gguf-py's n_bytes for all 606 tensors
# of the two J-015 witness files with zero mismatches.

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
        if et == 8:  # string array: count only, skip values
            for _ in range(n): r.s()
            return {"array_of": "string", "len": n}
        vals = [read_value(r, et) for _ in range(n)]
        return {"array_len": n, "values": vals if n <= 16 else vals[:16]}
    raise ValueError(f"bad meta type {t}")

def parse(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        r = R(f)
        magic = f.read(4)
        assert magic == b"GGUF", magic
        version = r.u32(); n_tensors = r.u64(); n_kv = r.u64()
        meta = {}
        for _ in range(n_kv):
            k = r.s(); t = r.u32(); meta[k] = read_value(r, t)
        tensors = []
        for _ in range(n_tensors):
            name = r.s(); nd = r.u32()
            dims = [r.u64() for _ in range(nd)]
            tt = r.u32(); off = r.u64()
            tname, bs, tsz = TT[tt]
            elems = 1
            for d in dims: elems *= d
            nbytes = elems // bs * tsz
            tensors.append({"name": name, "dims_ne": dims, "type": tname,
                            "elems": elems, "bytes": nbytes, "rel_offset": off})
        hdr_end = f.tell()
    align = meta.get("general.alignment", 32)
    data_start = (hdr_end + align - 1) // align * align
    for t in tensors: t["abs_offset"] = data_start + t["rel_offset"]
    return meta, tensors, {"version": version, "n_tensors": n_tensors,
           "n_kv": n_kv, "header_end": hdr_end, "data_start": data_start,
           "alignment": align, "file_bytes": size}

def layer_of(name):
    if name.startswith("blk."):
        try: return int(name.split(".")[1])
        except Exception: return None
    return None

def analyse(meta, tensors, hdr):
    arch = meta.get("general.architecture", "?")
    pfx = arch + "."
    total_tensor = sum(t["bytes"] for t in tensors)
    def is_routed_exp(t):
        n = t["name"]
        return ("_exps." in n) or (".ffn_gate." in n and n.split(".ffn_gate.")[1][0].isdigit()) or \
               (".ffn_up." in n and n.split(".ffn_up.")[1][0].isdigit()) or \
               (".ffn_down." in n and n.split(".ffn_down.")[1][0].isdigit())
    routed = [t for t in tensors if "_exps" in t["name"] or is_routed_exp(t)]
    fused = [t for t in tensors if "_exps" in t["name"]]
    perexp = [t for t in tensors if is_routed_exp(t) and "_exps" not in t["name"]]
    shexp = [t for t in tensors if "shexp" in t["name"]]
    router = [t for t in tensors if "ffn_gate_inp" in t["name"]]
    routed_ids = {id(t) for t in routed}
    resident = [t for t in tensors if id(t) not in routed_ids]
    exp_bytes = sum(t["bytes"] for t in routed)
    res_bytes = sum(t["bytes"] for t in resident)
    # per-layer expert bytes + contiguity
    by_layer = defaultdict(list)
    for t in routed: by_layer[layer_of(t["name"])].append(t)
    layer_info = {}
    for L, ts in sorted(by_layer.items(), key=lambda kv: (kv[0] is None, kv[0])):
        ts2 = sorted(ts, key=lambda x: x["abs_offset"])
        span = ts2[-1]["abs_offset"] + ts2[-1]["bytes"] - ts2[0]["abs_offset"]
        own = sum(x["bytes"] for x in ts2)
        layer_info[L] = {"tensors": [x["name"] for x in ts2], "bytes": own,
                         "span": span, "contiguous": span == own,
                         "first_off": ts2[0]["abs_offset"], "last_end": ts2[-1]["abs_offset"] + ts2[-1]["bytes"]}
    # global offset order: are tensors stored in directory order?
    offs = [t["abs_offset"] for t in tensors]
    dir_order_sorted = offs == sorted(offs)
    # gaps between consecutive tensors in file order
    st = sorted(tensors, key=lambda x: x["abs_offset"])
    gaps = []
    for a, b in zip(st, st[1:]):
        gaps.append(b["abs_offset"] - (a["abs_offset"] + a["bytes"]))
    # expert tensor stride pattern (same kind across layers)
    kinds = defaultdict(list)
    for t in fused:
        key = t["name"].split(".", 2)[-1] if t["name"].startswith("blk.") else t["name"]
        kinds[key.rsplit(".", 1)[0] if False else t["name"][t["name"].index(".")+1:]].append(t)
    ec = meta.get(pfx + "expert_count"); topk = meta.get(pfx + "expert_used_count")
    per_exp = {}
    for t in fused:
        kind = [k for k in ("ffn_gate_exps", "ffn_up_exps", "ffn_down_exps", "ffn_gate_up_exps") if k in t["name"]]
        if kind and ec:
            per_exp.setdefault(kind[0], t["bytes"] // ec)
    per_exp_layer_token = None
    if per_exp and topk:
        per_exp_layer_token = sum(per_exp.values()) * topk
    n_layers = meta.get(pfx + "block_count")
    cats = {"token_embd": 0, "output": 0, "attn": 0, "norm": 0, "ffn_resident_incl_shared": 0, "router": 0, "other": 0}
    for t in resident:
        n = t["name"]
        if n.startswith("token_embd"): cats["token_embd"] += t["bytes"]
        elif n.startswith("output"): cats["output"] += t["bytes"]
        elif ".attn_" in n: cats["attn"] += t["bytes"]
        elif "norm" in n: cats["norm"] += t["bytes"]
        elif "ffn_gate_inp" in n: cats["router"] += t["bytes"]
        elif ".ffn_" in n: cats["ffn_resident_incl_shared"] += t["bytes"]
        else: cats["other"] += t["bytes"]
    type_hist = defaultdict(int)
    for t in tensors: type_hist[t["type"]] += t["bytes"]
    return {
        "total_tensor_bytes": total_tensor,
        "routed_expert_tensors": len(routed), "fused_exps_tensors": len(fused),
        "per_expert_tensors": len(perexp), "shared_expert_tensors": len(shexp),
        "router_tensors": len(router),
        "expert_bytes": exp_bytes, "resident_bytes": res_bytes,
        "expert_frac_of_tensor_bytes": exp_bytes / total_tensor if total_tensor else None,
        "expert_frac_of_file": exp_bytes / hdr["file_bytes"],
        "resident_categories": cats,
        "shared_expert_bytes": sum(t["bytes"] for t in shexp),
        "router_bytes": sum(t["bytes"] for t in router),
        "per_expert_bytes_by_kind": per_exp,
        "per_token_expert_bytes_one_layer": per_exp_layer_token,
        "per_token_expert_bytes_all_layers": (per_exp_layer_token * n_layers) if per_exp_layer_token and n_layers else None,
        # Exact per-token routed bytes: valid even when layers are NOT uniform
        # (mixed-quant recipes up-quantize some layers' down_exps, e.g. the
        # Q4_K_M OLMoE/Granite files of J-015, where the uniform-layer figure
        # above overstates). topk/expert_count x total routed expert bytes.
        "per_token_expert_bytes_all_layers_exact": (exp_bytes * topk // ec) if (ec and topk and exp_bytes * topk % ec == 0) else None,
        "layers": {str(k): v for k, v in layer_info.items()},
        "dir_order_is_offset_order": dir_order_sorted,
        "gap_min": min(gaps) if gaps else None, "gap_max": max(gaps) if gaps else None,
        "gap_nonzero_count": sum(1 for g in gaps if g != 0),
        "tensor_type_bytes": dict(type_hist),
        "sample_expert_tensors": fused[:6], "sample_resident": resident[:8],
        "all_tensor_names_count": len(tensors),
    }

if __name__ == "__main__":
    out = {}
    for path in sys.argv[1:]:
        meta, tensors, hdr = parse(path)
        routing_keys = {k: v for k, v in meta.items()
                        if any(s in k for s in ("expert", "architecture", "block_count",
                        "embedding_length", "context_length", "feed_forward", "file_type",
                        "quantization", "head_count", "name")) and not isinstance(v, dict)}
        out[path] = {"header": hdr, "routing_meta": routing_keys,
                     "all_meta_keys": sorted(meta.keys()),
                     "analysis": analyse(meta, tensors, hdr),
                     "tensors": tensors}
    json.dump(out, sys.stdout, indent=1, default=str)
