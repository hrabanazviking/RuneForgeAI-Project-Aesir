# core/vulkan_norm_rope.mojo
# VulkanNormRope: Vulkan RMSNorm + RoPE gateway (slice A-060).
#
# Both kernels are the A-055 foundation shaders
# (aesir_engine/shaders/rmsnorm.comp and rope.comp), compiled by
# the A-055 SPIR-V build pipeline and embedded through the
# generated header aesir_engine/shaders/generated/
# aesir_shaders_spv.h (hashes in SHADER_MANIFEST.json); the shim
# side (aesir_engine/vulkan_buffer_shim.c) creates the pipeline
# per call on the A-014/A-015 context, submits, and waits for the
# queue to go idle before returning.
#
# RMSNorm: y[row, i] = x[row, i] * rsqrt(mean_i(x[row, i]^2) + eps)
# * g[i] - the same math as the engine CPU rmsnorm
# (core/compute.mojo), in Float32 throughout here.
#
# RoPE: rotate-half pairing exactly as the shader of record and
# the engine CPU apply_rope with neox=True lay it out: pair
# (i, i + head_dim/2) of each row rotates by
# position * base^(-2i/head_dim), applied in place. One position
# per call (the decode-step shape); rows are independent rows of
# head_dim (e.g. one row per head at one position).
#
# Fail-closed contract (matches A-014/A-015/A-056): when the
# Vulkan runtime or the RADV device is unavailable every
# operation raises; no host fallback is fabricated. Shapes are
# validated before any dispatch. rmsnorm_dispatch_count() and
# rope_dispatch_count() read the shim counters that increment
# only after a submit + queue-wait-idle completed on the
# device - the filed device-execution evidence (law 6).
#
# Float arguments cross the FFI as IEEE-754 bit patterns
# (UInt32) so the gateway needs no float FFI surface.

from std.ffi import external_call
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


struct VulkanNormRope:
    """Static Vulkan RMSNorm + RoPE gateway (A-060). See header."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanNormRope." + what + ": Vulkan loader or dispatch"
                " entry points are not loadable on this host"
                " (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanNormRope." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def rmsnorm(
        x: VulkanAllocation,
        g: VulkanAllocation,
        y: VulkanAllocation,
        n: Int,
        rows: Int,
        eps: Float32,
    ) raises:
        """Dispatch the A-060 RMSNorm kernel: for each row,
        y[i] = x[i] * rsqrt(mean(x^2) + eps) * g[i]. x and y hold
        rows * n Float32, g holds n Float32. n and rows must be
        positive and eps must be positive. The shim submits and
        waits for the queue to go idle, so a mapped read of y
        after this call observes the completed dispatch. Raises
        (fail-closed) on any violation or Vulkan failure -
        nothing is computed on the host instead."""
        if n <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: row length n must be positive")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: row count must be positive")
        if eps <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: eps must be positive")
        if x.requested_size < rows * n * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: input buffer is smaller than rows*n Float32")
        if g.requested_size < n * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: weight buffer is smaller than n Float32")
        if y.requested_size < rows * n * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rmsnorm: output buffer is smaller than rows*n Float32")
        var eps_bits = bitcast[DType.uint32](eps)
        var rc = external_call["aesir_vk_buffer_rmsnorm", Int32](
            UInt64(x.id), UInt64(g.id), UInt64(y.id), UInt32(n), UInt32(rows), eps_bits
        )
        if rc != 0:
            Self._raise_for_rc("rmsnorm", rc)

    @staticmethod
    def rope(
        x: VulkanAllocation,
        head_dim: Int,
        rows: Int,
        position: Int,
        base: Float32,
    ) raises:
        """Dispatch the A-060 RoPE kernel in place over x: rows
        independent rows of head_dim Float32, pair
        (i, i + head_dim/2) rotated by position * base^(-2i /
        head_dim) (rotate-half). head_dim must be a positive
        even number, rows must be positive, position must be
        non-negative and base must be positive. The shim
        submits and waits idle before returning. Raises
        (fail-closed) on any violation or Vulkan failure."""
        if head_dim <= 0 or head_dim % 2 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rope: head_dim must be positive and even")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rope: row count must be positive")
        if position < 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rope: position must be non-negative")
        if base <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rope: base must be positive")
        if x.requested_size < rows * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanNormRope.rope: buffer is smaller than rows*head_dim Float32")
        var base_bits = bitcast[DType.uint32](base)
        var rc = external_call["aesir_vk_buffer_rope", Int32](
            UInt64(x.id), UInt32(head_dim), UInt32(rows), UInt32(position), base_bits
        )
        if rc != 0:
            Self._raise_for_rc("rope", rc)

    @staticmethod
    def rmsnorm_dispatch_count() -> Int:
        """Completed A-060 RMSNorm dispatches on the device so
        far (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_rmsnorm_dispatch_count", UInt64]())

    @staticmethod
    def rope_dispatch_count() -> Int:
        """Completed A-060 RoPE dispatches on the device so far
        (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_rope_dispatch_count", UInt64]())
