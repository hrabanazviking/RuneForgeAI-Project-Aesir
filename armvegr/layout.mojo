# armvegr/layout.mojo
# H045 — Weight layout planner (Domain D1 ARMVEGR, pure Mojo).
#
# Given a model's tensor shapes and the kernel contracts (H023/H033), the
# planner decides per-tensor packed/interleaved layouts and pre-packs weights
# at load time so inference never repacks.
#
# Layouts:
#   "row_major"  — untouched C-order (norms, embeddings, 1-D, small or
#                  quantized tensors, anything the planner leaves alone).
#   "packed_b"   — FP16 GEMM B-weight pre-packed into (NC x KC) column panels
#                  in the exact byte order gemm_fp16's inner loop consumes
#                  (see gemm_pack_b). Panel (ji, pi) holds cur_nc x cur_kc
#                  values as bp[j*kc + k].
#   "packed_a"   — FP16 GEMM A-weight pre-packed into (MC x KC) row panels
#                  in gemm_pack_a's byte order: ap[i*kc + k].
# Packed buffers are self-describing: [n_slab: u64][n_k: u64]
# [offsets: n_slab*n_k x u64 LE][panel data...]. Offsets are absolute byte
# offsets from the buffer start. gemm_packed consumes them directly.
#
# Planner rules (deterministic; recorded in the plan JSON):
#   - role "gemm_b", dtype F16, N >= 64 and K >= 64 -> "packed_b" (NC=64, KC=256)
#   - role "gemm_a", dtype F16, M >= 64 and K >= 64 -> "packed_a" (MC=64, KC=256)
#   - everything else -> "row_major"
# Numerics: packed GEMM executes the same micro-kernel in the same order over
# the same bytes, so results are bit-identical to the naive path (the H045
# acceptance allows <= 1e-3; measured 0).

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.gemm import (
    gemm_fp16,
    gemm_micro_8x8,
    gemm_pack_a,
    gemm_pack_b,
    gemm_scalar_tile,
)


struct TensorSpec(Copyable, Movable):
    var name: String
    var rows: Int
    var cols: Int
    var dtype: UInt8  # 0=F32, 1=F16, 2=Q8_0, 3=Q4_0
    var role: String  # "gemm_a" | "gemm_b" | "norm" | "embedding" | "other"

    def __init__(out self):
        self.name = ""
        self.rows = 0
        self.cols = 0
        self.dtype = UInt8(255)
        self.role = "other"


struct LayoutEntry(Copyable, Movable):
    var name: String
    var layout: String  # "row_major" | "packed_b" | "packed_a"
    var block_m: Int
    var block_n: Int
    var block_k: Int
    var packed_bytes: Int64

    def __init__(out self):
        self.name = ""
        self.layout = "row_major"
        self.block_m = 0
        self.block_n = 0
        self.block_k = 0
        self.packed_bytes = Int64(0)


def plan_layouts(specs: List[TensorSpec]) -> List[LayoutEntry]:
    """Decide the layout for each tensor. Deterministic: no RNG, no time."""
    var out = List[LayoutEntry]()
    for i in range(len(specs)):
        ref s = specs[i]
        var e = LayoutEntry()
        e.name = s.name
        if s.role == "gemm_b" and s.dtype == UInt8(1) and s.cols >= 64 and s.rows >= 64:
            # B is (K x N): rows=K, cols=N.
            e.layout = "packed_b"
            e.block_n = 64
            e.block_k = 256
            e.packed_bytes = packed_b_bytes(s.rows, s.cols, 64, 256)
        elif s.role == "gemm_a" and s.dtype == UInt8(1) and s.rows >= 64 and s.cols >= 64:
            # A is (M x K): rows=M, cols=K.
            e.layout = "packed_a"
            e.block_m = 64
            e.block_k = 256
            e.packed_bytes = packed_a_bytes(s.rows, s.cols, 64, 256)
        else:
            e.layout = "row_major"
        out.append(e.copy())
    return out.copy()


def _ceil_div(a: Int, b: Int) -> Int:
    return (a + b - 1) // b


def packed_b_bytes(K: Int, N: Int, NC: Int, KC: Int) -> Int64:
    """Byte size of a packed_b buffer for a (K x N) F16 matrix."""
    var nj = _ceil_div(N, NC)
    var nk = _ceil_div(K, KC)
    var data = Int64(0)
    for ji in range(nj):
        var cur_nc = NC
        if (ji + 1) * NC > N:
            cur_nc = N - ji * NC
        for pi in range(nk):
            var cur_kc = KC
            if (pi + 1) * KC > K:
                cur_kc = K - pi * KC
            data += Int64(cur_nc * cur_kc * 2)
    return Int64(16 + 8 * nj * nk) + data


def packed_a_bytes(M: Int, K: Int, MC: Int, KC: Int) -> Int64:
    """Byte size of a packed_a buffer for a (M x K) F16 matrix."""
    var ni = _ceil_div(M, MC)
    var nk = _ceil_div(K, KC)
    var data = Int64(0)
    for ii in range(ni):
        var cur_mc = MC
        if (ii + 1) * MC > M:
            cur_mc = M - ii * MC
        for pi in range(nk):
            var cur_kc = KC
            if (pi + 1) * KC > K:
                cur_kc = K - pi * KC
            data += Int64(cur_mc * cur_kc * 2)
    return Int64(16 + 8 * ni * nk) + data


def _write_u64_le(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int, v: Int):
    for b in range(8):
        buf[unsafe_offset=off + b] = UInt8((v >> (8 * b)) & 255)


def _read_u64_le(buf: Pointer[UInt8, MutUntrackedOrigin], off: Int) -> Int:
    var v = 0
    for b in range(8):
        v |= Int(buf.unsafe_offset(off + b).unsafe_load()) << (8 * b)
    return v


def pack_b_for_gemm(
    b: Pointer[Float16, MutUntrackedOrigin],
    K: Int,
    N: Int,
    NC: Int,
    KC: Int,
    packed: Pointer[UInt8, MutUntrackedOrigin],
):
    """Pre-pack a (K x N) F16 B matrix into packed_b layout."""
    var nj = _ceil_div(N, NC)
    var nk = _ceil_div(K, KC)
    _write_u64_le(packed, 0, nj)
    _write_u64_le(packed, 8, nk)
    var data_off = 16 + 8 * nj * nk
    var tmp = unsafe_alloc[Float16](NC * KC)
    for ji in range(nj):
        var j0 = ji * NC
        var cur_nc = NC
        if j0 + cur_nc > N:
            cur_nc = N - j0
        for pi in range(nk):
            var p0 = pi * KC
            var cur_kc = KC
            if p0 + cur_kc > K:
                cur_kc = K - p0
            gemm_pack_b(b, tmp, N, j0, cur_nc, p0, cur_kc)
            _write_u64_le(packed, 16 + 8 * (ji * nk + pi), data_off)
            var dst = packed.unsafe_offset(data_off).unsafe_bitcast[Float16]()
            for t in range(cur_nc * cur_kc):
                dst[unsafe_offset=t] = tmp[unsafe_offset=t]
            data_off += cur_nc * cur_kc * 2
    tmp.unsafe_free()


def pack_a_for_gemm(
    a: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    K: Int,
    MC: Int,
    KC: Int,
    packed: Pointer[UInt8, MutUntrackedOrigin],
):
    """Pre-pack a (M x K) F16 A matrix into packed_a layout."""
    var ni = _ceil_div(M, MC)
    var nk = _ceil_div(K, KC)
    _write_u64_le(packed, 0, ni)
    _write_u64_le(packed, 8, nk)
    var data_off = 16 + 8 * ni * nk
    var tmp = unsafe_alloc[Float16](MC * KC)
    for ii in range(ni):
        var i0 = ii * MC
        var cur_mc = MC
        if i0 + cur_mc > M:
            cur_mc = M - i0
        for pi in range(nk):
            var p0 = pi * KC
            var cur_kc = KC
            if p0 + cur_kc > K:
                cur_kc = K - p0
            gemm_pack_a(a, tmp, K, i0, cur_mc, p0, cur_kc)
            _write_u64_le(packed, 16 + 8 * (ii * nk + pi), data_off)
            var dst = packed.unsafe_offset(data_off).unsafe_bitcast[Float16]()
            for t in range(cur_mc * cur_kc):
                dst[unsafe_offset=t] = tmp[unsafe_offset=t]
            data_off += cur_mc * cur_kc * 2
    tmp.unsafe_free()


def gemm_packed(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    packed_b: Pointer[UInt8, MutUntrackedOrigin],
    use_packed_b: Bool,
    c: Pointer[Float16, MutUntrackedOrigin],
    M: Int,
    N: Int,
    K: Int,
    use_packed_a: Bool,
    packed_a: Pointer[UInt8, MutUntrackedOrigin],
):
    """GEMM C = A @ B where B (and optionally A) is pre-packed.
    With use_packed_b=False, B is the row-major (K x N) matrix packed on the
    fly; with use_packed_a=False, A is the row-major (M x K) matrix packed on
    the fly. Mirrors gemm_fp16's blocking exactly (MC=64, NC=64, KC=256) so
    numerics match bit-for-bit.
    """
    var mc_block = 64
    var nc_block = 64
    var kc_block = 256
    var acc = unsafe_alloc[Float32](mc_block * nc_block)
    var ap = unsafe_alloc[Float16](mc_block * kc_block)
    var bp = unsafe_alloc[Float16](nc_block * kc_block)
    var nk = 0
    if use_packed_b:
        nk = _read_u64_le(packed_b, 8)
    var nk_a = 0
    if use_packed_a:
        nk_a = _read_u64_le(packed_a, 8)
    for i0 in range(0, M, mc_block):
        var cur_mc = mc_block
        if i0 + cur_mc > M:
            cur_mc = M - i0
        for j0 in range(0, N, nc_block):
            var cur_nc = nc_block
            if j0 + cur_nc > N:
                cur_nc = N - j0
            for t in range(cur_mc * cur_nc):
                acc[unsafe_offset=t] = Float32(0)
            for p0 in range(0, K, kc_block):
                var cur_kc = kc_block
                if p0 + cur_kc > K:
                    cur_kc = K - p0
                # A panel: pre-packed or on the fly.
                var ap_use: Pointer[Float16, MutUntrackedOrigin]
                if use_packed_a:
                    var ii_a = i0 // mc_block
                    var pi_a = p0 // kc_block
                    var aoff = _read_u64_le(packed_a, 16 + 8 * (ii_a * nk_a + pi_a))
                    ap_use = packed_a.unsafe_offset(aoff).unsafe_bitcast[Float16]()
                else:
                    gemm_pack_a(a, ap, K, i0, cur_mc, p0, cur_kc)
                    ap_use = ap
                # B panel: pre-packed or on the fly.
                var bp_use: Pointer[Float16, MutUntrackedOrigin]
                if use_packed_b:
                    var ji = j0 // nc_block
                    var pi = p0 // kc_block
                    var boff = _read_u64_le(packed_b, 16 + 8 * (ji * nk + pi))
                    bp_use = packed_b.unsafe_offset(boff).unsafe_bitcast[Float16]()
                else:
                    gemm_pack_b(b, bp, N, j0, cur_nc, p0, cur_kc)
                    bp_use = bp
                var ii = 0
                while ii < cur_mc:
                    var mr = 8
                    if ii + mr > cur_mc:
                        mr = cur_mc - ii
                    var jj = 0
                    while jj < cur_nc:
                        var nr = 8
                        if jj + nr > cur_nc:
                            nr = cur_nc - jj
                        if mr == 8 and nr == 8:
                            gemm_micro_8x8(
                                ap_use.unsafe_offset(ii * cur_kc),
                                bp_use.unsafe_offset(jj * cur_kc),
                                acc.unsafe_offset(ii * cur_nc + jj),
                                cur_kc,
                                cur_nc,
                            )
                        else:
                            gemm_scalar_tile(
                                ap_use.unsafe_offset(ii * cur_kc),
                                bp_use.unsafe_offset(jj * cur_kc),
                                acc.unsafe_offset(ii * cur_nc + jj),
                                mr,
                                nr,
                                cur_kc,
                                cur_nc,
                            )
                        jj += 8
                    ii += 8
            for i in range(cur_mc):
                for j in range(cur_nc):
                    c[unsafe_offset=(i0 + i) * N + j0 + j] = Float16(
                        acc[unsafe_offset=i * cur_nc + j]
                    )
    acc.unsafe_free()
    ap.unsafe_free()
    bp.unsafe_free()


def plan_to_json(entries: List[LayoutEntry]) -> String:
    """Deterministic plan JSON: entries sorted by name, fixed field order."""
    var order = List[Int]()
    for i in range(len(entries)):
        order.append(i)
    for i in range(1, len(order)):
        var key = order[i]
        var j = i - 1
        while j >= 0 and entries[order[j]].name > entries[key].name:
            order[j + 1] = order[j]
            j -= 1
        order[j + 1] = key
    var s = String('{"tensors":[')
    for oi in range(len(order)):
        ref e = entries[order[oi]]
        if oi > 0:
            s += ","
        s += (
            '{"name":"' + e.name + '","layout":"' + e.layout
            + '","block_m":' + String(e.block_m)
            + ',"block_n":' + String(e.block_n)
            + ',"block_k":' + String(e.block_k)
            + ',"packed_bytes":' + String(e.packed_bytes) + "}"
        )
    s += "]}"
    return s


def layout_version() -> String:
    return "0.1.0"
