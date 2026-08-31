"""Exact explicit buffer accounting for the implemented native CUDA profiles."""
from core.native_hardware import observe_host_memory
from core.sampling_config import sampling_device_bytes


def checked_bytes_sum(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or a > 9223372036854775807 - b:
        raise Error("Inference memory byte count overflow")
    return a + b


struct InferenceMemoryPlan(Copyable, ImplicitlyCopyable):
    var weights_bytes: Int
    var kv_bytes: Int
    var activation_bytes: Int
    var device_bytes: Int
    var host_upload_bytes: Int

    def __init__(out self, weights: Int, kv: Int, activations: Int) raises:
        if weights <= 0 or kv <= 0 or activations <= 0:
            raise Error("Inference buffers must have positive sizes")
        self.weights_bytes = weights
        self.kv_bytes = kv
        self.activation_bytes = activations
        # One int32 token output on each side; weights are mapped plus pinned
        # during initial upload. Tokenizer/driver overhead needs reserve too.
        self.device_bytes = checked_bytes_sum(checked_bytes_sum(weights, kv), checked_bytes_sum(activations, 4))
        self.host_upload_bytes = checked_bytes_sum(checked_bytes_sum(weights, weights), 4)

    def fits(self, free_bytes: Int, reserve_bytes: Int) raises -> Bool:
        if free_bytes < 0 or reserve_bytes < 0:
            raise Error("Memory budget and reserve must be nonnegative")
        return reserve_bytes <= free_bytes and self.device_bytes <= free_bytes - reserve_bytes

    def admit(self, free_bytes: Int, host_available: Int, reserve_bytes: Int) raises:
        if not self.fits(free_bytes, reserve_bytes):
            raise Error("CUDA model does not fit: explicit_buffers=" + String(self.device_bytes)
                        + " free=" + String(free_bytes) + " reserve=" + String(reserve_bytes)
                        + "; reduce context or choose another device; no CPU fallback")
        if host_available < 0 or reserve_bytes > host_available or self.host_upload_bytes > host_available - reserve_bytes:
            raise Error("Insufficient host memory for mapped weights and pinned upload staging")

    def admit_observed(self, free_bytes: Int, reserve_bytes: Int) raises:
        self.admit(free_bytes, observe_host_memory().available_bytes, reserve_bytes)


def llama3_memory_plan(weights: Int, context: Int) raises -> InferenceMemoryPlan:
    if context < 2 or context > 8192:
        raise Error("Llama 3 memory context must be in 2..8192")
    return InferenceMemoryPlan(weights, 32 * 2 * context * 1024 * 2,
                               (179456 + 32 * context) * 4 + sampling_device_bytes(128256))


def gemma4_memory_plan(weights: Int, context: Int) raises -> InferenceMemoryPlan:
    if context < 2 or context > 32768:
        raise Error("Gemma 4 memory context must be in 2..32768")
    # Only first 24 layers own KV: twenty local windows and four global caches.
    var kv = (20 * 2 * 512 * 2 * 256 + 4 * 2 * context * 2 * 512) * 4
    return InferenceMemoryPlan(weights, kv, (322048 + 8 * context) * 4 + sampling_device_bytes(262144))
