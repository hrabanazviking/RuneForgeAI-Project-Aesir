# core/hip_gemv.mojo
# HipGemv: HIP Q8_0 GEMV gateway (slice A-082).
#
# Dequant + single-row GEMV executed on the Radeon 8060S
# (gfx1151) by a Mojo-native kernel launched through MAX
# DeviceContext(api="hip") - the A-029 proven HIP kernel road -
# gated by the A-010-A-012 HIP gate: AMDGate device properties
# (exactly one device, gfx_arch == gfx1151, plausible record)
# plus the HipMemory runtime probe. The kernel consumes the raw
# GGUF Q8_0 byte layout - per row, blocks of one fp16 scale +
# 32 int8 values (34 bytes) - plus a Float32 activation vector,
# and writes one Float32 per row. Byte extraction and the fp16
# scale decode run in-kernel, so the dequant itself is GPU
# work; nothing is dequantized on the host.
#
# Kernel shape: one thread per output row, accumulating in
# sequential k order in Float32 (the A-075 accumulation law).
# This deliberately uses only the kernel shapes A-029 proved
# (one output per thread, no shared memory / barriers /
# subgroup ops); the A-085 bake-off judges speed against the
# Vulkan road, this slice claims parity + real execution.
#
# Fail-closed contract (matches A-011/A-029/A-056): when the
# HIP runtime or the gfx1151 device is unavailable - or the
# device identity is anything else - every operation raises;
# no host fallback is fabricated. Column counts must be
# positive multiples of the 32-wide Q8_0 block and the operand
# lists must cover the full shape; violations raise before any
# device work. dispatch_count() reads the hip shim counter
# that the launcher increments only after the kernel launch +
# device synchronize completed - the filed device-execution
# Per-call cost note (measured in the A-082 bench, filed in
# the ledger): creating a DeviceContext per call costs
# ~13-16 ms on this stack, so q8_0_gemv_repeated() reuses one
# context across dispatches - the decode-loop shape.
# evidence (law 6), triangulated with the A-029 evidence class
# (arch-specific gfx1151 code object; hidden-device runs raise
# hipErrorNoDevice upstream of this gateway).

from std.ffi import external_call
from std.gpu import global_idx
from std.memory import Pointer
from core.amd_gate import AMDGate
from core.hip_memory import HipMemory
from core.mojo_gpu_target import MojoNative
from max.gpu.host import DeviceContext


def _hip_q8_gemv_kernel[
    w_origin: Origin[mut=False],
    x_origin: Origin[mut=False],
    y_origin: MutOrigin,
](
    w: Pointer[Scalar[DType.uint8], w_origin],
    x: Pointer[Scalar[DType.float32], x_origin],
    y: Pointer[Scalar[DType.float32], y_origin],
    rows: Int32,
    cols: Int32,
):
    var row = Int(global_idx.x)
    if row < Int(rows):
        var blocks = Int(cols) // 32
        var wf = w.unsafe_bitcast[Scalar[DType.float16]]()
        var acc: Scalar[DType.float32] = 0.0
        for blk in range(blocks):
            var gblk = row * blocks + blk
            var scale = wf.unsafe_load(gblk * 17).cast[DType.float32]()
            var base = gblk * 34 + 2
            var k0 = blk * 32
            for lane in range(32):
                var raw = Int(w.unsafe_load(base + lane))
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Scalar[DType.float32](q) * x.unsafe_load(k0 + lane)
        y.unsafe_store(row, acc)


struct HipGemv:
    """Static HIP Q8_0 GEMV gateway (A-082). See file header."""

    @staticmethod
    def gate_ok() -> Bool:
        """The A-010-A-012 gate, HIP side: HIP runtime loadable
        (A-011 shim probe), exactly one HIP device, and the
        A-010 properties record for device 0 is plausible with
        gfx_arch gfx1151. Any other identity is refused."""
        if not HipMemory.runtime_available():
            return False
        try:
            if HipMemory.device_count() != 1:
                return False
        except:
            return False
        var props = AMDGate.get_device_properties(0)
        if not props.plausible():
            return False
        if props.gfx_arch != "gfx1151":
            return False
        return MojoNative.available()

    @staticmethod
    def device_name() raises -> String:
        return MojoNative.device_name()

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-082 HIP GEMV dispatches so far (hip shim
        counter; the launcher increments it only after the
        kernel launch + synchronize completed on the device)."""
        return Int(external_call["aesir_hip_q8_gemv_dispatch_count", UInt64]())

    @staticmethod
    def _note_dispatch():
        external_call["aesir_hip_note_q8_gemv_dispatch", NoneType]()

    @staticmethod
    def _validate(w: List[UInt8], x: List[Float32], rows: Int, cols: Int) raises -> Int:
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipGemv.q8_0_gemv: row count must be positive")
        if cols <= 0 or cols % 32 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipGemv.q8_0_gemv: column count must be a positive multiple of the 32-wide Q8_0 block")
        var need_w = rows * (cols // 32) * 34
        if len(w) != need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipGemv.q8_0_gemv: weight list does not cover the Q8_0 operand")
        if len(x) != cols:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipGemv.q8_0_gemv: activation list does not cover the column count")
        return need_w

    @staticmethod
    def _require_gate() raises:
        if not Self.gate_ok():
            raise Error("GPU-002 DEVICE_NOT_FOUND: HipGemv.q8_0_gemv: HIP gate (A-010-A-012) not satisfied - runtime absent, device count != 1, or device is not gfx1151 (honest-absent / wrong-device refused)")

    @staticmethod
    def _dispatch_once(ctx: DeviceContext, w: List[UInt8], x: List[Float32], rows: Int, cols: Int, need_w: Int) raises -> List[Float32]:
        var host_w = ctx.enqueue_create_host_buffer[DType.uint8](need_w)
        var host_x = ctx.enqueue_create_host_buffer[DType.float32](cols)
        var host_y = ctx.enqueue_create_host_buffer[DType.float32](rows)
        var dev_w = ctx.enqueue_create_buffer[DType.uint8](need_w)
        var dev_x = ctx.enqueue_create_buffer[DType.float32](cols)
        var dev_y = ctx.enqueue_create_buffer[DType.float32](rows)
        for i in range(need_w):
            host_w[i] = w[i]
        for i in range(cols):
            host_x[i] = x[i]
        for i in range(rows):
            host_y[i] = Float32(-9999.0)
        ctx.enqueue_copy(dev_w, host_w)
        ctx.enqueue_copy(dev_x, host_x)
        ctx.enqueue_copy(dev_y, host_y)
        ctx.synchronize()
        ctx.enqueue_function[
            _hip_q8_gemv_kernel[
                origin_of(dev_w), origin_of(dev_x), origin_of(dev_y)
            ]
        ](
            dev_w.unsafe_ptr(),
            dev_x.unsafe_ptr(),
            dev_y.unsafe_ptr(),
            Int32(rows),
            Int32(cols),
            grid_dim=(rows + 255) // 256,
            block_dim=256,
        )
        ctx.enqueue_copy(host_y, dev_y)
        ctx.synchronize()
        var out = List[Float32](capacity=rows)
        for i in range(rows):
            out.append(host_y[i])
        Self._note_dispatch()
        return out^

    @staticmethod
    def q8_0_gemv(
        w: List[UInt8], x: List[Float32], rows: Int, cols: Int
    ) raises -> List[Float32]:
        """y[r] = sum_k dequant(w[r, k]) * x[k] on the HIP
        device. w holds rows * (cols/32) * 34 raw Q8_0 bytes,
        x holds cols Float32; returns rows Float32. cols must
        be a positive multiple of 32; rows must be positive;
        the lists must cover the full operand. Fail-closed:
        raises on any violation, on a failed A-010-A-012 gate,
        or on any HIP failure - nothing is computed on the
        host instead."""
        var need_w = Self._validate(w, x, rows, cols)
        Self._require_gate()
        with DeviceContext(0, api="hip") as ctx:
            return Self._dispatch_once(ctx, w, x, rows, cols, need_w)

    @staticmethod
    def q8_0_gemv_repeated(
        w: List[UInt8], x: List[Float32], rows: Int, cols: Int, reps: Int
    ) raises -> List[Float32]:
        """The same GEMV dispatched reps times through ONE
        DeviceContext (the decode-loop shape: context creation
        measured at ~13-16 ms per call in the A-082 bench, so
        per-token decode must not pay it per dispatch).
        Returns the last dispatch's output; every dispatch is
        counted in dispatch_count(). reps must be positive."""
        if reps <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipGemv.q8_0_gemv_repeated: reps must be positive")
        var need_w = Self._validate(w, x, rows, cols)
        Self._require_gate()
        var out = List[Float32](capacity=rows)
        with DeviceContext(0, api="hip") as ctx:
            # Buffers are created and the operands uploaded ONCE;
            # the loop below is kernel launch + output readback
            # only - the weight-resident decode shape (cf. A-064).
            var host_w = ctx.enqueue_create_host_buffer[DType.uint8](need_w)
            var host_x = ctx.enqueue_create_host_buffer[DType.float32](cols)
            var host_y = ctx.enqueue_create_host_buffer[DType.float32](rows)
            var dev_w = ctx.enqueue_create_buffer[DType.uint8](need_w)
            var dev_x = ctx.enqueue_create_buffer[DType.float32](cols)
            var dev_y = ctx.enqueue_create_buffer[DType.float32](rows)
            for i in range(need_w):
                host_w[i] = w[i]
            for i in range(cols):
                host_x[i] = x[i]
            for i in range(rows):
                host_y[i] = Float32(-9999.0)
            ctx.enqueue_copy(dev_w, host_w)
            ctx.enqueue_copy(dev_x, host_x)
            ctx.enqueue_copy(dev_y, host_y)
            ctx.synchronize()
            for _ in range(reps):
                ctx.enqueue_function[
                    _hip_q8_gemv_kernel[
                        origin_of(dev_w), origin_of(dev_x), origin_of(dev_y)
                    ]
                ](
                    dev_w.unsafe_ptr(),
                    dev_x.unsafe_ptr(),
                    dev_y.unsafe_ptr(),
                    Int32(rows),
                    Int32(cols),
                    grid_dim=(rows + 255) // 256,
                    block_dim=256,
                )
                ctx.enqueue_copy(host_y, dev_y)
                ctx.synchronize()
                Self._note_dispatch()
            for i in range(rows):
                out.append(host_y[i])
        return out^
