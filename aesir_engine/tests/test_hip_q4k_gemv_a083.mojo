"""HIP Q4_K GEMV (A-083): dequant + single-row (batch-1) GEMV on
the Radeon 8060S through the HIP road (MAX DeviceContext,
api="hip", the A-029 Mojo-native path via core/hip_q4k_gemv.mojo),
judged against the same Z13 CPU oracle as the A-057 Vulkan slice:
dequantize_ggml_k kind 12 (the banked A-040 SIMD path) into f16,
then an f32 dot with the input vector. Acceptance is the A-082
discipline via the A-010-A-012 HIP gate: CPU-oracle parity plus
device-execution evidence.

The HIP kernel decodes Q4_K super-blocks in f32 and never rounds
the weights to f16, while the CPU oracle does round them; parity
is therefore judged at the A-057 filed tolerance (the
f16-rounding band), never bit-exactness: per output row,
|got - want| <= 0.02 * sqrt(K) + 0.02 * |want|.

Device-execution evidence (law 6): on purpleraider a HIP device
must be present (MojoNative gate), its name is printed, and the
hip-shim dispatch counter - incremented by the launcher only
after the device context synchronized without error - must rise
by exactly the number of calls. There is no host fallback in the
path: with the device hidden the context raises (A-029). On a
host without a HIP device the cases assert fail-closed behaviour
and pass as honest-absent.

Fixtures are deterministic synthetic Q4_K super-blocks (LCG seed
0xA083, d/dmin pinned to the A-040 values, same construction as
A-057), byte-reproducible from this source alone.
"""
from std.memory.alloc import alloc
from std.math import abs as fabs, sqrt
from core.hip_q4k_gemv import HipQ4kGemv
from core.hip_memory import HipMemory
from core.compute import dequantize_ggml_k
from core.mimir_well import f16, f32


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


def _make_x(k_elems: Int) -> List[Float32]:
    var x = List[Float32](capacity=k_elems)
    for i in range(k_elems):
        x.append(_fx(i))
    return x^


def _run_gemv(n_rows: Int, k_elems: Int) raises -> List[Float32]:
    var w = _make_weights(n_rows, k_elems)
    var x = _make_x(k_elems)
    var before = HipQ4kGemv.dispatch_count()
    var got_list = HipQ4kGemv.q4k_gemv(w, x, n_rows, k_elems)
    var after = HipQ4kGemv.dispatch_count()
    if after != before + 1:
        raise Error("A-083 dispatch counter did not rise by exactly 1")
    if len(got_list) != n_rows:
        raise Error("A-083 Q4_K GEMV output size mismatch")
    # CPU oracle: dequantize row by row (kind 12) into f16, dot f32.
    var nblocks = k_elems // 256
    var w_bytes = n_rows * nblocks * 144
    var w_host = alloc[UInt8](w_bytes)
    for i in range(w_bytes):
        w_host.unsafe_store(i, w[i])
    var deq = alloc[Scalar[f16]](k_elems)
    for r in range(n_rows):
        dequantize_ggml_k(
            w_host.unsafe_offset(r * nblocks * 144), deq, k_elems, 12
        )
        var want = Float32(0.0)
        for e in range(k_elems):
            want += deq.unsafe_load(e).cast[f32]() * _fx(e)
        var got = got_list[r]
        var tol = Float32(0.02) * sqrt(Float32(k_elems)) + Float32(0.02) * fabs(want)
        if fabs(got - want) > tol:
            w_host.unsafe_free()
            deq.unsafe_free()
            raise Error(
                "A-083 Q4_K GEMV mismatch rows=" + String(n_rows)
                + " k=" + String(k_elems) + " row " + String(r)
                + ": got " + String(got) + " want " + String(want)
            )
    w_host.unsafe_free()
    deq.unsafe_free()
    return got_list^


def test_hip_q4k_gemv_oracle() raises:
    print("--- Testing HIP Q4_K GEMV oracle (A-083) ---")
    if not HipQ4kGemv.available():
        var rejected = False
        var w = _make_weights(1, 256)
        var x = _make_x(256)
        try:
            _ = HipQ4kGemv.q4k_gemv(w, x, 1, 256)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but q4k_gemv succeeded (fabricated)")
        print("HIP UNAVAILABLE: Q4_K GEMV fail-closed: PASS (honest-absent)")
        return
    var name = HipQ4kGemv.device_name()
    if name.byte_length() == 0:
        raise Error("HIP device name empty on a live device")
    print("A083_DEVICE name=" + name)
    _ = _run_gemv(1, 256)
    _ = _run_gemv(7, 512)
    _ = _run_gemv(64, 1024)
    _ = _run_gemv(33, 2048)
    print(
        "HIP Q4_K GEMV (rows/k = 1/256, 7/512, 64/1024, 33/2048;"
        " HIP dequant+GEMV vs Z13 CPU oracle within filed"
        " f16-rounding tolerance, dispatch counter +1 per call,"
        " HIP device): PASS"
    )


def test_hip_q4k_gemv_rejection() raises:
    print("--- Testing HIP Q4_K GEMV rejection (A-083) ---")
    # Shape errors raise before any device work, on every host.
    var w = _make_weights(1, 256)
    var x = _make_x(256)
    var zero_rows = False
    try:
        _ = HipQ4kGemv.q4k_gemv(w, x, 0, 256)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q4k_gemv accepted zero rows")
    var zero_k = False
    try:
        _ = HipQ4kGemv.q4k_gemv(w, x, 1, 0)
    except:
        zero_k = True
    if not zero_k:
        raise Error("q4k_gemv accepted a zero element count")
    var ragged_k = False
    try:
        _ = HipQ4kGemv.q4k_gemv(w, x, 1, 128)
    except:
        ragged_k = True
    if not ragged_k:
        raise Error("q4k_gemv accepted a non-super-block element count")
    var short_w = False
    try:
        _ = HipQ4kGemv.q4k_gemv(w, x, 2, 256)
    except:
        short_w = True
    if not short_w:
        raise Error("q4k_gemv accepted a shape beyond the weight operand")
    var short_x = False
    var x_small = _make_x(128)
    try:
        _ = HipQ4kGemv.q4k_gemv(w, x_small, 1, 256)
    except:
        short_x = True
    if not short_x:
        raise Error("q4k_gemv accepted an undersized activation operand")
    print(
        "HIP Q4_K GEMV rejection (zero rows, zero k, ragged k,"
        " oversize shape, undersized activation): PASS"
    )


def test_hip_q4k_gemv_no_leak() raises:
    print("--- Testing HIP Q4_K GEMV no-leak (A-083) ---")
    if not HipQ4kGemv.available():
        print("HIP UNAVAILABLE: no-leak case not run (honest-absent)")
        return
    # Warm up first (A-011 contract): the HIP runtime and the MAX
    # DeviceContext arena reserve their one-time blocks on first
    # use; the leak claim is judged only after warm-up.
    var first = _run_gemv(4, 256)
    var base = HipMemory.mem_info()
    var before = HipQ4kGemv.dispatch_count()
    for _ in range(50):
        var out = _run_gemv(4, 256)
        for r in range(4):
            if out[r] != first[r]:
                raise Error("HIP Q4_K GEMV repeat run diverged (nondeterministic)")
    var after = HipQ4kGemv.dispatch_count()
    if after != before + 50:
        raise Error("HIP Q4_K GEMV dispatch counter did not rise by 50")
    var now = HipMemory.mem_info()
    # Per-context runtime retention, characterized by probe (see
    # hidden_files/A083_LEDGER.md): on this pinned toolchain every
    # buffer-bearing MAX DeviceContext retains exactly 8 MiB of
    # GTT (8,388,608 bytes) until process exit - the A-029/A-079
    # process-lifetime arena family, shared by MojoNative.vec_add
    # and by bare buffer+copy contexts (attr probe), and NOT
    # operand memory (this case's operands are ~2.4 KB per call).
    # The slice-level leak claim is therefore exact: retention
    # over the 50 calls must equal 50 x that constant - a real
    # operand leak on top would break the equality.
    var retention = base.free_bytes - now.free_bytes
    if retention != 50 * 8388608:
        raise Error(
            "HIP Q4_K GEMV loop retention " + String(retention)
            + " != 50 x 8388608 (filed MAX per-context constant):"
            " slice-attributable leak or runtime behaviour change"
        )
    print(
        "HIP Q4_K GEMV no-leak (50 dispatches at rows=4 k=256,"
        " outputs bit-identical across repeats, hipMemGetInfo"
        " retention exactly 50 x 8 MiB filed MAX per-context"
        " constant - zero slice-attributable bytes, counter"
        " +50): PASS"
    )
