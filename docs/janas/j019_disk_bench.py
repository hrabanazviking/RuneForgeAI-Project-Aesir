#!/usr/bin/env python3
"""J-019 disk-reading measurement harness (Project Aesir, Janas clean-room road).

MEASUREMENT HARNESS ONLY -- not Aesir engine code. It exists to answer one
question with numbers: when J-018's expert cache misses, how should the
engine read the missed expert's three slabs from the GGUF file?

Workload (never invented): the J-016 router trace
(j016_trace_olmoe.jsonl, MEASURED on purplelongship by the J-016 reference
instrument) is replayed through a pair-capacity LRU cache (J-016's own
simulation construction) over the first --tokens tokens. The misses, in
order, are the demand stream. Each miss expands to exactly three slab
reads whose offsets and sizes come from the opened file's own GGUF
tensor directory (J-017 section 3.3: the directory is the only truth --
no family layout assumption), in file order within the expert.

Strategies measured on the SAME file under the SAME demand:
  seq       sequential pread of the whole file in 8 MiB chunks
            (bandwidth ceiling reference on this file/device)
  mmap      plain mmap paging: bytes touched through a read-only mapping,
            exactly as Aesir's current loader (PackedGGUF) exposes them
  mmap_wn   mmap + madvise(MADV_WILLNEED) for the next miss's slabs
  pread     explicit os.pread of exactly the needed slabs
  pread_ra  pread + readahead(2) issued for the next slab while the
            current slab is consumed, POSIX_FADV_SEQUENTIAL set at open
  pipe      pread + a helper thread keeping posix_fadvise(WILLNEED)
            issued --lookahead slabs ahead of the reader
  odirect   O_DIRECT pread of the 4096-aligned cover extent of each slab
            (GGUF slabs are only 32-byte aligned, so raw O_DIRECT on the
            slab itself is impossible; the cover's over-read is counted)

Every leg consumes every byte it reads with zlib.crc32 (the consume
proxy: dequant must touch every byte anyway) and all strategies must
agree on the combined checksum for a workload, or the run is invalid.

Cold legs first evict the file from the page cache with
posix_fadvise(POSIX_FADV_DONTNEED) and report the mincore-resident page
fraction afterwards, so "cold" is a measured state, not a hope. Warm legs
run the identical workload immediately after a completed pass.

Usage:
  j019_disk_bench.py --gguf PATH --trace TRACE.jsonl --tokens 16 \
      --cap 512 --legs mmap:cold,pread:cold,... --out results.jsonl
Each leg appends one JSON object to --out and prints a one-line summary.
Run legs in separate invocations when a co-running workload must be
yielded to between legs.
"""
import argparse
import ctypes
import json
import mmap as mmap_mod
import os
import struct
import sys
import threading
import time
import zlib
from collections import OrderedDict

# GGUF quant block table: the fixed J-015 table (verified against
# gguf-py's GGML_QUANT_SIZES; see j015_parse_gguf.py).
TT = {0: ("F32", 1, 4), 1: ("F16", 1, 2), 2: ("Q4_0", 32, 18), 3: ("Q4_1", 32, 20),
      6: ("Q5_0", 32, 22), 7: ("Q5_1", 32, 24), 8: ("Q8_0", 32, 34), 9: ("Q8_1", 32, 40),
      10: ("Q2_K", 256, 84), 11: ("Q3_K", 256, 110), 12: ("Q4_K", 256, 144),
      13: ("Q5_K", 256, 176), 14: ("Q6_K", 256, 210), 15: ("Q8_K", 256, 292),
      16: ("IQ2_XXS", 256, 66), 17: ("IQ2_XS", 256, 74), 18: ("IQ3_XXS", 256, 98),
      19: ("IQ1_S", 256, 50), 20: ("IQ4_NL", 32, 18), 21: ("IQ3_S", 256, 110),
      22: ("IQ2_S", 256, 82), 23: ("IQ4_XS", 256, 136), 24: ("I8", 1, 1),
      25: ("I16", 1, 2), 26: ("I32", 1, 4), 27: ("I64", 1, 8), 28: ("F64", 1, 8),
      29: ("IQ1_M", 256, 56), 30: ("BF16", 1, 2), 34: ("TQ1_0", 256, 54),
      35: ("TQ2_0", 256, 66), 39: ("MXFP4", 32, 17), 40: ("NVFP4", 64, 36),
      41: ("Q1_0", 128, 18)}

PAGE = 4096
MASK64 = (1 << 64) - 1
libc = ctypes.CDLL("libc.so.6", use_errno=True)


class R:
    def __init__(self, f):
        self.f = f

    def u32(self):
        return struct.unpack("<I", self.f.read(4))[0]

    def u64(self):
        return struct.unpack("<Q", self.f.read(8))[0]

    def s(self):
        n = self.u64()
        return self.f.read(n).decode("utf-8", "replace")


def skip_value(f, t):
    """Skip one metadata value of GGUF type t (we only need two keys)."""
    sizes = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8}
    if t == 8:  # string
        n = struct.unpack("<Q", f.read(8))[0]
        f.seek(n, 1)
        return None
    if t == 9:  # array
        et = struct.unpack("<I", f.read(4))[0]
        n = struct.unpack("<Q", f.read(8))[0]
        if et == 8:
            for _ in range(n):
                skip_value(f, 8)
        else:
            f.seek(sizes[et] * n, 1)
        return None
    raw = f.read(sizes[t])
    if t == 4:
        return struct.unpack("<I", raw)[0]
    if t == 5:
        return struct.unpack("<i", raw)[0]
    return None


def parse_gguf(path):
    """Return (meta_subset, tensors) with absolute offsets, directory only."""
    with open(path, "rb") as f:
        assert f.read(4) == b"GGUF"
        version = struct.unpack("<I", f.read(4))[0]
        assert version == 3, version
        n_tensors = struct.unpack("<Q", f.read(8))[0]
        n_kv = struct.unpack("<Q", f.read(8))[0]
        r = R(f)
        meta = {}
        for _ in range(n_kv):
            k = r.s()
            t = r.u32()
            v = skip_value(f, t)
            if k in ("general.alignment",) or k.endswith(".expert_count") \
                    or k.endswith(".block_count"):
                meta[k] = v
        tensors = []
        for _ in range(n_tensors):
            name = r.s()
            nd = r.u32()
            dims = [r.u64() for _ in range(nd)]
            tt = r.u32()
            off = r.u64()
            _, bs, tsz = TT[tt]
            elems = 1
            for d in dims:
                elems *= d
            tensors.append({"name": name, "bytes": elems // bs * tsz,
                            "rel_offset": off})
        hdr_end = f.tell()
    align = meta.get("general.alignment", 32)
    data_start = (hdr_end + align - 1) // align * align
    for t in tensors:
        t["abs_offset"] = data_start + t["rel_offset"]
    return meta, tensors


def build_workload(gguf_path, trace_path, n_tokens, cap_pairs):
    meta, tensors = parse_gguf(gguf_path)
    arch = None
    for k in meta:
        if k.endswith(".expert_count"):
            arch = k.split(".")[0]
    expert_count = meta[f"{arch}.expert_count"]
    by_name = {t["name"]: t for t in tensors}
    # Slab extents per (layer, kind) from the directory only.
    slab = {}
    layers = meta[f"{arch}.block_count"]
    for L in range(layers):
        for kind in ("down", "gate", "up"):
            t = by_name[f"blk.{L}.ffn_{kind}_exps.weight"]
            assert t["bytes"] % expert_count == 0
            slab[(L, kind)] = (t["abs_offset"], t["bytes"] // expert_count)
    toks = []
    with open(trace_path) as f:
        for line in f:
            d = json.loads(line)
            if d.get("type") == "token":
                toks.append(d)
            if len(toks) >= n_tokens:
                break
    cache = OrderedDict()
    slabs = []
    misses = 0
    accesses = 0
    total_bytes = 0
    for t in toks:
        for L, layer in enumerate(t["layers"]):
            for e in layer:
                accesses += 1
                key = (L, e)
                if key in cache:
                    cache.move_to_end(key)
                    continue
                misses += 1
                if len(cache) >= cap_pairs:
                    cache.popitem(last=False)
                cache[key] = 1
                # The expert's three slabs, in file order.
                exts = []
                for kind in ("down", "gate", "up"):
                    base, sz = slab[(L, kind)]
                    exts.append((base + e * sz, sz))
                exts.sort()
                slabs.extend(exts)
                total_bytes += sum(s for _, s in exts)
    return {"slabs": slabs, "misses": misses, "accesses": accesses,
            "bytes": total_bytes, "expert_count": expert_count,
            "layers": layers}


def resident_fraction(fd, size):
    # Map via libc directly: a read-only Python mmap object will not hand
    # out its address through ctypes, and mincore needs the raw pointer.
    libc.mmap.restype = ctypes.c_void_p
    libc.mmap.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int,
                          ctypes.c_int, ctypes.c_int, ctypes.c_int64]
    addr = libc.mmap(None, size, 1, 1, fd, 0)  # PROT_READ, MAP_SHARED
    if addr in (None, ctypes.c_void_p(-1).value):
        return -1.0
    try:
        npages = (size + PAGE - 1) // PAGE
        vec = (ctypes.c_ubyte * npages)()
        rc = libc.mincore(ctypes.c_void_p(addr), ctypes.c_size_t(size),
                          ctypes.cast(vec, ctypes.POINTER(ctypes.c_ubyte)))
        if rc != 0:
            return -1.0
        res = sum(1 for i in range(npages) if vec[i] & 1)
        return res / npages
    finally:
        libc.munmap(ctypes.c_void_p(addr), ctypes.c_size_t(size))


def evict(fd, size):
    os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
    return resident_fraction(fd, size)


def pct(samples, q):
    if not samples:
        return 0.0
    s = sorted(samples)
    return s[min(len(s) - 1, int(q * len(s)))]


def run_leg(strategy, state, path, size, slabs, lookahead):
    """Run one leg; return the result dict. state is 'cold' or 'warm'."""
    rec = {"strategy": strategy, "cache_state": state}
    if strategy == "seq":
        fd = os.open(path, os.O_RDONLY)
        try:
            if state == "cold":
                rec["resident_before"] = evict(fd, size)
            t0 = time.perf_counter_ns()
            total = 0
            crc = 0
            off = 0
            while off < size:
                data = os.pread(fd, min(8 * 1024 * 1024, size - off), off)
                if not data:
                    break
                crc = (crc + zlib.crc32(data)) & MASK64
                total += len(data)
                off += len(data)
            dt = (time.perf_counter_ns() - t0) / 1e9
            rec.update(wall_s=dt, bytes=total, checksum=crc, slabs=0)
            return rec
        finally:
            os.close(fd)

    fd = os.open(path, os.O_RDONLY | (os.O_DIRECT if strategy == "odirect" else 0))
    try:
        if state == "cold":
            rec["resident_before"] = evict(fd, size)
        mm = None
        if strategy in ("mmap", "mmap_wn"):
            mm = mmap_mod.mmap(fd, 0, access=mmap_mod.ACCESS_READ)
        if strategy == "pread_ra":
            os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_SEQUENTIAL)
        stop = threading.Event()
        thread = None
        if strategy == "pipe":
            def advisor():
                i = 0
                n = len(slabs)
                while not stop.is_set() and i < n:
                    off, sz = slabs[i]
                    os.posix_fadvise(fd, off, sz, os.POSIX_FADV_WILLNEED)
                    i += 1
                    # Stay roughly `lookahead` slabs ahead of the reader:
                    # the reader publishes its index through fd's slot.
                    while not stop.is_set() and i - reader_idx[0] > lookahead:
                        time.sleep(0.0002)
            reader_idx = [0]
            thread = threading.Thread(target=advisor, daemon=True)
            thread.start()
        # Aligned buffer for O_DIRECT.
        buf = None
        buf_addr = 0
        if strategy == "odirect":
            raw = ctypes.create_string_buffer(2 * 1024 * 1024 + PAGE)
            base = ctypes.addressof(raw)
            buf_addr = (base + PAGE - 1) & ~(PAGE - 1)
            buf = raw
            rec["_rawbuf"] = raw  # keep alive
        lat = []
        crc = 0
        total = 0
        over = 0
        t0 = time.perf_counter_ns()
        for i, (off, sz) in enumerate(slabs):
            s0 = time.perf_counter_ns()
            if strategy == "mmap":
                crc = (crc + zlib.crc32(mm[off:off + sz])) & MASK64
            elif strategy == "mmap_wn":
                if i + 1 < len(slabs):
                    noff, nsz = slabs[i + 1]
                    # madvise(2) requires a page-aligned start; GGUF slab
                    # offsets are only 32-byte aligned, so advise the
                    # page-aligned cover of the next slab.
                    aoff = noff & ~(PAGE - 1)
                    aend = (noff + nsz + PAGE - 1) & ~(PAGE - 1)
                    mm.madvise(mmap_mod.MADV_WILLNEED, aoff, aend - aoff)
                crc = (crc + zlib.crc32(mm[off:off + sz])) & MASK64
            elif strategy in ("pread", "pipe"):
                data = os.pread(fd, sz, off)
                assert len(data) == sz, (len(data), sz)
                crc = (crc + zlib.crc32(data)) & MASK64
            elif strategy == "pread_ra":
                if i + 1 < len(slabs):
                    noff, nsz = slabs[i + 1]
                    libc.readahead(fd, ctypes.c_int64(noff), ctypes.c_size_t(nsz))
                data = os.pread(fd, sz, off)
                assert len(data) == sz
                crc = (crc + zlib.crc32(data)) & MASK64
            elif strategy == "odirect":
                aoff = off & ~(PAGE - 1)
                aend = (off + sz + PAGE - 1) & ~(PAGE - 1)
                alen = aend - aoff
                n = libc.pread(fd, ctypes.c_void_p(buf_addr),
                               ctypes.c_size_t(alen), ctypes.c_int64(aoff))
                assert n == alen, (n, alen)
                inner = ctypes.string_at(buf_addr + (off - aoff), sz)
                crc = (crc + zlib.crc32(inner)) & MASK64
                over += alen - sz
            lat.append((time.perf_counter_ns() - s0) / 1e6)
            total += sz
            if strategy == "pipe":
                reader_idx[0] = i
        dt = (time.perf_counter_ns() - t0) / 1e9
        if thread is not None:
            stop.set()
            thread.join(timeout=5)
        if mm is not None:
            mm.close()
        rec.update(wall_s=dt, bytes=total, checksum=crc, slabs=len(slabs),
                   slab_ms_mean=sum(lat) / len(lat), slab_ms_p50=pct(lat, 0.50),
                   slab_ms_p95=pct(lat, 0.95), slab_ms_max=max(lat))
        if strategy == "odirect":
            rec["overread_bytes"] = over
        rec.pop("_rawbuf", None)
        return rec
    finally:
        os.close(fd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gguf", required=True)
    ap.add_argument("--trace", required=True)
    ap.add_argument("--tokens", type=int, default=16)
    ap.add_argument("--cap", type=int, default=512)
    ap.add_argument("--legs", required=True,
                    help="comma list of strategy:state, e.g. mmap:cold")
    ap.add_argument("--lookahead", type=int, default=8)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    size = os.path.getsize(args.gguf)
    wl = build_workload(args.gguf, args.trace, args.tokens, args.cap)
    print(f"workload: tokens={args.tokens} cap={args.cap} accesses={wl['accesses']} "
          f"misses={wl['misses']} slabs={len(wl['slabs'])} bytes={wl['bytes']}",
          flush=True)
    for leg in args.legs.split(","):
        strategy, state = leg.split(":")
        rec = run_leg(strategy, state, args.gguf, size, wl["slabs"],
                      args.lookahead)
        rec.update(host=os.uname().nodename, kernel=os.uname().release,
                   loadavg=os.getloadavg(), tokens=args.tokens, cap=args.cap,
                   workload_bytes=wl["bytes"], workload_misses=wl["misses"],
                   ts=time.strftime("%Y-%m-%dT%H:%M:%S%z"))
        rec["gbps"] = rec["bytes"] / rec["wall_s"] / 1e9
        with open(args.out, "a") as f:
            f.write(json.dumps(rec) + "\n")
        print(f"{strategy}:{state} wall={rec['wall_s']:.3f}s "
              f"GB/s={rec['gbps']:.3f} crc={rec['checksum']} "
              f"resident_before={rec.get('resident_before')}", flush=True)


if __name__ == "__main__":
    main()
