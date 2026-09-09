"""Central GGUF architecture recognition and executable compatibility policy.

The registry describes what a model is and whether this build can run it. It
does not own tensors, CUDA resources, tokenization state, or generation loops.
"""
from loader.packed_gguf import PackedGGUF
from loader.chat_template import RuneChatTemplate
from core.gemma4_profile import gemma4_profile_for, validate_gemma4
from core.llama3_profile import llama3_profile_for, validate_llama3
from core.inference_memory import InferenceMemoryPlan, gemma4_profile_memory_plan, llama3_memory_plan


comptime NATIVE_K_QUANTS = "Q4_K_S, Q4_K_M, Q5_K_S, Q5_K_M, Q6_K"


def gguf_quantization_name(file_type: Int) -> String:
    if file_type == 0:
        return "F32"
    if file_type == 1:
        return "F16"
    if file_type == 2:
        return "Q4_0"
    if file_type == 3:
        return "Q4_1"
    if file_type == 7:
        return "Q8_0"
    if file_type == 14:
        return "Q4_K_S"
    if file_type == 15:
        return "Q4_K_M"
    if file_type == 16:
        return "Q5_K_S"
    if file_type == 17:
        return "Q5_K_M"
    if file_type == 18:
        return "Q6_K"
    if file_type == 32:
        return "BF16"
    return "unknown(" + String(file_type) + ")"


def native_quantization_supported(name: String) -> Bool:
    return name == "Q4_K_S" or name == "Q4_K_M" or name == "Q5_K_S" or name == "Q5_K_M" or name == "Q6_K" or name == "F16" or name == "BF16" or name == "F32"


struct ModelCompatibility(Copyable):
    var name: String
    var architecture: String
    var family: String
    var model_variant: String
    var quantization: String
    var tokenizer_family: String
    var chat_template: String
    var attention_type: String
    var rope_type: String
    var activation: String
    var normalization: String
    var density: String
    var tensor_naming: String
    var supported_quantizations: String
    var metadata_context: Int
    var recommended_context: Int
    var cuda_support: Bool
    var cpu_support: Bool
    var capability_flags: String
    var compatibility: String
    var status: String
    var native_profile: String
    var reason: String
    var estimated_vram_bytes: Int

    def __init__(out self):
        self.name = "unknown"
        self.architecture = "unknown"
        self.family = "unknown"
        self.model_variant = "unknown"
        self.quantization = "unknown"
        self.tokenizer_family = "unknown"
        self.chat_template = "unknown"
        self.attention_type = "unknown"
        self.rope_type = "unknown"
        self.activation = "unknown"
        self.normalization = "unknown"
        self.density = "unknown"
        self.tensor_naming = "unknown"
        self.supported_quantizations = ""
        self.metadata_context = 0
        self.recommended_context = 0
        self.cuda_support = False
        self.cpu_support = False
        self.capability_flags = "inspection"
        self.compatibility = "UNSUPPORTED"
        self.status = "UNSUPPORTED"
        self.native_profile = ""
        self.reason = "No architecture adapter is registered."
        self.estimated_vram_bytes = 0

    def friendly_error(self) -> String:
        return (
            "Aesir cannot run this model yet.\n\nArchitecture: " + self.architecture
            + "\nVariant: " + self.model_variant
            + "\nQuantization: " + self.quantization
            + "\n\nReason:\n" + self.reason
            + "\n\nTry:\naesir inspect <model.gguf>\n\nCompatibility: " + self.compatibility
        )


def _optional_text(model: PackedGGUF, key: String) raises -> String:
    if model.field_types.get(key, -1) != 8:
        return ""
    return model.text(key)


struct ModelArchitectureRegistry:
    """Recognizes architecture families and binds them to proven adapters."""

    @staticmethod
    def classify(architecture: String, size_label: String, layers: Int,
                 hidden: Int, metadata_context: Int, file_type: Int,
                 jinja_template: String) -> ModelCompatibility:
        var result = ModelCompatibility()
        result.architecture = architecture if architecture != "" else "unknown"
        result.name = result.architecture
        result.quantization = gguf_quantization_name(file_type)
        result.metadata_context = metadata_context
        if jinja_template != "":
            var detected = RuneChatTemplate.detect_template_family(jinja_template)
            result.chat_template = "ChatML-compatible" if detected == "chatml" else detected

        if architecture == "gemma4":
            result.family = "Gemma 4"
            result.tokenizer_family = "Gemma BPE"
            result.chat_template = "gemma" if jinja_template == "" else result.chat_template
            result.attention_type = "hybrid sliding/full grouped-query"
            result.rope_type = "Gemma local/global RoPE"
            result.activation = "GELU gated"
            result.normalization = "RMSNorm"
            result.density = "dense"
            result.tensor_naming = "gemma4/blk.*"
            result.supported_quantizations = NATIVE_K_QUANTS + ", F16, BF16, F32"
            result.native_profile = "gemma4"
            if layers == 35 and hidden == 1536:
                result.model_variant = "E2B"
                result.recommended_context = min(metadata_context, 16384)
            elif layers == 42 and hidden == 2560:
                result.model_variant = "E4B"
                result.recommended_context = min(metadata_context, 32768)
            else:
                result.reason = "Gemma 4 is recognized, but this variant has no matching native profile."
                result.compatibility = "EXPERIMENTAL"
                result.status = "NOT READY"
                return result^
            if not native_quantization_supported(result.quantization):
                result.reason = "The Gemma 4 adapter does not support this GGUF quantization."
                result.status = "NOT READY"
                return result^
            result.cuda_support = True
            result.capability_flags = "text, chat, persistent-chat, cuda"
            result.compatibility = "VERIFIED" if result.quantization == "Q4_K_M" else "COMPATIBLE"
            result.status = "READY"
            result.reason = "Matched a native Gemma 4 variant profile."
            return result^

        if architecture == "llama":
            result.family = "Llama 3.x"
            result.tokenizer_family = "Llama 3 BPE"
            result.chat_template = "llama3" if jinja_template == "" else result.chat_template
            result.attention_type = "grouped-query causal"
            result.rope_type = "Llama RoPE"
            result.activation = "SwiGLU"
            result.normalization = "RMSNorm"
            result.density = "dense"
            result.tensor_naming = "llama/blk.*"
            result.supported_quantizations = NATIVE_K_QUANTS
            result.native_profile = "llama3"
            if layers != 32 or hidden != 4096:
                result.model_variant = size_label if size_label != "" else String(layers) + "L/" + String(hidden) + "d"
                result.reason = "Llama is recognized, but this build only has the strict 8B native profile."
                result.compatibility = "EXPERIMENTAL"
                result.status = "NOT READY"
                return result^
            result.model_variant = "8B"
            result.recommended_context = min(metadata_context, 8192)
            if not native_quantization_supported(result.quantization) or result.quantization == "F16" or result.quantization == "BF16" or result.quantization == "F32":
                result.reason = "The current Llama 3 adapter requires a supported K-quant GGUF."
                result.status = "NOT READY"
                return result^
            result.cuda_support = True
            result.capability_flags = "text, chat, persistent-chat, cuda"
            result.compatibility = "VERIFIED" if result.quantization == "Q4_K_S" else "COMPATIBLE"
            result.status = "READY"
            result.reason = "Matched the native Llama 3 8B profile."
            return result^

        if architecture == "qwen2" or architecture == "qwen3":
            result.family = "Qwen"
            result.model_variant = size_label if size_label != "" else String(layers) + "L/" + String(hidden) + "d"
            result.tokenizer_family = "Qwen BPE"
            result.chat_template = "ChatML-compatible" if jinja_template == "" else result.chat_template
            result.attention_type = "grouped-query causal"
            result.rope_type = "Qwen RoPE"
            result.activation = "SwiGLU"
            result.normalization = "RMSNorm"
            result.density = "dense"
            result.tensor_naming = architecture + "/blk.*"
            result.supported_quantizations = NATIVE_K_QUANTS
            result.recommended_context = min(metadata_context, 32768)
            result.compatibility = "EXPERIMENTAL"
            result.status = "NOT READY"
            result.reason = "Qwen is recognized, but its native CUDA adapter is not implemented yet."
            return result^

        if architecture == "mistral":
            result.family = "Mistral"
            result.model_variant = size_label if size_label != "" else String(layers) + "L/" + String(hidden) + "d"
            result.tokenizer_family = "Mistral tokenizer"
            result.attention_type = "sliding-window causal"
            result.rope_type = "Mistral RoPE"
            result.activation = "SwiGLU"
            result.normalization = "RMSNorm"
            result.density = "dense"
            result.tensor_naming = "llama/blk.*"
            result.supported_quantizations = NATIVE_K_QUANTS
            result.recommended_context = min(metadata_context, 32768)
            result.compatibility = "EXPERIMENTAL"
            result.status = "NOT READY"
            result.reason = "Mistral is recognized, but its native CUDA adapter is not implemented yet."
            return result^

        return result^

    @staticmethod
    def inspect(model: PackedGGUF, requested_context: Int = 0) raises -> ModelCompatibility:
        var architecture = _optional_text(model, "general.architecture")
        var prefix = architecture + "."
        var result = Self.classify(
            architecture,
            _optional_text(model, "general.size_label"),
            model.integer(prefix + "block_count", 0),
            model.integer(prefix + "embedding_length", 0),
            model.integer(prefix + "context_length", 0),
            model.integer("general.file_type", 999),
            _optional_text(model, "tokenizer.chat_template"),
        )
        var observed_name = _optional_text(model, "general.name")
        if observed_name != "":
            result.name = observed_name
        if result.status != "READY":
            return result^
        var context = requested_context if requested_context != 0 else result.recommended_context
        try:
            if result.native_profile == "gemma4":
                var profile = gemma4_profile_for(model)
                validate_gemma4(model, profile, context)
                var gemma_memory = gemma4_profile_memory_plan(Int(model.source.file_size), context, profile)
                result.estimated_vram_bytes = gemma_memory.device_bytes
            else:
                var llama_profile = llama3_profile_for(model)
                validate_llama3(model, llama_profile, context)
                var llama_memory = llama3_memory_plan(
                    Int(model.source.file_size), context, llama_profile
                )
                result.estimated_vram_bytes = llama_memory.device_bytes
        except:
            result.cuda_support = False
            result.status = "NOT READY"
            result.compatibility = "UNSUPPORTED"
            result.reason = "Metadata or tensor layout does not match the registered native adapter."
            result.estimated_vram_bytes = 0
        return result^
