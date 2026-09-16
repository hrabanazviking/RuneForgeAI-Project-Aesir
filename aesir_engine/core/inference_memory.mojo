"""Exact explicit buffer accounting for the implemented native CUDA profiles."""
from core.native_hardware import observe_host_memory
from core.sampling_config import sampling_device_bytes
from core.cuda_upload import upload_staging_bytes
from core.gemma4_profile import Gemma4Profile, gemma4_e4b_profile
from core.dense_gqa_profile import DenseGQAProfile, llama3_8b_profile


def checked_bytes_sum(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or a > 9223372036854775807 - b:
        raise Error("Inference memory byte count overflow")
    return a + b


struct MemoryFitExplanation(Copyable):
    """Stable arithmetic evidence for one host or device memory decision."""

    var fits: Bool
    var reason_code: String
    var required_bytes: Int
    var available_bytes: Int
    var reserve_bytes: Int
    var usable_bytes: Int
    var deficit_bytes: Int
    var headroom_bytes: Int

    def __init__(out self, fits: Bool, reason_code: String,
                 required_bytes: Int, available_bytes: Int,
                 reserve_bytes: Int, usable_bytes: Int,
                 deficit_bytes: Int, headroom_bytes: Int):
        self.fits = fits
        self.reason_code = reason_code
        self.required_bytes = required_bytes
        self.available_bytes = available_bytes
        self.reserve_bytes = reserve_bytes
        self.usable_bytes = usable_bytes
        self.deficit_bytes = deficit_bytes
        self.headroom_bytes = headroom_bytes

    def describe(self) -> String:
        return (
            "code=" + self.reason_code
            + " required_bytes=" + String(self.required_bytes)
            + " available_bytes=" + String(self.available_bytes)
            + " reserve_bytes=" + String(self.reserve_bytes)
            + " usable_bytes=" + String(self.usable_bytes)
            + " deficit_bytes=" + String(self.deficit_bytes)
            + " headroom_bytes=" + String(self.headroom_bytes)
        )


def explain_memory_fit(required_bytes: Int, available_bytes: Int,
                       reserve_bytes: Int, domain: String) raises -> MemoryFitExplanation:
    """Explains checked required <= available - reserve arithmetic without overflow."""
    if required_bytes <= 0 or available_bytes < 0 or reserve_bytes < 0:
        raise Error("Memory fit values must be positive/nonnegative")
    if domain != "device" and domain != "host":
        raise Error("Memory fit domain must be device or host")
    if reserve_bytes > available_bytes:
        return MemoryFitExplanation(
            False, domain + "_reserve_exceeds_available",
            required_bytes, available_bytes, reserve_bytes, 0,
            required_bytes, 0
        )
    var usable_bytes = available_bytes - reserve_bytes
    if required_bytes > usable_bytes:
        return MemoryFitExplanation(
            False, domain + "_required_exceeds_usable",
            required_bytes, available_bytes, reserve_bytes, usable_bytes,
            required_bytes - usable_bytes, 0
        )
    return MemoryFitExplanation(
        True, domain + "_fit", required_bytes, available_bytes,
        reserve_bytes, usable_bytes, 0, usable_bytes - required_bytes
    )


struct InferenceMemoryPlan(Copyable, ImplicitlyCopyable):
    var weights_bytes: Int
    var kv_bytes: Int
    var activation_bytes: Int
    var device_bytes: Int
    var host_upload_bytes: Int
    var host_staging_bytes: Int

    def __init__(out self, weights: Int, kv: Int, activations: Int) raises:
        if weights <= 0 or kv <= 0 or activations <= 0:
            raise Error("Inference buffers must have positive sizes")
        self.weights_bytes = weights
        self.kv_bytes = kv
        self.activation_bytes = activations
        # One int32 output on each side; one bounded pinned upload chunk plus
        # the mapped weights. Tokenizer/driver overhead needs reserve too.
        self.device_bytes = checked_bytes_sum(checked_bytes_sum(weights, kv), checked_bytes_sum(activations, 4))
        self.host_staging_bytes = upload_staging_bytes(weights)
        self.host_upload_bytes = checked_bytes_sum(checked_bytes_sum(weights, self.host_staging_bytes), 4)

    def fits(self, free_bytes: Int, reserve_bytes: Int) raises -> Bool:
        return self.explain_device_fit(free_bytes, reserve_bytes).fits

    def explain_device_fit(self, free_bytes: Int,
                           reserve_bytes: Int) raises -> MemoryFitExplanation:
        return explain_memory_fit(
            self.device_bytes, free_bytes, reserve_bytes, "device"
        )

    def explain_host_fit(self, available_bytes: Int,
                         reserve_bytes: Int) raises -> MemoryFitExplanation:
        return explain_memory_fit(
            self.host_upload_bytes, available_bytes, reserve_bytes, "host"
        )

    def admit(self, free_bytes: Int, host_available: Int, reserve_bytes: Int) raises:
        var device_fit = self.explain_device_fit(free_bytes, reserve_bytes)
        if not device_fit.fits:
            raise Error(
                "CUDA model does not fit: " + device_fit.describe()
                + "; reduce context or choose another device; no CPU fallback"
            )
        var host_fit = self.explain_host_fit(host_available, reserve_bytes)
        if not host_fit.fits:
            raise Error(
                "Host upload does not fit: " + host_fit.describe()
                + "; reduce context or reserve"
            )

    def admit_observed(self, free_bytes: Int, reserve_bytes: Int) raises:
        self.admit(free_bytes, observe_host_memory().available_bytes, reserve_bytes)


def llama3_memory_plan(weights: Int, context: Int,
                       profile: DenseGQAProfile = llama3_8b_profile()) raises -> InferenceMemoryPlan:
    if context < 2 or context > profile.context_cap:
        raise Error(
            profile.label() + " memory context must be in 2.."
            + String(profile.context_cap)
        )
    return InferenceMemoryPlan(
        weights, profile.kv_elements(context) * 2,
        profile.activation_elements(context) * 4
            + sampling_device_bytes(profile.vocabulary_size),
    )


def gemma4_memory_plan(weights: Int, context: Int) raises -> InferenceMemoryPlan:
    return gemma4_profile_memory_plan(weights, context, gemma4_e4b_profile())


def gemma4_profile_memory_plan(weights: Int, context: Int,
                               profile: Gemma4Profile) raises -> InferenceMemoryPlan:
    if context < 2 or context > profile.context_cap:
        raise Error(profile.label() + " memory context must be in 2.." + String(profile.context_cap))
    var kv_elements = 0
    for layer in range(profile.layer_count - profile.shared_kv_layers):
        var capacity = 512 if profile.is_local(layer) else context
        kv_elements += 2 * capacity * profile.kv_heads * profile.head_dim(layer)
    var kv = kv_elements * 4
    return InferenceMemoryPlan(weights, kv, (326144 + 8 * context) * 4 + sampling_device_bytes(262144))
