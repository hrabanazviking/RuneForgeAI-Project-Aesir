#!/usr/bin/env python3
"""J-020 disk leg: replay the REAL J-018 ExpertCache miss streams
(miss_cold / miss_warm, produced by j020_replay.mojo through the actual
Mojo module) over the J-015-pinned OLMoE Q4_K_M file on purplelongship,
under the J-019 verdict discipline only (explicit pread + next-slab
readahead). Question: what does cold-vs-warm cache state cost at the
disk, in wall time, on the same file?

Legs (strategy fixed = pread_ra):
  coldstream:coldpage  cold-cache miss stream, page cache evicted first
  coldstream:warmpage  same stream again immediately (page cache warm)
  warmstream:coldpage  warm-cache miss stream, page cache evicted first

Cold is measured, not hoped: POSIX_FADV_DONTNEED evict, then mincore
resident fraction recorded (J-019 pattern). Checksums must agree per
stream across its legs. Guard: refuses to start a leg while a 204-road
process (s0*, run_all, mojo build) is live on the box.
"""
import argparse
import csv
import ctypes
import json
import os
import subprocess
import sys
import time
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from j019_disk_bench import parse_gguf, resident_fraction, evict, pct, libc

MASK64 = (1 << 64) - 1


def build_slabs(gguf_path, miss_csv):
    meta, tensors = parse_gguf(gguf_path)
    arch = None
    for k in meta:
        if k.endswith(".expert_count"):
            arch = k.split(".")[0]
    expert_count = meta[f"{arch}.expert_count"]
    by_name = {t["name"]: t for t in tensors}
    slab = {}
    for L in range(meta[f"{arch}.block_count"]):
        for kind in ("down", "gate", "up"):
            t = by_name[f"blk.{L}.ffn_{kind}_exps.weight"]
            assert t["bytes"] % expert_count == 0
            slab[(L, kind)] = (t["abs_offset"], t["bytes"] // expert_count)
    slabs = []
    total = 0
    nmiss = 0
    with open(miss_csv) as f:
        for row in csv.reader(f):
            ti, L, e = int(row[0]), int(row[1]), int(row[2])
            exts = []
            for kind in ("down", "gate", "up"):
                base, sz = slab[(L, kind)]
                exts.append((base + e * sz, sz))
            exts.sort()
            slabs.extend(exts)
            total += sum(s for _, s in exts)
            nmiss += 1
    return slabs, total, nmiss


def guard_clear():
    out = subprocess.run(["bash", "-c",
                          "ps aux | grep -E 's0[0-9]{2}|run_all|mojo build|"
                          "aesir' | grep -v grep | grep -v j020"],
                         capture_output=True, text=True).stdout.strip()
    return out


def run_leg(path, size, slabs, cold_page):
    fd = os.open(path, os.O_RDONLY)
    try:
        rec = {}
        if cold_page:
            rec["resident_before"] = evict(fd, size)
        os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_SEQUENTIAL)
        lat = []
        crc = 0
        total = 0
        t0 = time.perf_counter_ns()
        for i, (off, sz) in enumerate(slabs):
            s0 = time.perf_counter_ns()
            if i + 1 < len(slabs):
                noff, nsz = slabs[i + 1]
                libc.readahead(fd, ctypes.c_int64(noff),
                               ctypes.c_size_t(nsz))
            data = os.pread(fd, sz, off)
            assert len(data) == sz
            crc = (crc + zlib.crc32(data)) & MASK64
            lat.append((time.perf_counter_ns() - s0) / 1e6)
            total += sz
        dt = (time.perf_counter_ns() - t0) / 1e9
        rec.update(wall_s=dt, bytes=total, checksum=crc, slabs=len(slabs),
                   slab_ms_mean=sum(lat) / len(lat),
                   slab_ms_p50=pct(lat, 0.50), slab_ms_p95=pct(lat, 0.95),
                   slab_ms_max=max(lat), gbps=total / dt / 1e9)
        return rec
    finally:
        os.close(fd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gguf", required=True)
    ap.add_argument("--miss-cold", required=True)
    ap.add_argument("--miss-warm", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    busy = guard_clear()
    if busy:
        print("GUARD ABORT: 204-road process live on box:\n" + busy,
              flush=True)
        return 3
    size = os.path.getsize(args.gguf)
    legs = [("coldstream", args.miss_cold, True),
            ("coldstream", args.miss_cold, False),
            ("warmstream", args.miss_warm, True)]
    cache = {}
    for name, csv_path, cold_page in legs:
        if csv_path not in cache:
            cache[csv_path] = build_slabs(args.gguf, csv_path)
        slabs, total, nmiss = cache[csv_path]
        state = "coldpage" if cold_page else "warmpage"
        rec = run_leg(args.gguf, size, slabs, cold_page)
        rec.update(stream=name, page_state=state, strategy="pread_ra",
                   misses=nmiss, host=os.uname().nodename,
                   kernel=os.uname().release, loadavg=os.getloadavg(),
                   ts=time.strftime("%Y-%m-%dT%H:%M:%S%z"))
        with open(args.out, "a") as f:
            f.write(json.dumps(rec) + "\n")
        print(f"{name}:{state} wall={rec['wall_s']:.3f}s "
              f"GB/s={rec['gbps']:.3f} crc={rec['checksum']} "
              f"bytes={rec['bytes']} resident_before="
              f"{rec.get('resident_before')}", flush=True)
    print("J020 DISK ALLDONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
