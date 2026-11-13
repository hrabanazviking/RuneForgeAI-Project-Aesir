"""A-082 bench / probe driver: HIP Q8_0 GEMV on gfx1151.

Standalone driver (not a suite case): prints the A-010 gate
identity, a parity spot check vs the sequential CPU oracle,
and HIP vs CPU-sequential timings at decode shapes. Run with
the staged shims exactly like run_all (see its header), e.g.:
  pixi run mojo run -I . --target-accelerator gfx1151 -Xlinker
  -L$staging -Xlinker -laesir_hip ... bench_hip_q8_gemv_a082.mojo
"""
from std.collections import InlineArray
from std.ffi import external_call
from std.memory import bitcast
from core.amd_gate import AMDGate
from core.hip_gemv import HipGemv
from core.hip_memory import HipMemory


def _monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A082 bench: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


struct _Lcg:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = self.state * 6364136223846793005 + 1442695040888963407
        return self.state >> 11

    def byte(mut self) -> UInt8:
        return UInt8(self.next() & 0xFF)

    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _make(rows: Int, cols: Int) -> Tuple[List[UInt8], List[Float32]]:
    var blocks = cols // 32
    var w = List[UInt8](capacity=rows * blocks * 34)
    for _ in range(rows * blocks * 34):
        w.append(UInt8(0))
    var lcg = _Lcg(0xA082)
    var xs = List[Float32](capacity=cols)
    for _ in range(cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    for blk in range(rows * blocks):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        var bits = bitcast[DType.uint16](Float16(s))
        w[blk * 34] = UInt8(bits & 0xFF)
        w[blk * 34 + 1] = UInt8((bits >> 8) & 0xFF)
        for lane in range(32):
            w[blk * 34 + 2 + lane] = lcg.byte()
    return (w^, xs^)


def _cpu_oracle(w: List[UInt8], xs: List[Float32], rows: Int, cols: Int) -> List[Float32]:
    var blocks = cols // 32
    var out = List[Float32](capacity=rows)
    for r in range(rows):
        var acc: Float32 = 0.0
        for blk in range(blocks):
            var gblk = r * blocks + blk
            var bits = UInt16(w[gblk * 34]) | (UInt16(w[gblk * 34 + 1]) << 8)
            var scale = bitcast[DType.float16](bits).cast[DType.float32]()
            for lane in range(32):
                var raw = Int(w[gblk * 34 + 2 + lane])
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * xs[blk * 32 + lane]
        out.append(acc)
    return out^


def _bench_shape(rows: Int, cols: Int, hip_iters: Int, cpu_iters: Int) raises:
    var fx = _make(rows, cols)
    var w = fx[0].copy()
    var xs = fx[1].copy()
    var want = _cpu_oracle(w, xs, rows, cols)
    var got = HipGemv.q8_0_gemv(w, xs, rows, cols)
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var d = got[r] - want[r]
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    var w_bytes = Float64(rows * (cols // 32) * 34)
    var t0 = _monotonic_ns()
    for _ in range(hip_iters):
        _ = HipGemv.q8_0_gemv(w, xs, rows, cols)
    var hip_ms = Float64(_monotonic_ns() - t0) / 1000000.0 / Float64(hip_iters)
    var t2 = _monotonic_ns()
    _ = HipGemv.q8_0_gemv_repeated(w, xs, rows, cols, hip_iters)
    var hip_rep_ms = Float64(_monotonic_ns() - t2) / 1000000.0 / Float64(hip_iters)
    var t1 = _monotonic_ns()
    for _ in range(cpu_iters):
        _ = _cpu_oracle(w, xs, rows, cols)
    var cpu_ms = Float64(_monotonic_ns() - t1) / 1000000.0 / Float64(cpu_iters)
    print(
        "A082_BENCH rows=", rows, " cols=", cols,
        " max_abs=", max_abs,
        " hip_ms_per_gemv=", hip_ms,
        " hip_GiBps=", w_bytes / (hip_ms / 1000.0) / 1073741824.0,
        " hip_repeated_ms_per_gemv=", hip_rep_ms,
        " hip_repeated_GiBps=", w_bytes / (hip_rep_ms / 1000.0) / 1073741824.0,
        " cpu_ms_per_gemv=", cpu_ms,
        " cpu_GiBps=", w_bytes / (cpu_ms / 1000.0) / 1073741824.0,
    )


def main() raises:
    print("A082 gate: hip_runtime_available=", HipMemory.runtime_available())
    print("A082 gate: hip_device_count=", HipMemory.device_count())
    var props = AMDGate.get_device_properties(0)
    print("A082 gate: device_name=", props.name)
    print("A082 gate: gfx_arch=", props.gfx_arch, " plausible=", props.plausible())
    print("A082 gate: mojo_device_name=", HipGemv.device_name())
    print("A082 gate: gate_ok=", HipGemv.gate_ok())
    if not HipGemv.gate_ok():
        raise Error("A082 bench: HIP gate not satisfied on this host")
    var before = HipGemv.dispatch_count()
    _bench_shape(512, 4096, 20, 3)
    _bench_shape(64, 1024, 20, 3)
    _bench_shape(37, 320, 20, 3)
    print("A082 dispatches_in_bench=", HipGemv.dispatch_count() - before)
    print("A082_BENCH_DONE")
