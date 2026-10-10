# tests/c3_h045_layout.mojo
# H045 — weight layout planner check (TEST-ONLY driver, not shipped).
#
# Builds a 6-tensor test model (shapes recorded below), runs plan_layouts,
# prints the plan JSON twice (byte-identical => deterministic), pre-packs the
# planned tensors, and compares GEMM with planned layouts vs naive gemm_fp16:
# max abs err must be <= 1e-3. Exits non-zero on failure.
#
# Usage: c3_h045_layout

from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.gemm import gemm_fp16
from armvegr.layout import (
    LayoutEntry,
    TensorSpec,
    gemm_packed,
    pack_a_for_gemm,
    pack_b_for_gemm,
    plan_layouts,
    plan_to_json,
)
from armvegr.util import fill_rand_f16, max_abs_err_f16, rng_next


def make_spec(
    name: String, rows: Int, cols: Int, dtype: UInt8, role: String
) -> TensorSpec:
    var s = TensorSpec()
    s.name = name
    s.rows = rows
    s.cols = cols
    s.dtype = dtype
    s.role = role
    return s.copy()


def main() raises:
    # 6-tensor test model (shapes recorded for the H045 evidence).
    var specs = List[TensorSpec]()
    specs.append(make_spec("w.q", 256, 128, UInt8(1), "gemm_b"))  # B: K=256 N=128
    specs.append(make_spec("w.k", 256, 64, UInt8(1), "gemm_b"))  # B: K=256 N=64
    specs.append(make_spec("act.a", 96, 256, UInt8(1), "gemm_a"))  # A: M=96 K=256
    specs.append(make_spec("n.norm", 1, 256, UInt8(0), "norm"))
    specs.append(make_spec("w.q80", 128, 256, UInt8(2), "other"))
    specs.append(make_spec("emb", 64, 256, UInt8(1), "embedding"))
    var plan = plan_layouts(specs)
    var json1 = plan_to_json(plan)
    var json2 = plan_to_json(plan_layouts(specs))
    print("PLAN1: " + json1)
    if json1 != json2:
        raise Error("H045 FAIL: plan JSON not deterministic")
    print("H045 determinism: PASS (byte-identical plan JSON)")
    # Expected layouts.
    for i in range(len(plan)):
        ref e = plan[i]
        if e.name == "w.q" or e.name == "w.k":
            if e.layout != "packed_b":
                raise Error("H045 FAIL: " + e.name + " should be packed_b")
        elif e.name == "act.a":
            if e.layout != "packed_a":
                raise Error("H045 FAIL: act.a should be packed_a")
        elif e.layout != "row_major":
            raise Error("H045 FAIL: " + e.name + " should be row_major")
    print("H045 layout decisions: PASS")
    # Numerics: packed vs naive.
    var state = unsafe_alloc[UInt64](1)
    state[unsafe_offset=0] = UInt64(0x12345678)
    var K = 256
    # Case 1: B pre-packed (w.q: K=256, N=128), A on the fly, M=96.
    var M = 96
    var N = 128
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c_naive = unsafe_alloc[Float16](M * N)
    var c_planned = unsafe_alloc[Float16](M * N)
    fill_rand_f16(a, M * K, state, -1.0, 1.0)
    fill_rand_f16(b, K * N, state, -1.0, 1.0)
    gemm_fp16(a, b, c_naive, M, N, K)
    var pb_bytes = Int(plan[0].packed_bytes)
    var pb = unsafe_alloc[UInt8](pb_bytes)
    pack_b_for_gemm(b, K, N, 64, 256, pb)
    var dummy_a = unsafe_alloc[UInt8](1)
    gemm_packed(a, b, pb, True, c_planned, M, N, K, False, dummy_a)
    var err1 = max_abs_err_f16(c_naive, c_planned, M * N)
    print("H045 packed_b vs naive max abs err: " + String(err1))
    if err1 > 1e-3:
        raise Error("H045 FAIL: packed_b numerics diverged")
    # Case 2: A pre-packed (act.a: M=96, K=256), B on the fly, N=64.
    var N2 = 64
    var b2 = unsafe_alloc[Float16](K * N2)
    var c2_naive = unsafe_alloc[Float16](M * N2)
    var c2_planned = unsafe_alloc[Float16](M * N2)
    fill_rand_f16(b2, K * N2, state, -1.0, 1.0)
    gemm_fp16(a, b2, c2_naive, M, N2, K)
    var pa_bytes = Int(plan[2].packed_bytes)
    var pa = unsafe_alloc[UInt8](pa_bytes)
    pack_a_for_gemm(a, M, K, 64, 256, pa)
    var dummy_b = unsafe_alloc[UInt8](1)
    gemm_packed(a, b2, dummy_b, False, c2_planned, M, N2, K, True, pa)
    var err2 = max_abs_err_f16(c2_naive, c2_planned, M * N2)
    print("H045 packed_a vs naive max abs err: " + String(err2))
    if err2 > 1e-3:
        raise Error("H045 FAIL: packed_a numerics diverged")
    print("H045 numerics: PASS")
    a.unsafe_free()
    b.unsafe_free()
    c_naive.unsafe_free()
    c_planned.unsafe_free()
    pb.unsafe_free()
    dummy_a.unsafe_free()
    b2.unsafe_free()
    c2_naive.unsafe_free()
    c2_planned.unsafe_free()
    pa.unsafe_free()
    dummy_b.unsafe_free()
    state.unsafe_free()
    print("H045-ALL-PASS")
