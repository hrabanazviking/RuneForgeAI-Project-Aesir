from std.sys import CompilationTarget
from std.sys.intrinsics import llvm_intrinsic

def dot64(a: SIMD[DType.uint8, 64], b: SIMD[DType.int8, 64]) -> SIMD[DType.int32, 16]:
    """Sum over each group of 4 consecutive bytes: sum_j a[4l+j] * b[4l+j]."""
    if CompilationTarget.has_vnni():
        return llvm_intrinsic[
            "llvm.x86.avx512.vpdpbusd.512", SIMD[DType.int32, 16]
        ](SIMD[DType.int32, 16](Int32(0)), a, b)
    var prod = (a.cast[DType.int16]() * b.cast[DType.int16]()).cast[DType.int32]()
    var pair = prod + prod.shuffle[
        1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
        17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30,
        33, 32, 35, 34, 37, 36, 39, 38, 41, 40, 43, 42, 45, 44, 47, 46,
        49, 48, 51, 50, 53, 52, 55, 54, 57, 56, 59, 58, 61, 60, 63, 62,
    ]()
    var quad = pair + pair.shuffle[
        2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13,
        18, 19, 16, 17, 22, 23, 20, 21, 26, 27, 24, 25, 30, 31, 28, 29,
        34, 35, 32, 33, 38, 39, 36, 37, 42, 43, 40, 41, 46, 47, 44, 45,
        50, 51, 48, 49, 54, 55, 52, 53, 58, 59, 56, 57, 62, 63, 60, 61,
    ]()
    var out = SIMD[DType.int32, 16](Int32(0))
    for l in range(16):
        out[l] = quad[l * 4]
    return out

def main() raises:
    var a = SIMD[DType.uint8, 64](UInt8(0))
    var b = SIMD[DType.int8, 64](Int8(0))
    for i in range(64):
        a[i] = UInt8((i * 37 + 11) % 256)
        b[i] = Int8(((i * 53 + 7) % 255) - 127)
    var got = dot64(a, b)
    var ok = True
    for l in range(16):
        var want = Int32(0)
        for j in range(4):
            want += Int32(a[l * 4 + j].cast[DType.int32]()) * Int32(b[l * 4 + j].cast[DType.int32]())
        if got[l] != want:
            print("lane", l, "got", got[l], "want", want)
            ok = False
    print("dot64:", "PASS" if ok else "FAIL")
    print("lanes:", got[0], got[1], got[2], got[15])
