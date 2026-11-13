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
# host. One workgroup of 64 invocations per output row (A-073
# wavefront-32 tuning: 2 x 32-wide wavefronts), strided
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
    @staticmethod
    def iq2_xxs_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        g: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-059 IQ2_XXS GEMV kernel: y[r] = sum_k
        dequant(w[r, k]) * x[k]. w holds rows * (cols/256) * 66 raw
        IQ2_XXS bytes, x holds cols Float32, y holds rows Float32,
        g holds the 256-entry IQ2_XXS grid as 512 bytes of packed
        UInt16 (the GGML format constant). cols must be a positive
        multiple of 256; rows must be positive. Fail-closed."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: row count must be positive")
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: column count must be a"
                " positive multiple of the 256-wide IQ2_XXS block"
            )
        var need_w = rows * (cols // 256) * 66
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: weight buffer is smaller than the IQ2_XXS operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: output buffer is smaller than the row count")
        if g.requested_size < 512:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq2_xxs_gemv: grid buffer is smaller than the 256-entry IQ2_XXS grid")
        var rc = external_call["aesir_vk_buffer_iq2xxs_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt64(g.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("iq2_xxs_gemv", rc)

    @staticmethod
    def iq2xxs_dispatch_count() -> Int:
        """Completed A-059 IQ2_XXS GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_iq2xxs_dispatch_count", UInt64]())

    @staticmethod
    def iq1_s_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        g: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-059 IQ1_S GEMV kernel. w holds rows *
        (cols/256) * 50 raw IQ1_S bytes; g holds the 2048-entry
        IQ1_S grid as 4096 bytes of packed UInt16. cols must be a
        positive multiple of 256. Fail-closed."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: row count must be positive")
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: column count must be a"
                " positive multiple of the 256-wide IQ1_S block"
            )
        var need_w = rows * (cols // 256) * 50
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: weight buffer is smaller than the IQ1_S operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: output buffer is smaller than the row count")
        if g.requested_size < 4096:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq1_s_gemv: grid buffer is smaller than the 2048-entry IQ1_S grid")
        var rc = external_call["aesir_vk_buffer_iq1s_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt64(g.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("iq1_s_gemv", rc)

    @staticmethod
    def iq1s_dispatch_count() -> Int:
        """Completed A-059 IQ1_S GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_iq1s_dispatch_count", UInt64]())

    @staticmethod
    def iq3_xxs_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        g: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-059 IQ3_XXS GEMV kernel. w holds rows *
        (cols/256) * 98 raw IQ3_XXS bytes; g holds the 256-entry
        IQ3_XXS grid as 512 bytes of packed UInt16. cols must be a
        positive multiple of 256. Fail-closed."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: row count must be positive")
        if cols <= 0 or cols % 256 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: column count must be a"
                " positive multiple of the 256-wide IQ3_XXS block"
            )
        var need_w = rows * (cols // 256) * 98
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: weight buffer is smaller than the IQ3_XXS operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: output buffer is smaller than the row count")
        if g.requested_size < 512:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq3_xxs_gemv: grid buffer is smaller than the 256-entry IQ3_XXS grid")
        var rc = external_call["aesir_vk_buffer_iq3xxs_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt64(g.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("iq3_xxs_gemv", rc)

    @staticmethod
    def iq3xxs_dispatch_count() -> Int:
        """Completed A-059 IQ3_XXS GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_iq3xxs_dispatch_count", UInt64]())

    @staticmethod
    def iq4_nl_gemv(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        """Dispatch the A-059 IQ4_NL GEMV kernel. w holds rows *
        (cols/32) * 18 raw IQ4_NL bytes (32-value blocks of one
        fp16 scale + 16 nibble bytes). cols must be a positive
        multiple of 32 - the format's own block size, NOT 256:
        the GPU-side landing of Bug A-046:B1 (the CPU gemm_iq
        wrapper still demands cols % 256 for every IQ type, so
        K=288 IQ4_NL runs here while the CPU wrapper raises).
        Fail-closed."""
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq4_nl_gemv: row count must be positive")
        if cols <= 0 or cols % 32 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq4_nl_gemv: column count must be a"
                " positive multiple of the 32-wide IQ4_NL block"
            )
        var need_w = rows * (cols // 32) * 18
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq4_nl_gemv: weight buffer is smaller than the IQ4_NL operand")
        if x.requested_size < cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq4_nl_gemv: activation buffer is smaller than the column count")
        if y.requested_size < rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemv.iq4_nl_gemv: output buffer is smaller than the row count")
        var rc = external_call["aesir_vk_buffer_iq4nl_gemv", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols)
        )
        if rc != 0:
            Self._raise_for_rc("iq4_nl_gemv", rc)

    @staticmethod
    def iq4nl_dispatch_count() -> Int:
        """Completed A-059 IQ4_NL GEMV dispatches on the device."""
        return Int(external_call["aesir_vk_iq4nl_dispatch_count", UInt64]())
