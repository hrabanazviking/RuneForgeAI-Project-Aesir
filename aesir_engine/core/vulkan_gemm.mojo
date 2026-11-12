# core/vulkan_gemm.mojo
# VulkanGemm: Vulkan batched GEMM gateway for prefill (slice A-068).
#
# Batched matrix kernels for prompt processing: where the Wave 7
# GEMV gateways (A-056..A-059) multiply one weight matrix by ONE
# activation vector (the decode shape), this gateway multiplies
# one weight matrix by a BATCH of activation rows - the prompt's
# tokens - in a single dispatch: Y[t, r] = sum_k W[r, k] * X[t, k].
# The weight bytes are read once per (row, token) workgroup but
# serve every token in the batch, which is the reuse that makes
# prefill compute-shaped instead of M x bandwidth-shaped.
#
# Two kernels, both built through the A-055 SPIR-V pipeline
# (scripts/build_shaders.py; SPIR-V consumed by the shim from
# aesir_engine/shaders/generated/aesir_shaders_spv.h):
# - q8_0_gemm (aesir_engine/shaders/q8_0_gemm.comp): W in the raw
#   GGUF Q8_0 byte layout - per row, blocks of one fp16 scale +
#   32 int8 values (34 bytes) - exactly the layout the A-056 GEMV
#   and the CPU oracle consume. Byte extraction and the fp16
#   scale decode run in-shader; the dequant itself is GPU work.
# - f32_gemm (aesir_engine/shaders/gemm_f32.comp): dense Float32
#   W, the batched generalisation of the A-055 gemv_f32 kernel.
# Both dispatch one workgroup of 256 invocations per (row, token)
# pair as (rows, tokens, 1), strided partial sums reduced through
# shared memory (the A-056 reduction), so a tokens == 1 dispatch
# computes the same per-row sums as the matching GEMV kernel.
#
# Scope boundary (honest): this is the GEMM layer of prefill
# only. Batched causal attention, per-position RoPE and
# incremental KV writes for a full prefill layer are A-069's
# road (chunked prefill), not claimed here.
#
# Fail-closed contract (matches A-014/A-015/A-056): when the
# Vulkan runtime or the RADV device is unavailable every
# operation raises; no host fallback is fabricated and no product
# is computed on the CPU in this path (any CPU participation in
# the wider GPU path is A-070's measured inventory, not a silent
# substitute). Shapes are validated before any dispatch: token,
# row and column counts must be positive (columns a positive
# multiple of the 32-wide Q8_0 block for q8_0_gemm) and every
# buffer must cover the full batched operand. dispatch_count()
# reads the shim counters that increment only after a submit +
# queue-wait-idle completed on the device - the filed
# device-execution evidence (roadmap law 6).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


struct VulkanGemm:
    """Static Vulkan batched GEMM gateway (A-068). See file header."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanGemm." + what + ": Vulkan loader or dispatch"
                " entry points are not loadable on this host"
                " (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanGemm." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def q8_0_gemm(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
        tokens: Int,
    ) raises:
        """Dispatch the A-068 Q8_0 GEMM kernel: y[t * rows + r] =
        sum_k dequant(w[r, k]) * x[t * cols + k] for t in
        [0, tokens), r in [0, rows), k in [0, cols). w holds
        rows * (cols/32) * 34 raw Q8_0 bytes, x holds
        tokens * cols Float32, y holds tokens * rows Float32.
        The shim creates the pipeline per call, submits, and
        waits for the queue to go idle before returning, so a
        mapped read of y after this call observes the completed
        dispatch. cols must be a positive multiple of 32; rows
        and tokens must be positive. Raises (fail-closed) on any
        violation or Vulkan failure - nothing is computed on
        the host instead."""
        if tokens <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: token count must be positive")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: row count must be positive")
        if cols <= 0 or cols % 32 != 0:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: column count must be a"
                " positive multiple of the 32-wide Q8_0 block"
            )
        var need_w = rows * (cols // 32) * 34
        if w.requested_size < need_w:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: weight buffer is smaller than the Q8_0 operand")
        if x.requested_size < tokens * cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: activation buffer is smaller than the batched operand")
        if y.requested_size < tokens * rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.q8_0_gemm: output buffer is smaller than the batched result")
        var rc = external_call["aesir_vk_buffer_q8_gemm", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols), UInt32(tokens)
        )
        if rc != 0:
            Self._raise_for_rc("q8_0_gemm", rc)

    @staticmethod
    def q8_dispatch_count() -> Int:
        """Completed A-068 Q8_0 GEMM dispatches on the device so
        far (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_q8_gemm_dispatch_count", UInt64]())

    @staticmethod
    def f32_gemm(
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
        tokens: Int,
    ) raises:
        """Dispatch the A-068 dense F32 GEMM kernel: y[t * rows +
        r] = sum_k w[r * cols + k] * x[t * cols + k]. w holds
        rows * cols Float32, x holds tokens * cols Float32, y
        holds tokens * rows Float32. rows, cols and tokens must
        be positive. Fail-closed like q8_0_gemm: raises on any
        violation or Vulkan failure, nothing computed on host."""
        if tokens <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: token count must be positive")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: row count must be positive")
        if cols <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: column count must be positive")
        if w.requested_size < rows * cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: weight buffer is smaller than the dense operand")
        if x.requested_size < tokens * cols * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: activation buffer is smaller than the batched operand")
        if y.requested_size < tokens * rows * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanGemm.f32_gemm: output buffer is smaller than the batched result")
        var rc = external_call["aesir_vk_buffer_f32_gemm", Int32](
            UInt64(w.id), UInt64(x.id), UInt64(y.id), UInt32(rows), UInt32(cols), UInt32(tokens)
        )
        if rc != 0:
            Self._raise_for_rc("f32_gemm", rc)

    @staticmethod
    def f32_dispatch_count() -> Int:
        """Completed A-068 F32 GEMM dispatches on the device so
        far (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_f32_gemm_dispatch_count", UInt64]())
