"""Vulkan batched GEMM for prefill (A-068): batched matrix
kernels for prompt processing, dispatched on the GPU through the
A-014/A-015 Vulkan context, judged against the Z13 CPU oracle
(the A-054 gate declared the CPU path the campaign's reference
oracle).

The kernels generalise the A-056 Q8_0 GEMV and the A-055
gemv_f32 to a token batch: Y[t, r] = sum_k W[r, k] * X[t, k] in
ONE dispatch for the whole prompt, where looping the GEMV per
token would re-read and re-dequantise the whole weight matrix
per token.

Parity discipline (raw-oracle):
- GPU Float32 outputs vs a sequential Float32 CPU oracle in this
  file that consumes the identical raw Q8_0 bytes with the
  identical math the engine's CPU body uses (per-block fp16
  scale x int8 x activation, summed in k order), independently
  for every token row. The GPU reduces in tree order, so the
  filed tolerance is an accumulation-order bound, not a dequant
  bound: max_abs is printed for the ledger and asserted below
  the filed A-068 bound.
- Batch independence: a tokens == T dispatch must reproduce,
  bit for bit, the T tokens == 1 dispatches of the same kernel
  (each (row, token) workgroup runs identical math), and the
  tokens == 1 Q8 dispatch must reproduce the A-056 GEMV output
  bit for bit (identical reduction in both shaders).
- Known value: one block, scale 0.25, q = i-16, x = (t+1) gives
  exactly -4 * (t+1) per token (mirrors the A-038/A-056 case).

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and the shim dispatch counters must
advance by exactly the number of dispatches performed. On a
host without that device the cases assert fail-closed
behaviour and pass as honest-absent, matching A-014/A-015
discipline. No host fallback exists in the gateway: nothing is
computed on the CPU when the device path fails.
"""
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.vulkan_gemm import VulkanGemm


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


struct _Lcg:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def byte(mut self) -> UInt8:
        return UInt8(self.next() & 0xFF)

    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _q8_fixture(
    rows: Int, cols: Int, tokens: Int, seed: UInt64
) raises -> Tuple[VulkanAllocation, VulkanAllocation, List[Float32]]:
    """Build one deterministic Q8_0 weight + batched activation
    fixture (A-056 LCG discipline, extended per token). Returns
    (w_alloc, x_alloc, xs) with xs the flat [tokens][cols]
    activations."""
    var blocks_per_row = cols // 32
    var w_alloc = VulkanBuffers.allocate(rows * blocks_per_row * 34)
    var x_alloc = VulkanBuffers.allocate(tokens * cols * 4)
    var lcg = _Lcg(seed)
    var xs = List[Float32]()
    for _ in range(tokens * cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w_alloc)
    for blk in range(rows * blocks_per_row):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        pw.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            pw.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(tokens * cols):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    return (w_alloc, x_alloc, xs^)


def _q8_gemm_run(
    w_alloc: VulkanAllocation,
    x_alloc: VulkanAllocation,
    rows: Int,
    cols: Int,
    tokens: Int,
) raises -> List[Float32]:
    var y_alloc = VulkanBuffers.allocate(tokens * rows * 4)
    var py = VulkanBuffers.map(y_alloc)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(tokens * rows):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y_alloc)
    VulkanGemm.q8_0_gemm(w_alloc, x_alloc, y_alloc, rows, cols, tokens)
    var out = List[Float32]()
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    for i in range(tokens * rows):
        out.append(gy.unsafe_load(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(y_alloc)
    return out^


def _q8_oracle_max_abs(
    w_alloc: VulkanAllocation,
    xs: List[Float32],
    got: List[Float32],
    rows: Int,
    cols: Int,
    tokens: Int,
) raises -> Float32:
    """Sequential Float32 CPU oracle over the identical raw
    Q8_0 bytes, per token; returns the max abs delta."""
    var blocks_per_row = cols // 32
    var qw = VulkanBuffers.map(w_alloc)
    var max_abs: Float32 = 0.0
    for t in range(tokens):
        for r in range(rows):
            var acc: Float32 = 0.0
            for blk in range(blocks_per_row):
                var base = (r * blocks_per_row + blk) * 34
                var scale = qw.unsafe_bitcast[Float16]().unsafe_load(
                    (r * blocks_per_row + blk) * 17
                ).cast[DType.float32]()
                for lane in range(32):
                    var raw = Int(qw.unsafe_load(base + 2 + lane))
                    var q = raw - 256 if raw >= 128 else raw
                    acc += scale * Float32(q) * xs[t * cols + blk * 32 + lane]
            var d = got[t * rows + r] - acc
            if d < 0:
                d = -d
            if d > max_abs:
                max_abs = d
    VulkanBuffers.unmap(w_alloc)
    return max_abs


def _q8_shape_parity(rows: Int, cols: Int, tokens: Int) raises -> Float32:
    var fx = _q8_fixture(rows, cols, tokens, 0xA068)
    var w_alloc = fx[0]
    var x_alloc = fx[1]
    var xs = fx[2].copy()
    var got = _q8_gemm_run(w_alloc, x_alloc, rows, cols, tokens)
    var max_abs = _q8_oracle_max_abs(w_alloc, xs, got, rows, cols, tokens)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    print(
        "A068_Q8_SHAPE rows=", rows, " cols=", cols, " tokens=", tokens,
        " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def test_vulkan_prefill_gemm_oracle_parity() raises:
    print("--- Testing Vulkan Q8_0 GEMM oracle parity (A-068) ---")
    if not _vk_present():
        var rejected = False
        try:
            var a = VulkanBuffers.allocate(4096)
            VulkanBuffers.free(a)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but allocate succeeded (fabricated)")
        print("Vulkan UNAVAILABLE: GEMM fail-closed: PASS (honest-absent)")
        return
    var shapes_r = [16, 37, 64, 13, 32]
    var shapes_c = [288, 320, 1024, 64, 256]
    var shapes_t = [8, 13, 32, 1, 64]
    var worst: Float32 = 0.0
    for s in range(len(shapes_r)):
        var m = _q8_shape_parity(shapes_r[s], shapes_c[s], shapes_t[s])
        if m > worst:
            worst = m
    # Filed A-068 bound: accumulation-order only (GPU tree vs
    # CPU sequential, both Float32, identical dequant) - the
    # A-056 GEMV bound for the identical reduction. Measured
    # worst is filed in hidden_files/A068_LEDGER.md.
    if worst > Float32(0.001):
        raise Error(
            "Q8_0 GEMM oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan Q8_0 GEMM oracle parity (5 batched shapes incl."
        " tokens=1..64, K=288 stories scale and K=1024, RADV"
        " device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_prefill_gemm_known_value() raises:
    print("--- Testing Vulkan Q8_0 GEMM known value (A-068) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value case not run (honest-absent)")
        return
    var tokens = 4
    var w_alloc = VulkanBuffers.allocate(34)
    var x_alloc = VulkanBuffers.allocate(tokens * 32 * 4)
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(34):
        pw.unsafe_store(i, UInt8(0))
    pw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    for i in range(32):
        pw.unsafe_store(2 + i, UInt8(i - 16))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for t in range(tokens):
        for i in range(32):
            fx.unsafe_store(t * 32 + i, Float32(t + 1))
    VulkanBuffers.unmap(x_alloc)
    var got = _q8_gemm_run(w_alloc, x_alloc, 1, 32, tokens)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    for t in range(tokens):
        var want = Float32(-4.0) * Float32(t + 1)
        if got[t] != want:
            raise Error(
                "Q8_0 GEMM known-value mismatch at token " + String(t)
                + ": got " + String(got[t]) + " want " + String(want)
            )
    print("Vulkan Q8_0 GEMM known value (tokens=4, scale 0.25, q=i-16, x=t+1 -> -4*(t+1) exact): PASS")


def test_vulkan_prefill_gemm_f32_parity() raises:
    print("--- Testing Vulkan F32 GEMM oracle parity (A-068) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: F32 parity case not run (honest-absent)")
        return
    var shapes_r = [32, 17, 64]
    var shapes_c = [256, 288, 1024]
    var shapes_t = [16, 7, 32]
    var worst: Float32 = 0.0
    for s in range(len(shapes_r)):
        var rows = shapes_r[s]
        var cols = shapes_c[s]
        var tokens = shapes_t[s]
        var w_alloc = VulkanBuffers.allocate(rows * cols * 4)
        var x_alloc = VulkanBuffers.allocate(tokens * cols * 4)
        var y_alloc = VulkanBuffers.allocate(tokens * rows * 4)
        var lcg = _Lcg(0xA068 + UInt64(s))
        var ws = List[Float32]()
        for _ in range(rows * cols):
            ws.append(lcg.unit() * Float32(2.0) - Float32(1.0))
        var xs = List[Float32]()
        for _ in range(tokens * cols):
            xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
        var pw = VulkanBuffers.map(w_alloc)
        var fw = pw.unsafe_bitcast[Float32]()
        for i in range(rows * cols):
            fw.unsafe_store(i, ws[i])
        VulkanBuffers.unmap(w_alloc)
        var px = VulkanBuffers.map(x_alloc)
        var fx2 = px.unsafe_bitcast[Float32]()
        for i in range(tokens * cols):
            fx2.unsafe_store(i, xs[i])
        VulkanBuffers.unmap(x_alloc)
        VulkanGemm.f32_gemm(w_alloc, x_alloc, y_alloc, rows, cols, tokens)
        var qy = VulkanBuffers.map(y_alloc)
        var gy = qy.unsafe_bitcast[Float32]()
        var max_abs: Float32 = 0.0
        for t in range(tokens):
            for r in range(rows):
                var acc: Float32 = 0.0
                for k in range(cols):
                    acc += ws[r * cols + k] * xs[t * cols + k]
                var d = gy.unsafe_load(t * rows + r) - acc
                if d < 0:
                    d = -d
                if d > max_abs:
                    max_abs = d
        VulkanBuffers.unmap(y_alloc)
        VulkanBuffers.free(w_alloc)
        VulkanBuffers.free(x_alloc)
        VulkanBuffers.free(y_alloc)
        print(
            "A068_F32_SHAPE rows=", rows, " cols=", cols,
            " tokens=", tokens, " cpu_oracle_max_abs=", max_abs,
        )
        if max_abs > worst:
            worst = max_abs
    # Filed A-068 F32 bound: accumulation-order only (GPU tree
    # vs CPU sequential, both Float32, dense operands).
    if worst > Float32(0.001):
        raise Error(
            "F32 GEMM oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan F32 GEMM oracle parity (3 batched shapes, RADV"
        " device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_prefill_gemm_batch_independence() raises:
    print("--- Testing Vulkan GEMM batch independence (A-068) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: batch independence not run (honest-absent)")
        return
    var rows = 24
    var cols = 256
    var tokens = 8
    var fx = _q8_fixture(rows, cols, tokens, 0xB068)
    var w_alloc = fx[0]
    var x_alloc = fx[1]
    var batched = _q8_gemm_run(w_alloc, x_alloc, rows, cols, tokens)
    # Each token alone through the same GEMM (tokens == 1 on a
    # per-token activation slice) must match bit for bit.
    for t in range(tokens):
        var xt_alloc = VulkanBuffers.allocate(cols * 4)
        var px = VulkanBuffers.map(xt_alloc)
        var fx1 = px.unsafe_bitcast[Float32]()
        var qx = VulkanBuffers.map(x_alloc)
        var gx = qx.unsafe_bitcast[Float32]()
        for i in range(cols):
            fx1.unsafe_store(i, gx.unsafe_load(t * cols + i))
        VulkanBuffers.unmap(x_alloc)
        VulkanBuffers.unmap(xt_alloc)
        var single = _q8_gemm_run(w_alloc, xt_alloc, rows, cols, 1)
        VulkanBuffers.free(xt_alloc)
        for r in range(rows):
            if single[r] != batched[t * rows + r]:
                raise Error(
                    "GEMM batch dependence at token " + String(t)
                    + " row " + String(r) + ": batched "
                    + String(batched[t * rows + r]) + " vs single "
                    + String(single[r])
                )
    # And the tokens == 1 GEMM must match the A-056 GEMV on the
    # first token's activations bit for bit (identical reduction
    # in both shaders).
    var y_alloc = VulkanBuffers.allocate(rows * 4)
    VulkanGemv.q8_0_gemv(w_alloc, x_alloc, y_alloc, rows, cols)
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    for r in range(rows):
        if gy.unsafe_load(r) != batched[r]:
            raise Error(
                "GEMM tokens=1 differs from GEMV at row " + String(r)
                + ": gemm " + String(batched[r]) + " vs gemv "
                + String(gy.unsafe_load(r))
            )
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(y_alloc)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    print("Vulkan GEMM batch independence (tokens=8 joint == 8x tokens=1 bitwise; tokens=1 == A-056 GEMV bitwise): PASS")


def test_vulkan_prefill_gemm_rejection() raises:
    print("--- Testing Vulkan GEMM rejection (A-068) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var w = VulkanBuffers.allocate(2 * 34)
    var x = VulkanBuffers.allocate(64 * 4)
    var y = VulkanBuffers.allocate(4 * 4)
    var xb = VulkanBuffers.allocate(8 * 64 * 4)
    var zero_tokens = False
    try:
        VulkanGemm.q8_0_gemm(w, xb, y, 1, 64, 0)
    except:
        zero_tokens = True
    if not zero_tokens:
        raise Error("q8_0_gemm accepted a zero token count")
    var zero_rows = False
    try:
        VulkanGemm.q8_0_gemm(w, xb, y, 0, 64, 8)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q8_0_gemm accepted a zero row count")
    var bad_cols = False
    try:
        VulkanGemm.q8_0_gemm(w, xb, y, 1, 48, 8)
    except:
        bad_cols = True
    if not bad_cols:
        raise Error("q8_0_gemm accepted cols=48 (not a Q8_0 block multiple)")
    var oversize = False
    try:
        VulkanGemm.q8_0_gemm(w, xb, y, 2, 64, 8)
    except:
        oversize = True
    if not oversize:
        raise Error("q8_0_gemm accepted a batched shape beyond the output buffer")
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanGemm.q8_0_gemm(bogus, xb, y, 1, 64, 8)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("q8_0_gemm accepted a bogus weight buffer id")
    var f32_zero_tokens = False
    try:
        VulkanGemm.f32_gemm(w, xb, y, 1, 64, 0)
    except:
        f32_zero_tokens = True
    if not f32_zero_tokens:
        raise Error("f32_gemm accepted a zero token count")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    VulkanBuffers.free(xb)
    print("Vulkan GEMM rejection (zero tokens, zero rows, cols=48, oversize batch, bogus id, f32 zero tokens): PASS")


def test_vulkan_prefill_gemm_dispatch_evidence() raises:
    print("--- Testing Vulkan GEMM dispatch evidence (A-068) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var q8_before = VulkanGemm.q8_dispatch_count()
    var f32_before = VulkanGemm.f32_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _q8_shape_parity(8, 256, 16)
    _ = _q8_shape_parity(8, 256, 16)
    var w_alloc = VulkanBuffers.allocate(8 * 8 * 4)
    var x_alloc = VulkanBuffers.allocate(16 * 8 * 4)
    var y_alloc = VulkanBuffers.allocate(16 * 8 * 4)
    VulkanGemm.f32_gemm(w_alloc, x_alloc, y_alloc, 8, 8, 16)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(y_alloc)
    var q8_after = VulkanGemm.q8_dispatch_count()
    var f32_after = VulkanGemm.f32_dispatch_count()
    if q8_after - q8_before != 2:
        raise Error(
            "q8 gemm dispatch counter advanced by "
            + String(q8_after - q8_before)
            + " for 2 dispatches (device-execution evidence broken)"
        )
    if f32_after - f32_before != 1:
        raise Error(
            "f32 gemm dispatch counter advanced by "
            + String(f32_after - f32_before)
            + " for 1 dispatch (device-execution evidence broken)"
        )
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("gemm loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("gemm loop leaked buffers")
    print(
        "Vulkan GEMM dispatch evidence (q8 counter +2, f32"
        " counter +1, accounting exact): PASS"
    )
