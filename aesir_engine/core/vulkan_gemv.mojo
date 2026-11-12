# core/vulkan_gemv.mojo
# VulkanGemv: Vulkan Q8_0 GEMV gateway (slice A-056).
#
# Dequant + single-row GEMV dispatched on the GPU through the
# A-014/A-015 Vulkan context and buffer slots: the kernel
# (aesir_engine/shaders/q8_0_gemv.comp, SPIR-V embedded in
# aesir_engine/vulkan_buffer_shim.c exactly as A-015 embedded
# vec_add) consumes the raw GGUF Q8_0 byte layout - per row,
# blocks of one fp16 scale + 32 int8 values (34 bytes) - plus a
# Float32 activation vector, and writes one Float32 per row.
# Byte extraction and the fp16 scale decode run in-shader, so
# the dequant itself is GPU work; nothing is dequantized on the
# host. One workgroup of 256 invocations per output row, strided
# partial sums reduced through shared memory.
#
# A-055 note: the SPIR-V build pipeline (team-04, in flight in
# parallel) was not yet available when A-056 was built, so this
# slice follows the banked A-015/A-013 precedent (glslangValidator
# compile on purpleraider, hash filed in the A-056 ledger, words
# embedded in the shim). Adopting the A-055 pipeline when it
# banks is recorded as follow-up work in CAMPAIGN_STATE.md; the
# shader source of record already lives in aesir_engine/shaders/
# where that pipeline will pick it up.
#
# Fail-closed contract (matches A-014/A-015): when the Vulkan
# runtime or the RADV device is unavailable every operation
# raises; no host fallback is fabricated. Column counts must be
# positive multiples of the 32-wide Q8_0 block and every buffer
# must cover the full operand; violations raise before any
# dispatch. dispatch_count() reads the shim counter that
# increments only after a submit + queue-wait-idle completed on
# the device - the filed device-execution evidence (law 6).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


struct VulkanGemv:
    """Static Vulkan Q8_0 GEMV gateway (A-056). See file header."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanGemv." + what + ": Vulkan loader or dispatch"
                " entry points are not loadable on this host"
                " (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanGemv." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def q8_0_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-056 Q8_0 GEMV kernel: y[r] = sum_k
        dequant(w[r, k]) * x[k] for r in [0, rows), k in [0, cols).
        w holds rows * (cols/32) * 34 raw Q8_0 bytes, x holds cols
        Float32, y holds rows Float32. The shim creates the
        pipeline per call, submits, and waits for the queue to go
        idle before returning, so a mapped read of y after this
        call observes the completed dispatch. cols must be a
        positive multiple of 32; rows must be positive. Raises
        (fail-closed) on any violation or Vulkan failure - nothing
        is computed on the host instead."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q8_0_gemv: row count must be positive")
        if cols <= 0 or cols % 32 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q8_0_gemv: column count must be a"
                " positive multiple of the 32-wide Q8_0 block"
            )
        var need_w = rows * (cols // 32) * 34
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q8_0_gemv: weight buffer is smaller than the Q8_0 operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q8_0_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q8_0_gemv: output buffer is smaller than the row count")
        var rc = external_call["aesir_vk_buffer_q8_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("q8_0_gemv", rc)

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-056 GEMV dispatches on the device so far
        (shim counter; increments only after submit + wait-idle)."""
        return Int(external_call["aesir_vk_q8_gemv_dispatch_count", UInt64]())

    @staticmethod
    def q6_k_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-058 Q6_K GEMV kernel: y[r] = sum_k
        dequant(w[r, k]) * x[k]. w holds rows * (cols/256) * 210
        raw Q6_K bytes (ql[128] + qh[64] + int8 scales[16] + fp16
        d per 256-value block), x holds cols Float32, y holds rows
        Float32. cols must be a positive multiple of 256; rows
        must be positive. Fail-closed like q8_0_gemv: raises on any
        violation or Vulkan failure, nothing computed on host."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q6_k_gemv: row count must be positive")
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q6_k_gemv: column count must be a"
                " positive multiple of the 256-wide Q6_K block"
            )
        var need_w = rows * (cols // 256) * 210
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q6_k_gemv: weight buffer is smaller than the Q6_K operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q6_k_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q6_k_gemv: output buffer is smaller than the row count")
        var rc = external_call["aesir_vk_buffer_q6_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("q6_k_gemv", rc)

    @staticmethod
    def q6_dispatch_count() -> Int:
        """Completed A-058 Q6_K GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_q6_gemv_dispatch_count", UInt64]())

    @staticmethod
    def q5_k_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-058 Q5_K GEMV kernel: y[r] = sum_k
        dequant(w[r, k]) * x[k]. w holds rows * (cols/256) * 176
        raw Q5_K bytes (fp16 d + fp16 dmin + 12 packed scale/min
        bytes + qh[32] + qs[128] per 256-value block), x holds cols
        Float32, y holds rows Float32. cols must be a positive
        multiple of 256; rows must be positive. Fail-closed."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q5_k_gemv: row count must be positive")
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q5_k_gemv: column count must be a"
                " positive multiple of the 256-wide Q5_K block"
            )
        var need_w = rows * (cols // 256) * 176
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q5_k_gemv: weight buffer is smaller than the Q5_K operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q5_k_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.q5_k_gemv: output buffer is smaller than the row count")
        var rc = external_call["aesir_vk_buffer_q5_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("q5_k_gemv", rc)

    @staticmethod
    def q5_dispatch_count() -> Int:
        """Completed A-058 Q5_K GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_q5_gemv_dispatch_count", UInt64]())
