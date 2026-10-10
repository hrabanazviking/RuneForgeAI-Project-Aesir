# TEST-ONLY (PRÓF): independent integer-arithmetic BF16->FP16 RNE reference for H044.
# Computes the expected FP16 bit pattern for every BF16 bit pattern using pure
# integer arithmetic (no floats), implementing round-to-nearest-even per the
# contract in armvegr/safetensors.mojo. Writes 65536 LE u16 to <outfile>.
# Usage: python3 check_bf16_rne.py <outfile>
import struct, sys

def bf16_to_f16_rne(w):
    sign = (w >> 15) & 1
    exp8 = (w >> 7) & 0xFF
    mant7 = w & 0x7F
    s = sign << 15
    if exp8 == 0xFF:
        return s | 0x7C00 if mant7 == 0 else s | 0x7E00
    if exp8 == 0:
        # |v| <= 127 * 2^-133 << half FP16-subnormal ULP -> signed zero
        return s
    e = exp8 - 127
    e5 = e + 15
    if e5 >= 31:
        return s | 0x7C00
    if e5 <= 0:
        # subnormal: M = round((128 + mant7) * 2^(e+17)), RNE
        base = 128 + mant7
        shift = e + 17
        if shift >= 0:
            m = base << shift
        else:
            v = base
            drop = -shift
            q = v >> drop
            mask = (1 << drop) - 1
            rem = v & mask
            half = 1 << (drop - 1)
            if rem > half or (rem == half and (q & 1)):
                q += 1
            m = q
        if m >= 1024:
            return s | 0x0400
        return s | m
    # normal: exact, M10 = mant7 * 8
    return s | (e5 << 10) | (mant7 * 8)

def main(path):
    out = bytearray()
    for w in range(65536):
        out += struct.pack("<H", bf16_to_f16_rne(w))
    open(path, "wb").write(bytes(out))
    print("reference wrote", path, len(out), "bytes")

if __name__ == "__main__":
    main(sys.argv[1])
