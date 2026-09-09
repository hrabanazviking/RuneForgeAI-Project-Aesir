"""Model admission and observed single-device selection for native sessions."""
from loader.packed_gguf import PackedGGUF
from core.gemma4_profile import gemma4_profile_for, validate_gemma4
from core.dense_gqa_profile import dense_gqa_profile_for, validate_dense_gqa
from core.model_registry import ModelArchitectureRegistry
from core.inference_memory import InferenceMemoryPlan, gemma4_profile_memory_plan, llama3_memory_plan
from core.cuda_gate import CUDAGate
from core.mimir_well import HardwareDiscoveryResult


struct NativeModelPlan(Copyable):
    var profile: String
    var variant: String
    var context_length: Int
    var memory: InferenceMemoryPlan

    def __init__(out self, path: String, requested_profile: String = "auto", context_length: Int = 0) raises:
        if requested_profile != "auto" and requested_profile != "gemma4" and requested_profile != "llama3" and requested_profile != "qwen3":
            raise Error("Unsupported native model profile")
        var model = PackedGGUF(path)
        var compatibility = ModelArchitectureRegistry.inspect(model, context_length)
        self.profile = requested_profile
        self.variant = ""
        if self.profile == "auto":
            if compatibility.status != "READY" or compatibility.native_profile == "":
                raise Error(compatibility.friendly_error())
            self.profile = compatibility.native_profile
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
        else:
            var gemma_profile = gemma4_profile_for(model)
            self.variant = "gemma4-" + gemma_profile.name
            if self.context_length == 0:
                self.context_length = gemma_profile.context_cap
            validate_gemma4(model, gemma_profile, self.context_length)
            self.memory = gemma4_profile_memory_plan(Int(model.source.file_size), self.context_length, gemma_profile)


def select_planned_cuda(memory: InferenceMemoryPlan, discovered: HardwareDiscoveryResult,
                        requested_index: Int, reserve_bytes: Int) raises -> Int:
    discovered.validate()
    if requested_index < -1 or reserve_bytes < 0:
        raise Error("Invalid device selection or memory reserve")
    var selected = -1
    var most_free = -1
    for device in discovered.devices:
        if requested_index >= 0 and device.backend_index != requested_index:
            continue
        if device.api != "cuda" or not device.capabilities.is_compatible:
            continue
        var free = device.capabilities.free_memory_bytes
        if free > UInt(9223372036854775807):
            raise Error("Device memory exceeds native address range")
        if memory.fits(Int(free), reserve_bytes) and Int(free) > most_free:
            selected = device.backend_index
            most_free = Int(free)
    if selected < 0:
        raise Error("No compatible CUDA device fits the requested model/context/reserve (device="
                    + String(requested_index) + "); discovery=" + discovered.status.name()
                    + ": " + discovered.message + "; no CPU fallback")
    return selected


def choose_native_cuda(memory: InferenceMemoryPlan, requested_index: Int = -1,
                       reserve_bytes: Int = 268435456) raises -> Int:
    return select_planned_cuda(memory, CUDAGate.discover_physical_devices(),
                               requested_index, reserve_bytes)
