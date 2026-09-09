"""Pure architecture recognition and compatibility-policy regressions."""
from core.model_registry import (
    ModelArchitectureRegistry,
    gguf_quantization_name,
    native_quantization_supported,
)
from core.llama3_profile import llama3_8b_profile


def test_model_architecture_registry() raises:
    var llama_profile = llama3_8b_profile()
    if (llama_profile.layer_count != 32 or llama_profile.hidden_size != 4096
            or llama_profile.feed_forward_size != 14336):
        raise Error("Llama 3 8B family profile dimensions drifted")
    if (llama_profile.kv_width() != 1024
            or llama_profile.activation_elements(8192) != 441600
            or llama_profile.kv_elements(8192) != 536870912):
        raise Error("Llama 3 8B profile memory dimensions drifted")
    if gguf_quantization_name(15) != "Q4_K_M":
        raise Error("GGUF Q4_K_M file type mapping drifted")
    if gguf_quantization_name(17) != "Q5_K_M":
        raise Error("GGUF Q5_K_M file type mapping drifted")
    if gguf_quantization_name(18) != "Q6_K":
        raise Error("GGUF Q6_K file type mapping drifted")
    if not native_quantization_supported("Q5_K_S"):
        raise Error("native K-quant support policy drifted")

    var gemma_e2b = ModelArchitectureRegistry.classify(
        "gemma4", "2B", 35, 1536, 131072, 15, ""
    )
    if gemma_e2b.family != "Gemma 4" or gemma_e2b.model_variant != "E2B":
        raise Error("Gemma 4 E2B recognition drifted")
    if gemma_e2b.status != "READY" or gemma_e2b.compatibility != "VERIFIED":
        raise Error("Gemma 4 E2B readiness drifted")
    if gemma_e2b.recommended_context != 16384 or not gemma_e2b.cuda_support:
        raise Error("Gemma 4 E2B capability policy drifted")

    var gemma_e4b = ModelArchitectureRegistry.classify(
        "gemma4", "4B", 42, 2560, 131072, 17, ""
    )
    if gemma_e4b.model_variant != "E4B" or gemma_e4b.compatibility != "COMPATIBLE":
        raise Error("Gemma 4 E4B compatible K-quant policy drifted")

    var llama = ModelArchitectureRegistry.classify(
        "llama", "8B", 32, 4096, 131072, 14, ""
    )
    if llama.native_profile != "llama3" or llama.status != "READY":
        raise Error("Llama 3 8B native profile recognition drifted")
    if llama.chat_template != "llama3" or llama.recommended_context != 8192:
        raise Error("Llama 3 defaults drifted")

    var qwen = ModelArchitectureRegistry.classify(
        "qwen3", "4B", 36, 2560, 32768, 15, "<|im_start|>system"
    )
    if qwen.family != "Qwen" or qwen.compatibility != "EXPERIMENTAL":
        raise Error("Qwen recognition drifted")
    if qwen.status != "NOT READY" or qwen.chat_template != "ChatML-compatible":
        raise Error("Qwen truthful readiness policy drifted")

    var mistral = ModelArchitectureRegistry.classify(
        "mistral", "7B", 32, 4096, 32768, 15, ""
    )
    if mistral.family != "Mistral" or mistral.status != "NOT READY":
        raise Error("Mistral recognition policy drifted")

    var unknown = ModelArchitectureRegistry.classify(
        "fimbul", "", 12, 768, 2048, 2, ""
    )
    if unknown.status != "UNSUPPORTED" or unknown.compatibility != "UNSUPPORTED":
        raise Error("unknown architecture admission drifted")
    var message = unknown.friendly_error()
    if "Architecture: fimbul" not in message or "aesir inspect" not in message:
        raise Error("unsupported-model diagnostic lost required context")
