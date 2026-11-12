# hidden_files/a039_bench.mojo -- A-039 IQ dequant bench (standalone,
# NOT part of run_all). Per IQ format: scalar per-element decode via
# iq_value_g (the pre-A-039 *_blocks definition) vs dequantize_*_blocks
# (A-039 wide-SIMD path) on the same deterministic fixture.
# 1 settle run + 5 measured trials, median ns/element reported.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc

from core.extreme_quantization import (
    dequantize_iq1_m_blocks,
    dequantize_iq1_s_blocks,
    dequantize_iq2_s_blocks,
    dequantize_iq2_xs_blocks,
    dequantize_iq2_xxs_blocks,
    dequantize_iq3_s_blocks,
    dequantize_iq3_xxs_blocks,
    dequantize_iq4_nl_blocks,
    dequantize_iq4_xs_blocks,
    iq_grid_materialize,
    iq_value_g,
)


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A039: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def median_of(mut vals: List[Float64]) -> Float64:
    for i in range(len(vals)):
        for j in range(len(vals) - 1 - i):
            if vals[j] > vals[j + 1]:
                var tmp = vals[j]
                vals[j] = vals[j + 1]
                vals[j + 1] = tmp
    return vals[len(vals) // 2]


def run_blocks(
    kind: Int,
    data: Pointer[UInt8, MutUntrackedOrigin],
    nbytes: Int,
    outp: Pointer[Float16, MutUntrackedOrigin],
    elements: Int,
) raises:
    if kind == 29:
        dequantize_iq1_m_blocks(data, nbytes, outp, elements)
    elif kind == 19:
        dequantize_iq1_s_blocks(data, nbytes, outp, elements)
    elif kind == 16:
        dequantize_iq2_xxs_blocks(data, nbytes, outp, elements)
    elif kind == 17:
        dequantize_iq2_xs_blocks(data, nbytes, outp, elements)
    elif kind == 22:
        dequantize_iq2_s_blocks(data, nbytes, outp, elements)
    elif kind == 18:
        dequantize_iq3_xxs_blocks(data, nbytes, outp, elements)
    elif kind == 21:
        dequantize_iq3_s_blocks(data, nbytes, outp, elements)
    elif kind == 23:
        dequantize_iq4_xs_blocks(data, nbytes, outp, elements)
    else:
        dequantize_iq4_nl_blocks(data, nbytes, outp, elements)


def bench_format(
    name: String, kind: Int, bytes_per_256: Int, super_blocks: Int, seed: Int
) raises:
    var nbytes = bytes_per_256 * super_blocks
    var elements = 256 * super_blocks
    var data = alloc[UInt8](nbytes)
    var outp = alloc[Float16](elements)
    var grid = alloc[UInt16](2048)
    var state = seed
    for i in range(nbytes):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        data.unsafe_store(i, UInt8((state >> 8) & 0xFF))
    if kind == 29:
        for sb in range(super_blocks):
            var bb = sb * bytes_per_256 + 48
            for j in range(8):
                data.unsafe_store(bb + j, UInt8(0))
            data.unsafe_store(bb + 5, UInt8(224))
            data.unsafe_store(bb + 7, UInt8(48))
    elif kind == 20:
        for b in range(super_blocks * 8):
            data.unsafe_store(b * 18, UInt8(0))
            data.unsafe_store(b * 18 + 1, UInt8(62))
    else:
        for sb in range(super_blocks):
            data.unsafe_store(sb * bytes_per_256, UInt8(0))
            data.unsafe_store(sb * bytes_per_256 + 1, UInt8(62))
    iq_grid_materialize(kind, grid)
    # settle
    run_blocks(kind, data, nbytes, outp, elements)
    var sink = Float32(0.0)
    for i in range(elements):
        sink += iq_value_g(data, 0, kind, grid, i)
    var scalar_times = List[Float64]()
    var simd_times = List[Float64]()
    for _ in range(5):
        var t0 = monotonic_ns()
        for i in range(elements):
            outp.unsafe_store(i, iq_value_g(data, 0, kind, grid, i).cast[DType.float16]())
        var t1 = monotonic_ns()
        scalar_times.append(Float64(t1 - t0) / Float64(elements))
        var t2 = monotonic_ns()
        run_blocks(kind, data, nbytes, outp, elements)
        var t3 = monotonic_ns()
        simd_times.append(Float64(t3 - t2) / Float64(elements))
    var sc = median_of(scalar_times)
    var sd = median_of(simd_times)
    print(
        name,
        "scalar_ns_per_elem=",
        sc,
        "simd_ns_per_elem=",
        sd,
        "speedup=",
        sc / sd,
        "sink=",
        sink,
    )
    data.unsafe_free()
    outp.unsafe_free()
    grid.unsafe_free()


def main() raises:
    var blocks = 2048
    bench_format("IQ1_S", 19, 50, blocks, 101)
    bench_format("IQ1_M", 29, 56, blocks, 202)
    bench_format("IQ2_XXS", 16, 66, blocks, 303)
    bench_format("IQ2_XS", 17, 74, blocks, 404)
    bench_format("IQ2_S", 22, 82, blocks, 505)
    bench_format("IQ3_XXS", 18, 98, blocks, 606)
    bench_format("IQ3_S", 21, 110, blocks, 707)
    bench_format("IQ4_NL", 20, 144, blocks, 808)
    bench_format("IQ4_XS", 23, 136, blocks, 909)
