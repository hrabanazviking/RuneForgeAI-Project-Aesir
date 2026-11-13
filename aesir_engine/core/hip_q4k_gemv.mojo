# core/hip_q4k_gemv.mojo
# HipQ4kGemv: HIP Q4_K GEMV gateway (slice A-083).
#
# Dequant + single-row GEMV executed on the Radeon 8060S (gfx1151)
# through a Mojo-native kernel launched via MAX
# DeviceContext(api="hip") - the A-029 road, judged against the
# same Z13 CPU oracle as the A-057 Vulkan Q4_K GEMV:
# dequantize_ggml_k kind 12 (the banked A-040 SIMD path) into f16,
# then an f32 dot with the input vector.
#
# The kernel consumes the raw GGUF Q4_K byte layout - per row,
# super-blocks of 144 bytes (fp16 d, fp16 dmin, 12 scale/min bytes,
# 128 quant bytes per 256 values) - plus a Float32 activation
# vector, and writes one Float32 per row. Byte extraction, the
# fp16 scale decode, and the 6-bit scale/min unpacking all run
# in-kernel (mirroring aesir_engine/shaders/q4k_gemv.comp and the
# CPU oracle in core/compute.mojo exactly), so the dequant itself
# is device work; nothing is dequantized on the host. One thread
# per output row; accumulation in f32 throughout (A-075 policy:
# reductions accumulate in FP32).
#
# Parity discipline (raw-oracle law): the CPU oracle rounds each
# dequantized weight to f16 before the dot while this kernel keeps
# f32, so parity is judged at the A-057 filed f16-rounding
# tolerance |got - want| <= 0.02 * sqrt(K) + 0.02 * |want|, never
# bit-exactness.
#
# Device-execution evidence (law 6, accelerator-visible is not
# accelerator-run): the launch goes through DeviceContext with
# api="hip" on device 0 - the A-029 triangulation applies (the
# binary embeds a gfx1151 code object; a wrong-arch build is
# rejected at launch; with the device hidden the context raises
# hipErrorNoDevice, so there is no silent CPU fallback in this
# path). dispatch_count() reads the hip-shim counter that the
# launcher increments ONLY after the device context has
# synchronized without error - a rising count therefore means a
# dispatch completed on the device, mirroring the Vulkan shim
# dispatch counters.
#
# Fail-closed contract (matches A-056/A-057): when no HIP device
# is present the launcher raises; no host fallback is fabricated.
# Column counts must be positive multiples of the 256-wide Q4_K
# super-block and every operand must cover the full shape;
# violations raise before any device work.

from max.gpu.host import DeviceContext
from std.gpu import global_idx
from std.memory import Pointer
from std.ffi import external_call
from core.mojo_gpu_target import MojoNative


def _q4k_byte[
    origin: Origin[mut=False]
](w: Pointer[Scalar[DType.uint8], origin], idx: Int) -> UInt32:
    return w.unsafe_load(idx).cast[DType.uint32]()


def _f16_bits_to_f32(bits: UInt32) -> Float32:
    """Decode one IEEE fp16 bit pattern to f32 arithmetically.

    Handles zero, subnormals, and normals; Inf maps to the
    largest finite f32 magnitude and NaN to 0.0 - neither occurs
    in GGUF scale headers, and the mapping keeps the kernel total
    (no traps) on adversarial bytes.
    """
    var sign = Float32(1.0)
    if ((bits >> 15) & UInt32(1)) == UInt32(1):
        sign = Float32(-1.0)
    var exp = Int((bits >> 10) & UInt32(31))
    var frac = Int(bits & UInt32(1023))
    if exp == 0:
        # Subnormal (or signed zero): value = frac * 2^-24.
        return sign * Float32(frac) * Float32(5.960464477539063e-08)
    if exp == 31:
        if frac == 0:
            return sign * Float32(3.4028235e38)
        return Float32(0.0)
    var mant = Float32(1.0) + Float32(frac) * Float32(0.0009765625)
    var scale = Float32(1.0)
    var e = exp - 15
    while e > 0:
        scale *= Float32(2.0)
        e -= 1
    while e < 0:
        scale *= Float32(0.5)
        e += 1
    return sign * mant * scale


def _hip_q4k_gemv_kernel[
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
    """y[r] = sum_e dequant_q4k(W[r])[e] * x[e], one row per thread.

    The decode mirrors core/compute.mojo's Q4_K path (ggml kind
    12) and shaders/q4k_gemv.comp byte-for-byte: group g (32
    values) unpacks its 6-bit scale/min from the 12 header bytes
    (g < 4: sc = b[4+g] & 63, mn = b[8+g] & 63; else the fields
    are completed from the high bits of b[g] / b[4+g]); the quant
    byte for element l of group g lives at qs + (g/2)*32 + l, low
    nibble for even g, high nibble for odd g; the value is
    d * (scale * q) - dmin * min.
    """
    var row = Int(global_idx.x)
    if row < Int(rows):
        var k = Int(cols)
        var nblocks = k // 256
        var acc = Float32(0.0)
        for e in range(k):
            var blk = e // 256
            var within = e - blk * 256
            var base = (row * nblocks + blk) * 144
            var d = _f16_bits_to_f32(
                _q4k_byte(w, base) | (_q4k_byte(w, base + 1) << 8)
            )
            var dmin = _f16_bits_to_f32(
                _q4k_byte(w, base + 2) | (_q4k_byte(w, base + 3) << 8)
            )
            var g = within // 32
            var l = within - g * 32
            var sc: UInt32
            var mn: UInt32
            if g < 4:
                sc = _q4k_byte(w, base + 4 + g) & UInt32(63)
                mn = _q4k_byte(w, base + 8 + g) & UInt32(63)
            else:
                sc = (_q4k_byte(w, base + 8 + g) & UInt32(15)) | (
                    (_q4k_byte(w, base + g) >> 6) << 4
                )
                mn = (_q4k_byte(w, base + 8 + g) >> 4) | (
                    (_q4k_byte(w, base + 4 + g) >> 6) << 4
                )
            var qb = _q4k_byte(w, base + 16 + (g // 2) * 32 + l)
            var q: UInt32
            if g % 2 == 0:
                q = qb & UInt32(15)
            else:
                q = qb >> 4
            var wv = d * (Float32(sc) * Float32(q)) - dmin * Float32(mn)
            acc += wv * x.unsafe_load(e)
        y.unsafe_store(row, acc)


struct HipQ4kGemv:
    """Static HIP Q4_K GEMV gateway (A-083). See file header."""

    @staticmethod
    def available() -> Bool:
        """True iff at least one HIP device is visible to MAX."""
        return MojoNative.available()

    @staticmethod
    def device_name() raises -> String:
        """Name of HIP device 0 (raises when no device exists)."""
        return MojoNative.device_name()

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-083 GEMV dispatches on the device so far.

        Shim counter; the launcher increments it only after the
        device context synchronized without error, so it counts
        completed device executions, never attempted launches.
        """
        return Int(external_call["aesir_hip_q4k_dispatch_count", UInt64]())

    @staticmethod
    def q4k_gemv(
        w: List[UInt8], x: List[Float32], rows: Int, cols: Int
    ) raises -> List[Float32]:
        """Dispatch the A-083 Q4_K GEMV kernel on HIP device 0:
        y[r] = sum_k dequant(w[r, k]) * x[k] for r in [0, rows),
        k in [0, cols). w holds rows * (cols/256) * 144 raw Q4_K
        bytes, x holds cols Float32. cols must be a positive
        multiple of 256; rows must be positive; operand sizes
        must cover the shape exactly-or-more. Raises (fail-closed)
        on any violation, on a missing HIP device, or on any
        device error - nothing is computed on the host instead.
        """
        if rows <= 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: HipQ4kGemv.q4k_gemv:"
                " row count must be positive"
            )
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: HipQ4kGemv.q4k_gemv:"
                " column count must be a positive multiple of the"
                " 256-wide Q4_K super-block"
            )
        var w_bytes = rows * (cols // 256) * 144
        if len(w) < w_bytes:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: HipQ4kGemv.q4k_gemv:"
                " weight operand is smaller than the Q4_K shape"
            )
        if len(x) < cols:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: HipQ4kGemv.q4k_gemv:"
                " activation operand is smaller than the column count"
            )
        if not Self.available():
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: HipQ4kGemv.q4k_gemv:"
                " no HIP device is visible on this host"
                " (honest-absent)"
            )
        with DeviceContext(0, api="hip") as ctx:
            var host_w = ctx.enqueue_create_host_buffer[DType.uint8](w_bytes)
            var host_x = ctx.enqueue_create_host_buffer[DType.float32](cols)
            var host_y = ctx.enqueue_create_host_buffer[DType.float32](rows)
            var dev_w = ctx.enqueue_create_buffer[DType.uint8](w_bytes)
            var dev_x = ctx.enqueue_create_buffer[DType.float32](cols)
            var dev_y = ctx.enqueue_create_buffer[DType.float32](rows)
            for i in range(w_bytes):
                host_w[i] = w[i]
            for i in range(cols):
                host_x[i] = x[i]
            for r in range(rows):
                host_y[r] = Float32(-9999.0)
            ctx.enqueue_copy(dev_w, host_w)
            ctx.enqueue_copy(dev_x, host_x)
            ctx.enqueue_copy(dev_y, host_y)
            ctx.synchronize()
            ctx.enqueue_function[
                _hip_q4k_gemv_kernel[
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
            for r in range(rows):
                out.append(host_y[r])
            external_call["aesir_hip_q4k_note_dispatch", NoneType]()
            return out^
