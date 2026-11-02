#!/usr/bin/env python3
"""J-074 tokenizer-identity probe: reads ONLY the GGUF metadata
(tokenizer section + architecture) of two files and compares them
token-for-token. No tensor data is read. Identity means, exactly:
same tokenizer model string, same vocab length, every token string
equal at every index, same merges length and every merge equal at
every index (where both files carry merges), and equal BOS/EOS ids
(where both carry them). Anything less is a mismatch with the first
divergence named. A file's tokenizer fingerprint is the sha256 of
the canonical serialization: model string, then each token as
<utf8-len>:<bytes>, then each merge likewise, then bos/eos.
Run: j074_tokenizer_probe.py FILE_A FILE_B  -> JSON verdict.
     j074_tokenizer_probe.py --fingerprint FILE -> JSON fingerprint.
"""
import hashlib, json, struct, sys


class R:
    def __init__(self, f):
        self.f = f

    def u32(self):
        return struct.unpack("<I", self.f.read(4))[0]

    def u64(self):
        return struct.unpack("<Q", self.f.read(8))[0]

    def s(self):
        n = self.u64()
        return self.f.read(n)


def read_meta(path):
    with open(path, "rb") as f:
        r = R(f)
        assert f.read(4) == b"GGUF"
        r.u32()  # version
        r.u64()  # n_tensors
        n_kv = r.u64()
        meta = {}
        for _ in range(n_kv):
            key = r.s().decode("utf-8", "replace")
            t = r.u32()
            meta[key] = read_value(r, t)
        return meta


def read_value(r, t):
    if t == 0:
        return struct.unpack("<B", r.f.read(1))[0]
    if t == 1:
        return struct.unpack("<b", r.f.read(1))[0]
    if t == 2:
        return struct.unpack("<H", r.f.read(2))[0]
    if t == 3:
        return struct.unpack("<h", r.f.read(2))[0]
    if t == 4:
        return r.u32()
    if t == 5:
        return struct.unpack("<i", r.f.read(4))[0]
    if t == 6:
        return struct.unpack("<f", r.f.read(4))[0]
    if t == 7:
        return bool(struct.unpack("<B", r.f.read(1))[0])
    if t == 8:
        return r.s()
    if t == 10:
        return r.u64()
    if t == 11:
        return struct.unpack("<q", r.f.read(8))[0]
    if t == 12:
        return struct.unpack("<d", r.f.read(8))[0]
    if t == 9:
        et = r.u32()
        n = r.u64()
        return [read_value(r, et) for _ in range(n)]
    raise ValueError(f"bad meta type {t}")


def fingerprint(meta):
    tokens = meta.get("tokenizer.ggml.tokens", [])
    merges = meta.get("tokenizer.ggml.merges", [])
    model = meta.get("tokenizer.ggml.model", b"")
    h = hashlib.sha256()
    h.update(b"model:" + model + b"\n")
    h.update(b"vocab:%d\n" % len(tokens))
    for tok in tokens:
        h.update(b"t:%d:" % len(tok) + tok + b"\n")
    h.update(b"merges:%d\n" % len(merges))
    for m in merges:
        h.update(b"m:%d:" % len(m) + m + b"\n")
    bos = meta.get("tokenizer.ggml.bos_token_id")
    eos = meta.get("tokenizer.ggml.eos_token_id")
    h.update(b"bos:%s eos:%s\n" % (
        str(bos).encode(), str(eos).encode()))
    return {
        "arch": meta.get("general.architecture", b"").decode("utf-8", "replace"),
        "tokenizer_model": model.decode("utf-8", "replace"),
        "vocab_len": len(tokens),
        "merges_len": len(merges),
        "bos_token_id": bos,
        "eos_token_id": eos,
        "tokenizer_sha256": h.hexdigest(),
    }


def first_diff(a, b):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    if len(a) != len(b):
        return n
    return -1


def compare(pa, pb):
    ma, mb = read_meta(pa), read_meta(pb)
    fa, fb = fingerprint(ma), fingerprint(mb)
    ta = ma.get("tokenizer.ggml.tokens", [])
    tb = mb.get("tokenizer.ggml.tokens", [])
    ga = ma.get("tokenizer.ggml.merges", [])
    gb = mb.get("tokenizer.ggml.merges", [])
    tok_diff = first_diff(ta, tb)
    merge_diff = first_diff(ga, gb)
    identical = (
        fa["tokenizer_model"] == fb["tokenizer_model"]
        and tok_diff == -1
        and merge_diff == -1
        and fa["bos_token_id"] == fb["bos_token_id"]
        and fa["eos_token_id"] == fb["eos_token_id"]
    )
    return {
        "a": fa, "b": fb, "identical": identical,
        "first_token_divergence": tok_diff,
        "first_merge_divergence": merge_diff,
    }


if __name__ == "__main__":
    if sys.argv[1] == "--fingerprint":
        meta = read_meta(sys.argv[2])
        print(json.dumps(fingerprint(meta), indent=1))
    else:
        print(json.dumps(compare(sys.argv[1], sys.argv[2]), indent=1))
