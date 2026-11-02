#!/usr/bin/env python3
"""J-122 conversion verification harness (pure stdlib, independent).

The per-file census form C09 hands to J-122 (J-119 doc
section 3): every conversion this road performs is
filed through this harness as a (source, converted)
pair and gets

  (a) a tensor census diff -- names, shapes, types,
      counts, source vs converted, every difference
      named and classified exactly one of
        merged / pass-through / labelled-head /
        carried-verbatim / REFUSED-by-name
      (protocol section 0.2), plus the fatal
      difference classes missing-in-converted,
      extra-in-converted, shape-mismatch,
      type-mismatch, value-mismatch, label-mismatch;
  (b) a grade -- for the synthetic pairs this road
      has produced, element-exact agreement (the
      synthetic pair's grade, stated as such; merged
      tensors graded against the slow-way merge
      recomputed here). The live teacher-forcing leg
      for real files is defined in the J-122 protocol
      section 0.3(b), is DEFERRED-WITH-REASON there,
      and is recorded in every pair record as such --
      this harness never invents a grade.

Modes (protocol section 0.1):
  hf-gguf             HF safetensors -> GGUF
                      (optional --adapter +
                      --adapter-config for a merge)
  gguf-gguf           GGUF -> GGUF (C10 re-emission)
  hf-gguf-subset-head HF safetensors -> block-only
                      GGUF (expected census == the
                      source's head subset, in order)

Usage:
  j122_harness.py <mode> --source <path>
      [--adapter <path> --adapter-config <path>]
      --converted <path> --out <record.json>

Exit 0 iff the verdict is PASS. FAIL and REFUSED
exit 1 and name every reason, on stdout and in the
record. This file shares no code with the converter
or with j120_verify.py / j121_verify.py; the format
readers, the name mapping, the head rules and the
slow-way merge are independent implementations of
the same stated rules.
"""
import argparse
import hashlib
import json
import os
import re
import struct
import sys

GGML_TYPE_NAMES = {
    0: "F32", 1: "F16", 2: "Q4_0", 3: "Q4_1", 6: "Q5_0",
    7: "Q5_1", 8: "Q8_0", 9: "Q8_1", 10: "Q2_K", 11: "Q3_K",
    12: "Q4_K", 13: "Q5_K", 14: "Q6_K", 30: "BF16",
}
PLAIN_TYPES = (0, 1, 30)  # F32, F16, BF16 -- everything else is refused by name (C05)


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


def bf16_bits(x):
    bits = struct.unpack("<I", struct.pack("<f", x))[0]
    lsb = (bits >> 16) & 1
    return ((bits + 0x7FFF + lsb) & 0xFFFFFFFF) >> 16


def bf16_decode(bits):
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def head_kind(name):
    """J-076's rules, this harness's own implementation:
    first match in the order nextn, mtp, assistant."""
    if "nextn" in name:
        return "nextn"
    if "mtp" in name:
        return "mtp"
    if "assistant" in name:
        return "assistant"
    return "none"


_LAYER_RE = re.compile(
    r"^model\.layers\.(\d+)\.(.+)\.weight$")
_LAYER_MAP = {
    "input_layernorm": "attn_norm",
    "self_attn.q_proj": "attn_q",
    "self_attn.k_proj": "attn_k",
    "self_attn.v_proj": "attn_v",
    "self_attn.o_proj": "attn_output",
    "post_attention_layernorm": "ffn_norm",
    "mlp.gate_proj": "ffn_gate",
    "mlp.up_proj": "ffn_up",
    "mlp.down_proj": "ffn_down",
}
_EXACT_MAP = {
    "model.embed_tokens.weight": "token_embd.weight",
    "lm_head.weight": "output.weight",
    "model.norm.weight": "output_norm.weight",
}


def gguf_name(hf_name):
    """J-120 section 0.4's mapping, implemented here
    independently. None if the name has no mapping."""
    if hf_name in _EXACT_MAP:
        return _EXACT_MAP[hf_name]
    m = _LAYER_RE.match(hf_name)
    if m and m.group(2) in _LAYER_MAP:
        return "blk.%s.%s.weight" % (m.group(1), _LAYER_MAP[m.group(2)])
    return None


# ---------------------------------------------------------------- formats

def read_safetensors(path):
    """Returns (tensors, order): tensors[name] =
    {shape, dtype, values (Float32 list)}."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 8:
        raise ValueError("safetensors too short: " + path)
    hlen = struct.unpack("<Q", data[:8])[0]
    header = json.loads(data[8:8 + hlen].decode("utf-8"))
    base = 8 + hlen
    out, order = {}, []
    for name, meta in header.items():
        if name == "__metadata__":
            continue
        b, e = meta["data_offsets"]
        raw = data[base + b: base + e]
        shape = list(meta["shape"])
        n = 1
        for d in shape:
            n *= d
        dt = meta["dtype"]
        if dt == "F32":
            vals = list(struct.unpack("<%df" % n, raw))
        elif dt == "F16":
            vals = [f32(v) for v in struct.unpack("<%de" % n, raw)]
        elif dt == "BF16":
            vals = [bf16_decode(v) for v in struct.unpack("<%dH" % n, raw)]
        else:
            raise ValueError("unsupported safetensors dtype %s for %s" % (dt, name))
        out[name] = {"shape": shape, "dtype": dt, "values": vals}
        order.append(name)
    return out, order


def read_gguf(path):
    """Returns (meta, tensors, order, nkv): meta is the
    full metadata dict (values as Python values);
    tensors[name] = {dims, type, values, raw}."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 24:
        raise ValueError("GGUF too short: " + path)
    magic, version, nt, nkv = struct.unpack("<IIQQ", data[:24])
    if magic != 0x46554747 or version != 3:
        raise ValueError("not a GGUF v3 file: " + path)
    pos = 24

    def read_str(p):
        n = struct.unpack("<Q", data[p:p + 8])[0]
        return data[p + 8:p + 8 + n].decode("utf-8"), p + 8 + n

    def read_val(p, t):
        if t == 0:
            return data[p], p + 1
        if t == 1:
            return struct.unpack("<b", data[p:p + 1])[0], p + 1
        if t == 2:
            return struct.unpack("<H", data[p:p + 2])[0], p + 2
        if t == 3:
            return struct.unpack("<h", data[p:p + 2])[0], p + 2
        if t == 4:
            return struct.unpack("<I", data[p:p + 4])[0], p + 4
        if t == 5:
            return struct.unpack("<i", data[p:p + 4])[0], p + 4
        if t == 6:
            return struct.unpack("<f", data[p:p + 4])[0], p + 4
        if t == 7:
            return data[p] != 0, p + 1
        if t == 8:
            return read_str(p)
        if t == 9:
            et = struct.unpack("<I", data[p:p + 4])[0]
            cnt = struct.unpack("<Q", data[p + 4:p + 12])[0]
            q = p + 12
            vals = []
            for _ in range(cnt):
                v, q = read_val(q, et)
                vals.append(v)
            return vals, q
        if t == 10:
            return struct.unpack("<Q", data[p:p + 8])[0], p + 8
        if t == 11:
            return struct.unpack("<q", data[p:p + 8])[0], p + 8
        if t == 12:
            return struct.unpack("<d", data[p:p + 8])[0], p + 8
        raise ValueError("bad metadata type %d" % t)

    meta = {}
    for _ in range(nkv):
        key, pos = read_str(pos)
        t = struct.unpack("<I", data[pos:pos + 4])[0]
        pos += 4
        meta[key], pos = read_val(pos, t)
    entries = []
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
        entries.append((name, dims, t, off))
    alignment = meta.get("general.alignment", 32)
    data_offset = (pos + alignment - 1) // alignment * alignment
    out, order = {}, []
    for name, dims, t, off in entries:
        n = 1
        for d in dims:
            n *= d
        start = data_offset + off
        if t == 0:
            raw = data[start:start + 4 * n]
            vals = list(struct.unpack("<%df" % n, raw))
        elif t == 1:
            raw = data[start:start + 2 * n]
            vals = [f32(v) for v in struct.unpack("<%de" % n, raw)]
        elif t == 30:
            raw = data[start:start + 2 * n]
            vals = [bf16_decode(v) for v in struct.unpack("<%dH" % n, raw)]
        else:
            raw = b""
            vals = []
        out[name] = {"dims": dims, "type": t, "values": vals, "raw": raw}
        order.append(name)
    return meta, out, order, nkv


def sha256_of(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def adapter_targets(adapter, adapter_order):
    """stem (base HF name) -> {A: tensor, B: tensor},
    per J-120 section 0.2's PEFT naming."""
    targets = {}
    for name in adapter_order:
        stem = name
        if stem.startswith("base_model.model."):
            stem = stem[len("base_model.model."):]
        for marker, half in ((".lora_A.default.weight", "A"),
                             (".lora_B.default.weight", "B"),
                             (".lora_A.weight", "A"),
                             (".lora_B.weight", "B")):
            if marker in stem:
                base_name = stem.replace(marker, ".weight")
                targets.setdefault(base_name, {})[half] = adapter[name]
                break
    return targets


def slow_merge(w, shape, a, b, scale):
    """J-120 section 0.3's merge, computed the slow
    way with Float32 rounding at every step."""
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


# ---------------------------------------------------------------- grading

class Pair:
    def __init__(self, mode):
        self.mode = mode
        self.diff = []        # one entry per source/converted tensor
        self.failures = []    # fatal difference entries (strings)
        self.refusals = []    # REFUSED-by-name entries (strings)
        self.total = 0
        self.differing = 0
        self.max_abs = 0.0
        self.class_counts = {}

    def classify(self, entry):
        self.diff.append(entry)
        self.class_counts[entry["class"]] = \
            self.class_counts.get(entry["class"], 0) + 1

    def compare_values(self, entry, expected, got):
        """expected/got are Float32 value lists under
        the storage rule already applied to expected
        (BF16-rounded for 2-D, exact for 1-D) -- the
        caller passes both in decoded form and, for
        2-D, compares by BF16 bits via `bits` flag."""
        n = len(expected)
        self.total += n
        diffs = 0
        first = -1
        for i in range(n):
            e, g = expected[i], got[i]
            if e != g:
                diffs += 1
                if first < 0:
                    first = i
                d = abs(e - g)
                if d > self.max_abs:
                    self.max_abs = d
        entry["elements"] = n
        entry["differing_elements"] = diffs
        if diffs:
            self.differing += diffs
            self.failures.append(
                "value-mismatch: %s (%d differing elements, first at index %d)"
                % (entry["converted_name"], diffs, first))
            entry["difference"] = "value-mismatch"


def expected_stored(src_vals, shape):
    """The storage rule (J-120 section 0.4): 2-D ->
    BF16 round-to-nearest-even, 1-D -> F32 exact;
    returned in decoded Float32 form."""
    if len(shape) == 2:
        return [bf16_decode(bf16_bits(v)) for v in src_vals]
    return list(src_vals)


def grade_hf_pair(pair, src, src_order, converted, conv, conv_order,
                  meta, targets, scale, subset_head):
    expected = []  # (src_name, conv_name, cls)
    for name in src_order:
        kind = head_kind(name)
        if subset_head and kind == "none":
            continue
        if name in targets:
            expected.append((name, gguf_name(name), "merged"))
        elif kind != "none":
            expected.append((name, name, "labelled-head"))
        elif gguf_name(name) is not None:
            expected.append((name, gguf_name(name), "pass-through"))
        else:
            pair.classify({
                "source_name": name, "converted_name": None,
                "class": "REFUSED-by-name",
                "difference": "refused-by-name: no GGUF name mapping "
                              "and no head classification"})
            pair.refusals.append(
                "REFUSED-by-name: %s (no GGUF name mapping, no head "
                "classification; absent from converted census -- a "
                "silent drop this harness refuses to file as a pair)" % name)
    exp_names = [c for _, c, _ in expected if c]
    if conv_order != exp_names:
        pair.failures.append(
            "census-order-mismatch: converted census order != source "
            "order transformed (%s vs %s)" % (conv_order, exp_names))
    exp_set = set(exp_names)
    for name in conv_order:
        if name not in exp_set:
            ct = conv[name]["type"]
            if ct not in PLAIN_TYPES:
                pair.classify({
                    "source_name": None, "converted_name": name,
                    "class": "REFUSED-by-name",
                    "difference": "refused-by-name: quantized/unsupported "
                                  "ggml type %s (C05 BF16-only scope)"
                                  % GGML_TYPE_NAMES.get(ct, str(ct))})
                pair.refusals.append(
                    "REFUSED-by-name: converted tensor %s has ggml type "
                    "%s (C05 BF16-only scope)" % (name, GGML_TYPE_NAMES.get(ct, ct)))
            else:
                pair.classify({
                    "source_name": None, "converted_name": name,
                    "class": "extra-in-converted",
                    "difference": "extra-in-converted"})
                pair.failures.append("extra-in-converted: " + name)
    for src_name, conv_name, cls in expected:
        entry = {"source_name": src_name, "converted_name": conv_name,
                 "class": cls}
        s = src[src_name]
        entry["source_shape"] = s["shape"]
        entry["source_type"] = s["dtype"]
        if conv_name not in conv:
            entry["difference"] = "missing-in-converted"
            pair.failures.append("missing-in-converted: %s (source %s)"
                                 % (conv_name, src_name))
            pair.classify(entry)
            continue
        c = conv[conv_name]
        entry["converted_shape"] = c["dims"]
        entry["converted_type"] = GGML_TYPE_NAMES.get(c["type"], str(c["type"]))
        want_dims = [s["shape"][1], s["shape"][0]] if len(s["shape"]) == 2 \
            else list(s["shape"])
        if c["dims"] != want_dims:
            entry["difference"] = "shape-mismatch"
            pair.failures.append("shape-mismatch: %s (converted %s vs "
                                 "expected %s)" % (conv_name, c["dims"], want_dims))
        want_type = 30 if len(s["shape"]) == 2 else 0
        if c["type"] != want_type:
            entry["difference"] = "type-mismatch"
            pair.failures.append("type-mismatch: %s (converted %s vs "
                                 "expected %s)" % (conv_name, entry["converted_type"],
                                                    GGML_TYPE_NAMES[want_type]))
        if cls == "merged":
            t = targets[src_name]
            want = slow_merge(s["values"], s["shape"],
                              t["A"]["values"], t["B"]["values"], scale)
            want = expected_stored(want, s["shape"])
        else:
            want = expected_stored(s["values"], s["shape"])
        if c["dims"] == want_dims and c["type"] in PLAIN_TYPES:
            pair.compare_values(entry, want, c["values"])
        pair.classify(entry)
    # The label agreement (J-121 section 0.3's dual label).
    census_heads = [n for n in conv_order if head_kind(n) != "none"]
    label = meta.get("aesir.mtp.head_tensors")
    count = meta.get("aesir.mtp.head_count")
    if census_heads:
        if label != census_heads or count != len(census_heads):
            pair.failures.append(
                "label-mismatch: census heads %s vs metadata "
                "aesir.mtp.head_tensors %s (head_count %s)"
                % (census_heads, label, count))
            for e in pair.diff:
                if e.get("converted_name") in census_heads:
                    e["difference"] = "label-mismatch"
    elif label is not None or count is not None:
        pair.failures.append(
            "label-mismatch: metadata carries aesir.mtp.* labels but "
            "the census carries no head tensor")


def grade_gguf_pair(pair, src, src_order, conv, conv_order, meta):
    if conv_order != src_order:
        pair.failures.append(
            "census-order-mismatch: converted census order != source "
            "order (%s vs %s)" % (conv_order, src_order))
    src_set = set(src_order)
    for name in conv_order:
        if name not in src_set:
            pair.classify({"source_name": None, "converted_name": name,
                           "class": "extra-in-converted",
                           "difference": "extra-in-converted"})
            pair.failures.append("extra-in-converted: " + name)
    census_heads = [n for n in conv_order if head_kind(n) != "none"]
    label = meta.get("aesir.mtp.head_tensors")
    count = meta.get("aesir.mtp.head_count")
    label_ok = True
    if census_heads:
        if label != census_heads or count != len(census_heads):
            label_ok = False
            pair.failures.append(
                "label-mismatch: census heads %s vs metadata "
                "aesir.mtp.head_tensors %s (head_count %s)"
                % (census_heads, label, count))
    for name in src_order:
        s = src[name]
        kind = head_kind(name)
        cls = "labelled-head" if kind != "none" else "carried-verbatim"
        entry = {"source_name": name, "converted_name": name, "class": cls,
                 "source_shape": s["dims"],
                 "source_type": GGML_TYPE_NAMES.get(s["type"], str(s["type"]))}
        if s["type"] not in PLAIN_TYPES:
            entry["class"] = "REFUSED-by-name"
            entry["difference"] = "refused-by-name: quantized/unsupported type"
            pair.refusals.append(
                "REFUSED-by-name: source tensor %s has ggml type %s"
                % (name, GGML_TYPE_NAMES.get(s["type"], s["type"])))
            pair.classify(entry)
            continue
        if name not in conv:
            entry["difference"] = "missing-in-converted"
            pair.failures.append("missing-in-converted: " + name)
            pair.classify(entry)
            continue
        c = conv[name]
        entry["converted_shape"] = c["dims"]
        entry["converted_type"] = GGML_TYPE_NAMES.get(c["type"], str(c["type"]))
        if c["dims"] != s["dims"]:
            entry["difference"] = "shape-mismatch"
            pair.failures.append("shape-mismatch: " + name)
        if c["type"] != s["type"]:
            entry["difference"] = "type-mismatch"
            pair.failures.append("type-mismatch: " + name)
        if c["dims"] == s["dims"] and c["type"] == s["type"]:
            # Bit-exact as stored: compare raw units.
            unit = 2 if s["type"] in (1, 30) else 4
            n = len(s["raw"]) // unit
            pair.total += n
            diffs = 0
            first = -1
            maxd = 0.0
            for i in range(n):
                if s["raw"][i * unit:(i + 1) * unit] != \
                        c["raw"][i * unit:(i + 1) * unit]:
                    diffs += 1
                    if first < 0:
                        first = i
                    d = abs(s["values"][i] - c["values"][i])
                    if d > maxd:
                        maxd = d
            entry["elements"] = n
            entry["differing_elements"] = diffs
            if diffs:
                pair.differing += diffs
                if maxd > pair.max_abs:
                    pair.max_abs = maxd
                entry["difference"] = "value-mismatch"
                pair.failures.append(
                    "value-mismatch: %s (%d differing elements, first "
                    "at index %d)" % (name, diffs, first))
        if kind != "none" and not label_ok:
            entry["difference"] = "label-mismatch"
        pair.classify(entry)


# ---------------------------------------------------------------- main

LIVE_LEG = {
    "status": "DEFERRED-WITH-REASON",
    "definition": "teacher-forcing rank + logit gap on the raw prompt, "
                  "CPU engine vs CPU comparator only, near-tie band "
                  "rank <=2 with sub-logit gap = faithful; never "
                  "llama-cli --single-turn (J-122 protocol 0.3(b))",
    "reason": "VM below the 5,500 MB inference gate; purplelongship "
              "yielded to the 204 road's live S-104; the only converted "
              "files in existence are the synthetic J-120/J-121 toys",
    "recited_to": ["J-128", "J-136"],
}


def census_of(order, get):
    return [{"name": n, "shape": get(n)[0], "type": get(n)[1],
             "elements": get(n)[2]} for n in order]


def run(args):
    pair = Pair(args.mode)
    record = {"mode": args.mode, "harness": "j122_harness.py (J-122)"}
    try:
        if args.mode in ("hf-gguf", "hf-gguf-subset-head"):
            src, src_order = read_safetensors(args.source)
            record["source"] = {
                "file": os.path.basename(args.source),
                "sha256": sha256_of(args.source),
                "bytes": os.path.getsize(args.source),
                "census": census_of(src_order, lambda n: (
                    src[n]["shape"], src[n]["dtype"],
                    len(src[n]["values"])))}
            targets, scale = {}, None
            if args.adapter:
                adapter, a_order = read_safetensors(args.adapter)
                cfg = json.load(open(args.adapter_config))
                scale = f32(cfg["lora_alpha"] / cfg["r"])
                targets = adapter_targets(adapter, a_order)
                record["adapter"] = {
                    "file": os.path.basename(args.adapter),
                    "sha256": sha256_of(args.adapter),
                    "targets": sorted(targets.keys()),
                    "rank": cfg["r"], "lora_alpha": cfg["lora_alpha"]}
            meta, conv, conv_order, nkv = read_gguf(args.converted)
            grade_hf_pair(pair, src, src_order, None, conv, conv_order,
                          meta, targets, scale,
                          args.mode == "hf-gguf-subset-head")
        else:
            smeta, src, src_order, _ = read_gguf(args.source)
            record["source"] = {
                "file": os.path.basename(args.source),
                "sha256": sha256_of(args.source),
                "bytes": os.path.getsize(args.source),
                "census": census_of(src_order, lambda n: (
                    src[n]["dims"],
                    GGML_TYPE_NAMES.get(src[n]["type"], str(src[n]["type"])),
                    len(src[n]["values"])))}
            meta, conv, conv_order, nkv = read_gguf(args.converted)
            grade_gguf_pair(pair, src, src_order, conv, conv_order, meta)
    except Exception as e:  # a pair that cannot be parsed is REFUSED by name
        record["verdict"] = "REFUSED"
        record["reasons"] = ["REFUSED-by-name: unparsable pair: %s" % e]
        record["live_teacher_forcing"] = LIVE_LEG
        with open(args.out, "w") as f:
            json.dump(record, f, indent=1, sort_keys=True)
            f.write("\n")
        print("VERDICT REFUSED -- REFUSED-by-name: unparsable pair: %s" % e)
        return 1
    record["converted"] = {
        "file": os.path.basename(args.converted),
        "sha256": sha256_of(args.converted),
        "bytes": os.path.getsize(args.converted),
        "metadata_count": nkv,
        "head_label": meta.get("aesir.mtp.head_tensors"),
        "head_count": meta.get("aesir.mtp.head_count"),
        "census": census_of(conv_order, lambda n: (
            conv[n]["dims"],
            GGML_TYPE_NAMES.get(conv[n]["type"], str(conv[n]["type"])),
            len(conv[n]["values"])))}
    record["census_diff"] = pair.diff
    record["class_counts"] = pair.class_counts
    record["grade"] = {
        "kind": "element-exact (synthetic pair grade)",
        "total_elements": pair.total,
        "differing_elements": pair.differing,
        "max_abs_diff": pair.max_abs,
    }
    record["live_teacher_forcing"] = LIVE_LEG
    if pair.refusals:
        record["verdict"] = "REFUSED"
        record["reasons"] = pair.refusals + pair.failures
    elif pair.failures:
        record["verdict"] = "FAIL"
        record["reasons"] = pair.failures
    else:
        record["verdict"] = "PASS"
        record["reasons"] = []
    with open(args.out, "w") as f:
        json.dump(record, f, indent=1, sort_keys=True)
        f.write("\n")
    print("VERDICT %s -- classes %s, grade %d elements / %d differing / "
          "max_abs_diff %s" % (record["verdict"], pair.class_counts,
                               pair.total, pair.differing, pair.max_abs))
    for r in record["reasons"]:
        print("REASON:", r)
    return 0 if record["verdict"] == "PASS" else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["hf-gguf", "gguf-gguf",
                                     "hf-gguf-subset-head"])
    ap.add_argument("--source", required=True)
    ap.add_argument("--adapter")
    ap.add_argument("--adapter-config")
    ap.add_argument("--converted", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    if args.adapter and not args.adapter_config:
        ap.error("--adapter requires --adapter-config")
    sys.exit(run(args))


if __name__ == "__main__":
    main()
