# core/vulkan_async.mojo
# VulkanAsync: async dispatch gateway (A-071) - queued submissions
# with timeline profiling over the A-014 shim context.
#
# Roadmap acceptance: "No per-token host sync stalls: queued
# submissions with timeline profiling. Timeline trace filed showing
# GPU busy fraction per token; host wait time per token measured."
#
# Mechanism (shim side, vulkan_buffer_shim.c A-071 section): with
# async mode ON, every banked dispatch gateway records two GPU
# timestamps (TOP_OF_PIPE at command-buffer begin, BOTTOM_OF_PIPE
# before end), submits with its own fence and returns WITHOUT any
# host wait - no vkQueueWaitIdle anywhere in the async path. The
# per-dispatch Vulkan objects move into a deferred ring in the shim
# and are destroyed only after their fence completes. Same-queue
# in-order execution preserves every data dependency between queued
# dispatches, so correctness needs no host sync inside a token; the
# host waits exactly once per drain (one vkWaitForFences for the
# whole pending batch), which is where host-wait time is measured.
# GPU busy time is the sum of timestamp-pair durations scaled by
# the device limits.timestampPeriod; a drain batch's span is
# (max end - min begin), so busy fraction = busy / span.
# With async mode OFF every dispatch keeps the exact legacy
# submit + vkQueueWaitIdle tail (the banked synchronous path).
#
# Fail-closed: set_mode(True) raises when the loader, dispatch
# entry points, or fence entry points are unavailable - no host
# fallback is fabricated. Timestamp absence degrades honestly:
# stats.ts_ok is False and busy/span read 0 (filed as such).

from std.ffi import external_call
from std.memory import alloc

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


struct VulkanAsyncStats:
    """Snapshot of the shim async counters (see shim A-071)."""

    var mode: Int
    var submits: Int
    var completed: Int
    var pending: Int
    var max_depth: Int
    var wait_idle_calls: Int
    var fence_waits: Int
    var host_wait_ns: Int
    var gpu_busy_ns: Int
    var gpu_span_ns: Int
    var ts_ok: Bool
    var ts_period_ps: Int

    def __init__(
        out self,
        mode: Int,
        submits: Int,
        completed: Int,
        pending: Int,
        max_depth: Int,
        wait_idle_calls: Int,
        fence_waits: Int,
        host_wait_ns: Int,
        gpu_busy_ns: Int,
        gpu_span_ns: Int,
        ts_ok: Bool,
        ts_period_ps: Int,
    ):
        self.mode = mode
        self.submits = submits
        self.completed = completed
        self.pending = pending
        self.max_depth = max_depth
        self.wait_idle_calls = wait_idle_calls
        self.fence_waits = fence_waits
        self.host_wait_ns = host_wait_ns
        self.gpu_busy_ns = gpu_busy_ns
        self.gpu_span_ns = gpu_span_ns
        self.ts_ok = ts_ok
        self.ts_period_ps = ts_period_ps

    def busy_fraction(self) -> Float64:
        """GPU busy / span over all drained batches (0 if no span)."""
        if self.gpu_span_ns <= 0:
            return Float64(0.0)
        return Float64(self.gpu_busy_ns) / Float64(self.gpu_span_ns)


struct VulkanAsync:
    """Static async-dispatch gateway (A-071). See file header."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanAsync." + what
                + ": Vulkan loader, dispatch or fence entry points"
                " are not loadable on this host (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanAsync." + what
                + ": invalid argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanAsync." + what
            + ": Vulkan call failed, VkResult " + String(Int(rc))
        )

    @staticmethod
    def set_mode(on: Bool) raises:
        """Enable/disable queued submission. Disabling drains first."""
        var rc = external_call["aesir_vk_async_set_mode", Int32](
            Int32(1) if on else Int32(0)
        )
        if rc != 0:
            Self._raise_for_rc("set_mode", rc)

    @staticmethod
    def drain() raises:
        """Wait once for every pending queued dispatch (fence batch)
        and harvest its timeline timestamps. No-op when idle."""
        var rc = external_call["aesir_vk_async_drain", Int32]()
        if rc != 0:
            Self._raise_for_rc("drain", rc)

    @staticmethod
    def reset_stats():
        external_call["aesir_vk_async_reset_stats", NoneType]()

    @staticmethod
    def stats() raises -> VulkanAsyncStats:
        var buf = alloc[UInt64](12)
        for i in range(12):
            buf.unsafe_store(i, UInt64(0))
        var rc = external_call["aesir_vk_async_stats", Int32](buf, Int32(12))
        if rc != 0:
            buf.unsafe_free()
            Self._raise_for_rc("stats", rc)
        var v = List[Int]()
        for i in range(12):
            v.append(Int(buf.unsafe_load(i)))
        buf.unsafe_free()
        return VulkanAsyncStats(
            v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9],
            v[10] == 1, v[11],
        )
