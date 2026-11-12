#!/usr/bin/env python3
"""A-049 oversized fixture builder.
Reads the pinned stories260K F16 GGUF (real tensors), emits a valid
GGUF v3 whose tensor directory = original 48 tensors verbatim plus
NPAD pad tensors. Each pad tensor is F16 [16384 x 8192] = 256 MiB of
payload built by repeating the real token_embd.weight bytes (65,536 B)
4096 times. The original tensor data region is copied byte-for-byte,
so the embedded model is bit-identical to the pinned fixture and
generates identically; the pads make the file oversized (40 GiB of
payload) so full residency is genuinely uncomfortable on the 128 GB
host while mmap streaming touches only what a pass actually reads.
"""
import hashlib, struct, sys

SRC = "hidden_files/fixtures/stories260K.F16.gguf"
DST = "hidden_files/fixtures/oversized_a049.gguf"
NPAD = 160
PAD_COLS, PAD_ROWS = 16384, 8192
PAD_BYTES = PAD_COLS * PAD_ROWS * 2  # F16

def main():
    src = open(SRC, "rb").read()
    magic, ver, tc, kvc = struct.unpack_from("<IIQQ", src, 0)
    assert magic == 0x46554747 and ver == 3 and tc == 48
    off = 24
    def rdstr(o):
        n, = struct.unpack_from("<Q", src, o)
        return o + 8 + n
    # skip KV section generically
    TSZ = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:1,10:8,11:8,12:8}
    for _ in range(kvc):
        off = rdstr(off)
        t, = struct.unpack_from("<I", src, off); off += 4
        if t == 8:
            off = rdstr(off)
        elif t == 9:
            et, = struct.unpack_from("<I", src, off); off += 4
            n, = struct.unpack_from("<Q", src, off); off += 8
            if et == 8:
                for _ in range(n): off = rdstr(off)
            else:
                off += TSZ[et] * n
        else:
            off += TSZ[t]
    kv_end = off
    infos_start = off
    embd = None
    for _ in range(tc):
        n0 = off
        off = rdstr(off)
        name = src[n0+8:off].decode()
        nd, = struct.unpack_from("<I", src, off); off += 4
        dims = []
        for _ in range(nd):
            x, = struct.unpack_from("<Q", src, off); off += 8; dims.append(x)
        ty, = struct.unpack_from("<I", src, off); off += 4
        toff, = struct.unpack_from("<Q", src, off); off += 8
        if name == "token_embd.weight":
            embd = (dims, ty, toff)
    infos_end = off
    data_start = (infos_end + 31) // 32 * 32
    assert data_start == 14240, data_start
    dims, ty, toff = embd
    assert ty == 1 and dims == [64, 512]
    embd_bytes = src[data_start+toff:data_start+toff+65536]
    assert len(embd_bytes) == 65536
    pad_chunk = embd_bytes * 4096
    assert len(pad_chunk) == PAD_BYTES

    out = open(DST, "wb")
    out.write(struct.pack("<IIQQ", magic, ver, tc + NPAD, kvc))
    out.write(src[24:kv_end])                    # KV verbatim
    out.write(src[infos_start:infos_end])        # tensor infos verbatim
    orig_payload = len(src) - data_start
    next_off = orig_payload
    if next_off % 32: next_off += 32 - next_off % 32
    for i in range(NPAD):
        nm = ("stream.pad.%04d.weight" % i).encode()
        out.write(struct.pack("<Q", len(nm))); out.write(nm)
        out.write(struct.pack("<I", 2))
        out.write(struct.pack("<Q", PAD_COLS)); out.write(struct.pack("<Q", PAD_ROWS))
        out.write(struct.pack("<I", 1))          # F16
        out.write(struct.pack("<Q", next_off))
        next_off += PAD_BYTES
    hdr_end = out.tell()
    new_data_start = (hdr_end + 31) // 32 * 32
    out.write(b"\0" * (new_data_start - hdr_end))
    assert new_data_start % 32 == 0
    # NOTE: tensor offsets are relative to data start; original offsets
    # stay valid because the original data region is copied verbatim
    # immediately at the new data start, pads follow after the same
    # relative offsets computed above (orig_payload aligned up).
    out.write(src[data_start:])                  # original data verbatim
    pad_gap = next_off - PAD_BYTES - orig_payload
    # recompute: first pad offset was aligned orig_payload; file cursor
    # is at orig_payload relative; write gap if any
    cur_rel = len(src) - data_start
    first_pad_off = orig_payload if orig_payload % 32 == 0 else orig_payload + (32 - orig_payload % 32)
    if first_pad_off > cur_rel:
        out.write(b"\0" * (first_pad_off - cur_rel))
    h = hashlib.sha256()
    for i in range(NPAD):
        # stream pads in 16 MiB slices, hashing the whole file is done
        # externally with sha256sum; here just write
        mv = memoryview(pad_chunk)
        for s in range(0, PAD_BYTES, 16*1024*1024):
            out.write(mv[s:s+16*1024*1024])
        if i % 20 == 0: print("pad", i, "written", flush=True)
    total = out.tell()
    out.close()
    print("DST bytes:", total)
    print("payload pad bytes:", NPAD * PAD_BYTES)

if __name__ == "__main__":
    main()
