# TEST-ONLY (PRÓF): safetensors corpus generator for H043/H044.
# Deterministic: same bytes on any machine. Run: python3 make_safetensors_corpus.py <outdir>
# Also writes 5 adversarial headers (adv_*.st) for the H043 fail-closed tests.
import struct, os, sys, json, math

def _emit(path, tensors, metadata=None):
    # tensors: list of (name, dtype_str, shape, payload_bytes)
    header = {}
    if metadata:
        header["__metadata__"] = metadata
    off = 0
    for name, dtype, shape, payload in tensors:
        header[name] = {"dtype": dtype, "shape": list(shape),
                        "data_offsets": [off, off + len(payload)]}
        off += len(payload)
    hj = json.dumps(header, separators=(",", ":")).encode()
    with open(path, "wb") as f:
        f.write(struct.pack("<Q", len(hj)))
        f.write(hj)
        for _, _, _, payload in tensors:
            f.write(payload)
    print("wrote", path, os.path.getsize(path), "bytes,", len(tensors), "tensors")

def _f16(vals):
    return struct.pack("<" + "e"*len(vals), *vals)

def _bf16(vals):
    # exact BF16 bit patterns for the given float values
    out = bytearray()
    for v in vals:
        b = struct.pack("<f", v)
        out += b[2:4]  # top 2 bytes = BF16 (round toward zero truncation is fine for fixtures)
    return bytes(out)

def _f32(vals):
    return struct.pack("<" + "f"*len(vals), *vals)

def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    # 1. F16 file
    _emit(os.path.join(outdir, "st_f16.st"), [
        ("a.weight", "F16", [4, 8], _f16([i * 0.125 for i in range(32)])),
        ("b.norm", "F16", [8], _f16([0.5]*8)),
        ("c.bias", "F16", [2, 2], _f16([1.0, -1.0, 0.25, -0.25])),
    ])
    # 2. BF16 file (includes subnormal, Inf, NaN patterns for H044)
    bf_bits = (list(range(0x0000, 0x0010)) + [0x3F80, 0x4000, 0xBF80, 0x7F80,
               0xFF80, 0x7FC0, 0xFFC0, 0x0001, 0x007F, 0x7F7F, 0x0080] +
               [0x3F80 + i for i in range(21)])
    _emit(os.path.join(outdir, "st_bf16.st"), [
        ("w.weight", "BF16", [8, 6], struct.pack("<" + "H"*48, *bf_bits)),
        ("w.norm", "BF16", [6], _bf16([1.0, 2.0, 0.5, -1.5, 100.0, 0.001])),
        ("w.bias", "BF16", [4], _bf16([0.0, -0.0, 3.25, -3.25])),
    ])
    # 3. F32 file
    _emit(os.path.join(outdir, "st_f32.st"), [
        ("q.weight", "F32", [4, 4], _f32([i * 0.1 for i in range(16)])),
        ("q.norm", "F32", [4], _f32([1.0, 1.0, 1.0, 1.0])),
        ("big", "F32", [16, 16], _f32([math.sin(i) for i in range(256)])),
    ])
    # 4. mixed file with metadata + unicode-escaped name
    _emit(os.path.join(outdir, "st_mixed.st"), [
        ("blk.0.attn_q", "F16", [8, 8], _f16([0.1]*64)),
        ("blk.0.attn_k", "BF16", [8, 4], _bf16([0.2]*32)),
        ("blk.0.ffn", "F32", [4, 8], _f32([0.3]*32)),
        ("caf\u00e9.weight", "F16", [2], _f16([1.5, 2.5])),
    ], metadata={"format": "test", "note": "mixed dtypes"})
    # 5. tiny model file (H044 end-to-end)
    _emit(os.path.join(outdir, "st_model.st"), [
        ("token_embd.weight", "F16", [16, 32], _f16([(i % 32) * 0.0625 - 1.0 for i in range(512)])),
        ("output_norm.weight", "F32", [32], _f32([1.0]*32)),
        ("blk.0.attn_q.weight", "F16", [32, 32], _f16([0.05]*1024)),
        ("blk.0.attn_k.weight", "BF16", [32, 16], _bf16([0.04]*512)),
        ("blk.0.ffn_down.weight", "F32", [16, 32], _f32([0.03]*512)),
    ], metadata={"model": "tiny-test"})
    # --- adversarial headers ---
    a = os.path.join(outdir, "adv_trunc_json.st")
    with open(a, "wb") as f:
        f.write(struct.pack("<Q", 1000) + b'{"a":')
    print("wrote", a)
    def adv_raw(name, header_json, payload=b""):
        hj = header_json.encode()
        with open(os.path.join(outdir, name), "wb") as f:
            f.write(struct.pack("<Q", len(hj)) + hj + payload)
        print("wrote", name)
    adv_raw("adv_overlap.st",
            '{"a":{"dtype":"F16","shape":[4],"data_offsets":[0,8]},'
            '"b":{"dtype":"F16","shape":[4],"data_offsets":[4,12]}}',
            b"\x00"*16)
    adv_raw("adv_badoff.st",
            '{"a":{"dtype":"F16","shape":[4],"data_offsets":[0,8]},'
            '"b":{"dtype":"F16","shape":[4],"data_offsets":[8,1000000]}}',
            b"\x00"*16)
    adv_raw("adv_baddtype.st",
            '{"a":{"dtype":"Q8_0","shape":[4],"data_offsets":[0,4]}}',
            b"\x00"*8)
    adv_raw("adv_badjson.st", '{"a":{"dtype":"F16","shape":[4],"data_offsets":[0,8]')
    adv_raw("adv_negsize.st",
            '{"a":{"dtype":"F16","shape":[4],"data_offsets":[8,0]}}',
            b"\x00"*8)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
