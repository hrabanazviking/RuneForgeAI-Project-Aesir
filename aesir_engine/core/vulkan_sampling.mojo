# core/vulkan_sampling.mojo
# VulkanSampling: Vulkan sampling gateway (slice A-063, Wave 7 closer).
#
# Greedy argmax and temperature/top-k draws over a Float32 logits
# row, dispatched on the GPU through the A-014/A-015 Vulkan context
# and buffer slots. The kernels are SPIR-V from the A-055 pipeline
# header only (aesir_engine/shaders/generated/aesir_shaders_spv.h):
# sampling_greedy.comp (A-055 foundation; one workgroup reduces
# (value, index) pairs, ties to the LOWEST index, matching the CPU
# greedy tie policy in test_greedy_tie_policy) and the A-063
# sampling_sample.comp (ranked top-k enumeration + temperature
# softmax draw for a caller-supplied uniform u in [0, 1), the same
# draw rule as core/sampler.mojo's stochastic path with
# u = RuneRNG.next_float32()). Both write one uint token id.
#
# Fail-closed contract (matches A-014/A-015/A-056/A-062): when the
# Vulkan runtime or the RADV device is unavailable every operation
# raises; no host fallback is fabricated. Shapes must be positive,
# temperature must be > 0, u must lie in [0, 1), the effective kept
# count min(top_k or n, n) is capped at 1024 and n at 16384 for the
# stochastic kernel (its ranked draw is bounded by design), and
# every buffer must cover the full operand; violations raise
# before any dispatch. Logits must be finite: the CPU sampler
# sanitizes non-finite lanes to -1e9 first, these kernels do not
# (A-063 ledger next work). greedy_dispatch_count() /
# sample_dispatch_count() read the shim counters that increment
# only after a submit + queue-wait-idle completed on the device -
# the filed device-execution evidence (law 6).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001
comptime _MAX_SAMPLE_N = 16384
comptime _MAX_KEPT = 1024


struct VulkanSampling:
    """Static Vulkan sampling gateway (A-063)."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanSampling." + what + ": Vulkan loader or dispatch"
                " entry points are not loadable on this host"
                " (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanSampling." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def _check_operands(
        what: String,
        logits: VulkanAllocation,
        out_alloc: VulkanAllocation,
        n: Int,
    ) raises:
        if n <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling." + what + ": vocab size n must be positive")
        if logits.requested_size < n * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling." + what + ": logits buffer is smaller than n Float32")
        if out_alloc.requested_size < 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling." + what + ": output buffer is smaller than one uint token id")

    @staticmethod
    def greedy(
        logits: VulkanAllocation,
        out_alloc: VulkanAllocation,
        n: Int,
    ) raises:
        """Dispatch the greedy argmax kernel over logits[0:n];
        the winning token id (lowest index on ties) is written
        as a uint to out[0]. Raises (fail-closed) on any shape
        or buffer violation or Vulkan failure - nothing is
        computed on the host instead."""
        Self._check_operands("greedy", logits, out_alloc, n)
        var rc = external_call["aesir_vk_buffer_sampling_greedy", Int32](
            UInt64(logits.id), UInt64(out_alloc.id), UInt32(n),
        )
        if rc != 0:
            Self._raise_for_rc("greedy", rc)

    @staticmethod
    def sample(
        logits: VulkanAllocation,
        out_alloc: VulkanAllocation,
        n: Int,
        top_k: Int,
        temperature: Float32,
        u: Float32,
    ) raises:
        """Dispatch the temperature/top-k sampling kernel over
        logits[0:n] and write the drawn token id as a uint to
        out[0]. top_k == 0 or top_k >= n keeps the whole row;
        the effective kept count is capped at 1024 and n at
        16384. temperature must be > 0 and u must lie in
        [0, 1) (on the engine path u is RuneRNG.next_float32()).
        Raises (fail-closed) on any violation or Vulkan failure."""
        Self._check_operands("sample", logits, out_alloc, n)
        if n > _MAX_SAMPLE_N:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling.sample: vocab size n exceeds the stochastic kernel bound of 16384")
        if top_k < 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling.sample: top_k must be non-negative (0 keeps the whole row)")
        var kept = n
        if top_k > 0 and top_k < n:
            kept = top_k
        if kept > _MAX_KEPT:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling.sample: effective kept count exceeds the kernel bound of 1024")
        if not (temperature > Float32(0.0)):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling.sample: temperature must be positive")
        if u < Float32(0.0) or u >= Float32(1.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanSampling.sample: uniform u must lie in [0, 1)")
        var rc = external_call["aesir_vk_buffer_sampling_sample", Int32](
            UInt64(logits.id), UInt64(out_alloc.id), UInt32(n), UInt32(top_k),
            temperature, u,
        )
        if rc != 0:
            Self._raise_for_rc("sample", rc)

    @staticmethod
    def greedy_dispatch_count() -> Int:
        """Completed A-063 greedy dispatches on the device so
        far (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_sampling_greedy_dispatch_count", UInt64]())

    @staticmethod
    def sample_dispatch_count() -> Int:
        """Completed A-063 temperature/top-k dispatches on the
        device so far (shim counter; increments only after
        submit + wait-idle)."""
        return Int(external_call["aesir_vk_sampling_sample_dispatch_count", UInt64]())
