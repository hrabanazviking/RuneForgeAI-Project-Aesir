# tests/c9_h164_gemm.mojo
# H164 — verify gemm_fp16_tuned (config 11: mc128_kc512_nc128_hoist1_micro1)
# is bit-identical to the original gemm_fp16.

from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.gemm import gemm_fp16
from armvegr.gemm_tuned import gemm_fp16_tuned, GemmTune
from armvegr.util import fill_rand_f16


def main() raises:
    var M = 256
    var N = 256
    var K = 256
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c1 = unsafe_alloc[Float16](M * N)
    var c2 = unsafe_alloc[Float16](M * N)
    var st = unsafe_alloc[UInt64](1)
    st[unsafe_offset=0] = 42
    fill_rand_f16(a, M * K, st, -1.0, 1.0)
    fill_rand_f16(b, K * N, st, -1.0, 1.0)

    gemm_fp16(a, b, c1, M, N, K)
    var tune = GemmTune(128, 512, 128, 0, True, 1)
    gemm_fp16_tuned(a, b, c2, M, N, K, tune)

    var bad = 0
    for i in range(M * N):
        if c1[unsafe_offset=i] != c2[unsafe_offset=i]:
            bad += 1
            if bad < 5:
                print("MISMATCH at " + String(i))
    if bad == 0:
        print("H164 GEMM CORRECTNESS: PASS (bit-identical, 256^3)")
    else:
        print("H164 GEMM CORRECTNESS: FAIL (" + String(bad) + " mismatches)")
