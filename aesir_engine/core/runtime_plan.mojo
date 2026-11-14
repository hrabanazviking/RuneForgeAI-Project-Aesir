"""Model admission and observed single-device selection for native sessions."""
from std.math import max
from loader.packed_gguf import PackedGGUF
from core.gemma4_profile import gemma4_profile_for, validate_gemma4
from core.dense_gqa_profile import dense_gqa_profile_for, validate_dense_gqa
from core.model_registry import ModelArchitectureRegistry
from core.inference_memory import MemoryFitExplanation, InferenceMemoryPlan, gemma4_profile_memory_plan, llama3_memory_plan, qwen35_memory_plan
from core.qwen35_profile import qwen35_profile_for, validate_qwen35
from core.cuda_gate import CUDAGate
from core.amd_gate import AMDGate
from core.mimir_well import HardwareDiscoveryResult


struct NativeModelPlan(Copyable):
    var profile: String
    var variant: String
    var context_length: Int
    var memory: InferenceMemoryPlan
    var experimental: Bool

    def __init__(out self, path: String, requested_profile: String = "auto", context_length: Int = 0, experimental_qwen35: Bool = False) raises:
        if requested_profile != "auto" and requested_profile != "gemma4" and requested_profile != "llama3" and requested_profile != "qwen3" and requested_profile != "qwen35":
            raise Error("Unsupported native model profile")
        var model = PackedGGUF(path)
        var compatibility = ModelArchitectureRegistry.inspect(model, context_length)
        self.profile = requested_profile
        self.variant = ""
        self.experimental = False
        if self.profile == "auto":
            if compatibility.status != "READY" or compatibility.native_profile == "":
                raise Error(compatibility.friendly_error())
            self.profile = compatibility.native_profile
        elif self.profile == "qwen35" and compatibility.native_profile != "qwen35":
            # Q35-4a experimental admission: a qwen35 file whose geometry
            # is NOT the registry's family signature (e.g. the forward
            # fixture) carries no native_profile and is not READY. It is
            # admitted ONLY under the caller's explicit experimental
            # opt-in; the qwen35 branch below still runs
            # validate_qwen35 in full (relations + tensor contract +
            # tensor count) -- only the signature pin is skipped, and
            # the plan is marked experimental so serve health reports
            # it. Without the opt-in, the registry verdict refuses.
            if not experimental_qwen35:
                raise Error(compatibility.friendly_error())
            self.experimental = True
        elif compatibility.status != "READY":
            raise Error(compatibility.friendly_error())
        elif compatibility.native_profile != self.profile:
            raise Error(
                "Requested native profile '" + self.profile
                + "' does not match detected profile '"
                + compatibility.native_profile + "'"
            )
        self.context_length = context_length
        if self.profile == "llama3" or self.profile == "qwen3":
            var dense_profile = dense_gqa_profile_for(model)
            self.variant = self.profile + "-" + dense_profile.name
            if self.context_length == 0:
                self.context_length = compatibility.recommended_context
            validate_dense_gqa(model, dense_profile, self.context_length)
            self.memory = llama3_memory_plan(
                Int(model.source.file_size), self.context_length, dense_profile
            )
        elif self.profile == "qwen35":
            var q35_profile = qwen35_profile_for(model)
            var q35_label = compatibility.model_variant
            if q35_label == "":
                q35_label = String(q35_profile.layer_count) + "L/" + String(q35_profile.hidden_size) + "d"
            self.variant = "qwen35-" + q35_label
            if self.context_length == 0:
                self.context_length = compatibility.recommended_context
            validate_qwen35(model, q35_profile, self.context_length)
            self.memory = qwen35_memory_plan(
                Int(model.source.file_size), self.context_length, q35_profile
            )
        elif self.profile == "gemma4":
            var gemma_profile = gemma4_profile_for(model)
            self.variant = "gemma4-" + gemma_profile.name
            if self.context_length == 0:
                self.context_length = gemma_profile.context_cap
            validate_gemma4(model, gemma_profile, self.context_length)
            self.memory = gemma4_profile_memory_plan(Int(model.source.file_size), self.context_length, gemma_profile)
        else:
            raise Error("Unsupported native model profile '" + self.profile + "'")


struct NativeDeviceSelection(Copyable):
    """A model/context plan paired with the device that can admit it."""

    var plan: NativeModelPlan
    var device_index: Int
    var context_adjusted: Bool
    var device_fit: MemoryFitExplanation

    def __init__(out self, plan: NativeModelPlan, device_index: Int,
                 context_adjusted: Bool, device_fit: MemoryFitExplanation):
        self.plan = plan.copy()
        self.device_index = device_index
        self.context_adjusted = context_adjusted
        self.device_fit = device_fit.copy()


struct PlannedCUDADevice(Copyable):
    var device_index: Int
    var fit: MemoryFitExplanation

    def __init__(out self, device_index: Int, fit: MemoryFitExplanation):
        self.device_index = device_index
        self.fit = fit.copy()


def explain_device_fit(memory: InferenceMemoryPlan, free_bytes: Int,
                       reserve_bytes: Int) raises -> MemoryFitExplanation:
    return memory.explain_device_fit(free_bytes, reserve_bytes)


def explain_host_fit(memory: InferenceMemoryPlan, available_bytes: Int,
                     reserve_bytes: Int) raises -> MemoryFitExplanation:
    return memory.explain_host_fit(available_bytes, reserve_bytes)


def next_automatic_context(context: Int) raises -> Int:
    """Returns the next useful fallback context, or zero when none remains."""
    if context < 2:
        raise Error("Automatic context requires a valid starting context")
    if context <= 2048:
        return 0
    return max(2048, context // 2)


def select_planned_device_with_fit(
    memory: InferenceMemoryPlan, discovered: HardwareDiscoveryResult,
    requested_index: Int, reserve_bytes: Int, api: String
) raises -> PlannedCUDADevice:
    """Fit selection over discovered devices of one runtime api.

    The CUDA road is this function with api="cuda"; the HIP road is
    api="hip". Candidate labels and the refusal name the requested
    realm honestly; nothing about the fit arithmetic is realm-specific.
    """
    var realm = "CUDA" if api == "cuda" else "HIP"
    discovered.validate()
    if requested_index < -1 or reserve_bytes < 0:
        raise Error("Invalid device selection or memory reserve")
    var selected = -1
    var most_free = -1
    var selected_fit = MemoryFitExplanation(
        False, "device_not_selected", memory.device_bytes, 0,
        reserve_bytes, 0, memory.device_bytes, 0
    )
    var candidates = String("")
    var requested_seen = False
    for device in discovered.devices:
        if requested_index >= 0 and device.backend_index != requested_index:
            continue
        requested_seen = True
        var label = api + ":" + String(device.backend_index) + "="
        if device.api != api:
            candidates += label + "device_api_not_" + api + "(api=" + device.api + ");"
            continue
        if not device.capabilities.is_compatible:
            candidates += label + "device_incompatible;"
            continue
        var free = device.capabilities.free_memory_bytes
        if free > UInt(9223372036854775807):
            candidates += label + "device_memory_exceeds_native_range;"
            continue
        var fit = explain_device_fit(memory, Int(free), reserve_bytes)
        if not fit.fits:
            candidates += label + fit.describe() + ";"
        elif Int(free) > most_free:
            selected = device.backend_index
            most_free = Int(free)
            selected_fit = fit.copy()
    if selected < 0:
        if requested_index >= 0 and not requested_seen:
            candidates += api + ":" + String(requested_index) + "=requested_device_not_found;"
        raise Error(
            "No compatible " + realm + " device fits the requested model/context/reserve (device="
            + String(requested_index) + "); candidates=" + candidates
            + " discovery=" + discovered.status.name() + ": " + discovered.message
            + "; no CPU fallback"
        )
    return PlannedCUDADevice(selected, selected_fit)


def select_planned_cuda_with_fit(
    memory: InferenceMemoryPlan, discovered: HardwareDiscoveryResult,
    requested_index: Int, reserve_bytes: Int
) raises -> PlannedCUDADevice:
    return select_planned_device_with_fit(
        memory, discovered, requested_index, reserve_bytes, "cuda"
    )


def select_planned_cuda(memory: InferenceMemoryPlan, discovered: HardwareDiscoveryResult,
                        requested_index: Int, reserve_bytes: Int) raises -> Int:
    return select_planned_cuda_with_fit(
        memory, discovered, requested_index, reserve_bytes
    ).device_index


def choose_native_cuda(memory: InferenceMemoryPlan, requested_index: Int = -1,
                       reserve_bytes: Int = 268435456) raises -> Int:
    return select_planned_cuda(memory, CUDAGate.discover_physical_devices(),
                               requested_index, reserve_bytes)


def choose_native_cuda_plan(path: String, requested_profile: String = "auto",
                            requested_context: Int = 0,
                            requested_index: Int = -1,
                            reserve_bytes: Int = 268435456) raises -> NativeDeviceSelection:
    """Selects the largest recommended context that observed CUDA memory fits.

    An explicit context is never changed. Automatic contexts step down by powers
    of two to a practical 2K floor, preserving the user's device and reserve.
    """
    if requested_index < -1 or reserve_bytes < 0:
        raise Error("Invalid device selection or memory reserve")
    var discovered = CUDAGate.discover_physical_devices()
    discovered.validate()
    var plan = NativeModelPlan(path, requested_profile, requested_context)
    if requested_context != 0:
        var selected = select_planned_cuda_with_fit(
            plan.memory, discovered, requested_index, reserve_bytes
        )
        return NativeDeviceSelection(
            plan, selected.device_index, False, selected.fit
        )
    var original_context = plan.context_length
    while True:
        try:
            var selected = select_planned_cuda_with_fit(
                plan.memory, discovered, requested_index, reserve_bytes
            )
            return NativeDeviceSelection(
                plan, selected.device_index,
                plan.context_length != original_context, selected.fit
            )
        except error:
            var final_fit_error = String(error)
            var next_context = next_automatic_context(plan.context_length)
            if next_context == 0:
                raise Error(
                    "No compatible CUDA device fits this model with the "
                    + String(reserve_bytes)
                    + "-byte reserve, even at the automatic 2048-token context; "
                    + "choose another device/model or lower --reserve-mib; final_fit="
                    + final_fit_error
                )
            plan = NativeModelPlan(path, plan.profile, next_context)


def select_planned_hip(memory: InferenceMemoryPlan, discovered: HardwareDiscoveryResult,
                       requested_index: Int, reserve_bytes: Int) raises -> Int:
    return select_planned_device_with_fit(
        memory, discovered, requested_index, reserve_bytes, "hip"
    ).device_index


def choose_native_hip(memory: InferenceMemoryPlan, requested_index: Int = -1,
                      reserve_bytes: Int = 268435456) raises -> Int:
    return select_planned_hip(memory, AMDGate.discover_physical_devices(),
                              requested_index, reserve_bytes)


def choose_native_hip_plan(path: String, requested_profile: String = "auto",
                           requested_context: Int = 0,
                           requested_index: Int = -1,
                           reserve_bytes: Int = 268435456) raises -> NativeDeviceSelection:
    """Selects the largest recommended context that observed HIP memory fits.

    Mirrors choose_native_cuda_plan over AMDGate discovery: an explicit
    context is never changed; automatic contexts step down by powers of
    two to a practical 2K floor, preserving device and reserve.
    """
    if requested_index < -1 or reserve_bytes < 0:
        raise Error("Invalid device selection or memory reserve")
    var discovered = AMDGate.discover_physical_devices()
    discovered.validate()
    var plan = NativeModelPlan(path, requested_profile, requested_context)
    if requested_context != 0:
        var selected = select_planned_device_with_fit(
            plan.memory, discovered, requested_index, reserve_bytes, "hip"
        )
        return NativeDeviceSelection(
            plan, selected.device_index, False, selected.fit
        )
    var original_context = plan.context_length
    while True:
        try:
            var selected = select_planned_device_with_fit(
                plan.memory, discovered, requested_index, reserve_bytes, "hip"
            )
            return NativeDeviceSelection(
                plan, selected.device_index,
                plan.context_length != original_context, selected.fit
            )
        except error:
            var final_fit_error = String(error)
            var next_context = next_automatic_context(plan.context_length)
            if next_context == 0:
                raise Error(
                    "No compatible HIP device fits this model with the "
                    + String(reserve_bytes)
                    + "-byte reserve, even at the automatic 2048-token context; "
                    + "choose another device/model or lower --reserve-mib; final_fit="
                    + final_fit_error
                )
            plan = NativeModelPlan(path, plan.profile, next_context)
