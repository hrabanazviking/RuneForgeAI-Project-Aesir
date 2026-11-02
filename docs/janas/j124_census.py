#!/usr/bin/env python3
"""J-124 stage (b): GGUF header census, pure stdlib, header bytes only.

Reads a GGUF file's header, metadata KV pairs, and tensor directory
(name / dims as stored / ggml type / offset) WITHOUT reading tensor
data: the file is read sequentially only as far as the end of the
tensor directory, so the tool is safe to run against a 35 GB-class
file. Own implementation, sharing no code with the Aesir loader or
the J-122 harness. Output: one line per metadata entry and per
tensor, plus a summary (architecture, block/layer-kind counts when
the arch is qwen35moe, total tensors), and an MTP grade of the
directory under J-076's classifier rules (nextn / mtp / assistant
substrings, first match in that order -- the same rules
core/mtp_census.mojo states) with the per-file verdict
WITH_MTP / NO_MTP / VOCAB_ONLY. Exit 0 on a parseable header, 1
with the parse failure named otherwise.
Usage: j124_census.py <file.gguf>
"""
import struct, sys

GGML = {0:"F32",1:"F16",2:"Q4_0",3:"Q4_1",6:"Q5_0",7:"Q5_1",8:"Q8_0",9:"Q8_1",
        10:"Q2_K",11:"Q3_K",12:"Q4_K",13:"Q5_K",14:"Q6_K",16:"IQ2_XXS",
        17:"IQ2_XS",18:"IQ3_XXS",19:"IQ1_S",20:"IQ4_NL",21:"IQ3_S",
        22:"IQ2_S",23:"IQ4_XS",29:"IQ1_M",30:"BF16",34:"TQ1_0",35:"TQ2_0"}

class Reader:
    def __init__(self, f): self.f = f
    def take(self, n):
        b = self.f.read(n)
        if len(b) != n: raise ValueError("unexpected end of file in header")
        return b
    def u32(self): return struct.unpack("<I", self.take(4))[0]
    def u64(self): return struct.unpack("<Q", self.take(8))[0]
    def string(self):
        n = self.u64(); return self.take(n).decode("utf-8", "replace")
    def value(self, t):
        if t == 0: return struct.unpack("<B", self.take(1))[0]
        if t == 1: return struct.unpack("<b", self.take(1))[0]
        if t == 2: return struct.unpack("<H", self.take(2))[0]
        if t == 3: return struct.unpack("<h", self.take(2))[0]
        if t == 4: return self.u32()
        if t == 5: return struct.unpack("<i", self.take(4))[0]
        if t == 6: return struct.unpack("<f", self.take(4))[0]
        if t == 7: return struct.unpack("<B", self.take(1))[0] != 0
        if t == 8: return self.string()
        if t == 9:
            et = self.u32(); cnt = self.u64()
            if et == 8: return [self.string() for _ in range(cnt)]
            if cnt > 100000: raise ValueError("array too large for header census")
            return [self.value(et) for _ in range(cnt)]
        if t == 10: return self.u64()
        if t == 11: return struct.unpack("<q", self.take(8))[0]
        if t == 12: return struct.unpack("<d", self.take(8))[0]
        raise ValueError(f"unknown metadata value type {t}")

def head_kind(name):
    # J-076's rules, first match wins: nextn, then mtp, then assistant.
    n = name.lower()
    if "nextn" in n: return "nextn"
    if "mtp" in n: return "mtp"
    if "assistant" in n: return "assistant"
    return None

def main():
    if len(sys.argv) != 2:
        print("usage: j124_census.py <file.gguf>"); return 1
    try:
        with open(sys.argv[1], "rb") as fh:
            r = Reader(fh)
            if r.take(4) != b"GGUF": raise ValueError("not a GGUF file (magic)")
            version = r.u32(); nt = r.u64(); nkv = r.u64()
            print(f"GGUF version {version} tensors {nt} metadata {nkv}")
            meta = {}
            for _ in range(nkv):
                k = r.string(); t = r.u32(); v = r.value(t)
                meta[k] = v
                shown = v if not isinstance(v, list) else f"<array len {len(v)}>"
                print(f"META {k} = {shown}")
            tensors = []
            counts = {"nextn": 0, "mtp": 0, "assistant": 0}
            for _ in range(nt):
                name = r.string(); nd = r.u32()
                dims = [r.u64() for _ in range(nd)]
                tt = r.u32(); off = r.u64()
                tensors.append(name)
                kind = head_kind(name)
                if kind: counts[kind] += 1
                print(f"TENSOR {name} dims {dims} type {GGML.get(tt, tt)} offset {off}")
            arch = meta.get("general.architecture", "")
            print(f"SUMMARY arch {arch} tensors {len(tensors)}")
            if arch == "qwen35moe":
                blocks = meta.get("qwen35moe.block_count", 0)
                interval = meta.get("qwen35moe.full_attention_interval", 4) or 4
                attn = sum(1 for i in range(blocks) if (i + 1) % interval == 0)
                print(f"SUMMARY qwen35moe blocks {blocks} attention {attn} ssm {blocks - attn}")
            heads = counts["nextn"] + counts["mtp"] + counts["assistant"]
            if len(tensors) == 0: verdict = "VOCAB_ONLY"
            elif heads > 0: verdict = "WITH_MTP"
            else: verdict = "NO_MTP"
            print(f"SUMMARY mtp nextn {counts['nextn']} mtp {counts['mtp']} "
                  f"assistant {counts['assistant']} verdict {verdict}")
        return 0
    except (ValueError, struct.error, OSError) as e:
        print(f"REFUSED: header census failed: {e}"); return 1

if __name__ == "__main__":
    sys.exit(main())
