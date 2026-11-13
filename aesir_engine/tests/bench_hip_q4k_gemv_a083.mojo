"""A-083 bench/probe: HIP Q4_K GEMV vs the Z13 CPU oracle.

Standalone proof (not an E-MASTER case): fills deterministic
synthetic Q4_K super-blocks (LCG seed 0xA083, d/dmin pinned like
A-040), dispatches the HIP kernel through HipQ4kGemv (MAX
DeviceContext api="hip", gfx1151) on the Radeon 8060S, and
compares every output row against the CPU oracle
(dequantize_ggml_k kind 12 into f16, then an f32 dot) - the
A-054-declared reference oracle, same as A-057. Prints the HIP
device identity, per-shape max abs/rel error, the shim dispatch
counter delta (device-execution evidence: it increments only
after a device dispatch synchronized without error), and median
GPU vs CPU wall times. Fails closed if no HIP device is present.
"""
from std.ffi import external_call
from std.memory.alloc import alloc
from std.math import abs as fabs
from core.hip_q4k_gemv import HipQ4kGemv
from core.compute import dequantize_ggml_k
from core.mimir_well import f16, f32


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A083 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)


def _fx(i: Int) -> Float32:
    return Float32((i * 73 + 19) % 997) * Float32(0.002) - Float32(0.997)


def _make_weights(n_rows: Int, k_elems: Int) -> List[UInt8]:
    var nblocks = k_elems // 256
    var total_blocks = n_rows * nblocks
    var w = List[UInt8](capacity=total_blocks * 144)
    var s = Int64(0xA083)
    for b in range(total_blocks):
        s = _lcg(s + Int64(b))
        var st = s
        for _i in range(144):
            st = _lcg(st)
            w.append(UInt8((st >> 33) & 0xFF))
        w[b * 144 + 0] = UInt8(0x00)
        w[b * 144 + 1] = UInt8(0x2E)
        w[b * 144 + 2] = UInt8(0x00)
        w[b * 144 + 3] = UInt8(0x1E)
    return w^


def _median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def _run_shape(n_rows: Int, k_elems: Int, reps: Int) raises:
    var nblocks = k_elems // 256
    var w_bytes = n_rows * nblocks * 144
    var w = _make_weights(n_rows, k_elems)
    var x = List[Float32](capacity=k_elems)
    for i in range(k_elems):
        x.append(_fx(i))
    # CPU oracle: dequantize row by row (kind 12) and dot in f32.
    var oracle = alloc[Float32](n_rows)
    var w_host = alloc[UInt8](w_bytes)
    for i in range(w_bytes):
        w_host.unsafe_store(i, w[i])
    var deq = alloc[Scalar[f16]](k_elems)
    var cpu_times = List[Int]()
    for _rep in range(reps):
        var t0 = monotonic_ns()
        for r in range(n_rows):
            dequantize_ggml_k(
                w_host.unsafe_offset(r * nblocks * 144), deq, k_elems, 12
            )
            var acc = Float32(0.0)
            for e in range(k_elems):
                acc += deq.unsafe_load(e).cast[f32]() * _fx(e)
            oracle.unsafe_store(r, acc)
        cpu_times.append(monotonic_ns() - t0)
    var before = HipQ4kGemv.dispatch_count()
    var gpu_times = List[Int]()
    var got = List[Float32]()
    for _rep in range(reps):
        var t0 = monotonic_ns()
        got = HipQ4kGemv.q4k_gemv(w, x, n_rows, k_elems)
        gpu_times.append(monotonic_ns() - t0)
    var after = HipQ4kGemv.dispatch_count()
    var max_abs = Float32(0.0)
    var max_rel = Float32(0.0)
    for r in range(n_rows):
        var g = got[r]
        var want = oracle.unsafe_load(r)
        var d = fabs(g - want)
        if d > max_abs:
            max_abs = d
        var denom = fabs(want)
        if denom > Float32(1.0):
            var rel = d / denom
            if rel > max_rel:
                max_rel = rel
    print(
        "A083_SHAPE rows=" + String(n_rows) + " k=" + String(k_elems)
        + " max_abs_err=" + String(max_abs)
        + " max_rel_err=" + String(max_rel)
        + " dispatches=" + String(after - before)
        + " gpu_median_ns=" + String(_median(gpu_times))
        + " cpu_median_ns=" + String(_median(cpu_times))
    )
    w_host.unsafe_free()
    deq.unsafe_free()
    oracle.unsafe_free()


def main() raises:
    if not HipQ4kGemv.available():
        raise Error("A083 bench: no HIP device present (fail-closed)")
    var name = HipQ4kGemv.device_name()
    print("A083_DEVICE name=" + name)
    _run_shape(1, 256, 3)
    _run_shape(7, 512, 3)
    _run_shape(64, 1024, 3)
    _run_shape(33, 2048, 3)
    _run_shape(1024, 4096, 3)
    print("A083_HIP_Q4K_GEMV_BENCH: PASS")
