"""Pure architecture recognition and compatibility-policy regressions."""
from core.model_registry import (
    ModelArchitectureRegistry,
    gguf_quantization_name,
    native_quantization_supported,
    native_k_quantization_supported,
    qwen3_0_6b_quantization_verified,
)
from core.dense_gqa_profile import llama3_8b_profile, llama3_2_3b_profile, qwen3_0_6b_profile
from cli.model_inspect import model_inspection_json


def test_model_architecture_registry() raises:
    var small = llama3_2_3b_profile()
    if (small.conversation_profile() != "llama3"
            or llama3_8b_profile().conversation_profile() != "llama3"
            or qwen3_0_6b_profile().conversation_profile() != "qwen3"):
        raise Error("Native snapshot profile confused GGUF architecture with family")
    if (small.layer_count != 28 or small.hidden_size != 3072
            or small.query_width() != 3072 or small.kv_width() != 1024
            or small.expected_tensor_count != 255 or not small.tied_embeddings
            or not small.rope_factors or small.context_cap != 8192):
        raise Error("Llama 3.2 3B layout policy drifted")
    var small_report = ModelArchitectureRegistry.classify(
        "llama", "3B", 28, 3072, 131072, 15, ""
    )
    if (small_report.status != "READY" or small_report.model_variant != "3B"
            or small_report.compatibility != "COMPATIBLE"):
        raise Error("Llama 3.2 3B admission policy drifted")
    var llama_profile = llama3_8b_profile()
    if (llama_profile.layer_count != 32 or llama_profile.hidden_size != 4096
            or llama_profile.feed_forward_size != 14336):
        raise Error("Llama 3 8B family profile dimensions drifted")
    if (llama_profile.kv_width() != 1024
            or llama_profile.activation_elements(8192) != 441600
            or llama_profile.kv_elements(8192) != 536870912):
        raise Error("Llama 3 8B profile memory dimensions drifted")
    var qwen_profile = qwen3_0_6b_profile()
    if (qwen_profile.layer_count != 28 or qwen_profile.hidden_size != 1024
            or qwen_profile.feed_forward_size != 3072
            or not qwen_profile.qk_norm or not qwen_profile.neox_rope):
        raise Error("Qwen 3 0.6B family profile drifted")
    if (qwen_profile.query_width() != 2048 or qwen_profile.kv_width() != 1024
            or qwen_profile.activation_elements(2048) != 200064):
        raise Error("Qwen 3 0.6B profile workspace dimensions drifted")
    if gguf_quantization_name(15) != "Q4_K_M":
        raise Error("GGUF Q4_K_M file type mapping drifted")
    if gguf_quantization_name(17) != "Q5_K_M":
        raise Error("GGUF Q5_K_M file type mapping drifted")
    if gguf_quantization_name(18) != "Q6_K":
        raise Error("GGUF Q6_K file type mapping drifted")
    # S-092 kind-table freeze: the full llama_ftype table is pinned.
    # Every value observed in the acquired stores (S-092 census of 284
    # files: 0,1,2,3,7,10-31) plus the enum's remaining live values.
    if gguf_quantization_name(0) != "F32":
        raise Error("GGUF F32 file type mapping drifted")
    if gguf_quantization_name(1) != "F16":
        raise Error("GGUF F16 file type mapping drifted")
    if gguf_quantization_name(2) != "Q4_0":
        raise Error("GGUF Q4_0 file type mapping drifted")
    if gguf_quantization_name(3) != "Q4_1":
        raise Error("GGUF Q4_1 file type mapping drifted")
    if gguf_quantization_name(7) != "Q8_0":
        raise Error("GGUF Q8_0 file type mapping drifted")
    if gguf_quantization_name(8) != "Q5_0":
        raise Error("GGUF Q5_0 file type mapping drifted")
    if gguf_quantization_name(9) != "Q5_1":
        raise Error("GGUF Q5_1 file type mapping drifted")
    if gguf_quantization_name(10) != "Q2_K":
        raise Error("GGUF Q2_K file type mapping drifted")
    if gguf_quantization_name(11) != "Q3_K_S":
        raise Error("GGUF Q3_K_S file type mapping drifted")
    if gguf_quantization_name(12) != "Q3_K_M":
        raise Error("GGUF Q3_K_M file type mapping drifted")
    if gguf_quantization_name(13) != "Q3_K_L":
        raise Error("GGUF Q3_K_L file type mapping drifted")
    if gguf_quantization_name(14) != "Q4_K_S":
        raise Error("GGUF Q4_K_S file type mapping drifted")
    if gguf_quantization_name(16) != "Q5_K_S":
        raise Error("GGUF Q5_K_S file type mapping drifted")
    if gguf_quantization_name(19) != "IQ2_XXS":
        raise Error("GGUF IQ2_XXS file type mapping drifted")
    if gguf_quantization_name(20) != "IQ2_XS":
        raise Error("GGUF IQ2_XS file type mapping drifted")
    if gguf_quantization_name(21) != "Q2_K_S":
        raise Error("GGUF Q2_K_S file type mapping drifted")
    if gguf_quantization_name(22) != "IQ3_XS":
        raise Error("GGUF IQ3_XS file type mapping drifted")
    if gguf_quantization_name(23) != "IQ3_XXS":
        raise Error("GGUF IQ3_XXS file type mapping drifted")
    if gguf_quantization_name(24) != "IQ1_S":
        raise Error("GGUF IQ1_S file type mapping drifted")
    if gguf_quantization_name(25) != "IQ4_NL":
        raise Error("GGUF IQ4_NL file type mapping drifted")
    if gguf_quantization_name(26) != "IQ3_S":
        raise Error("GGUF IQ3_S file type mapping drifted")
    if gguf_quantization_name(27) != "IQ3_M":
        raise Error("GGUF IQ3_M file type mapping drifted")
    if gguf_quantization_name(28) != "IQ2_S":
        raise Error("GGUF IQ2_S file type mapping drifted")
    if gguf_quantization_name(29) != "IQ2_M":
        raise Error("GGUF IQ2_M file type mapping drifted")
    if gguf_quantization_name(30) != "IQ4_XS":
        raise Error("GGUF IQ4_XS file type mapping drifted")
    if gguf_quantization_name(31) != "IQ1_M":
        raise Error("GGUF IQ1_M file type mapping drifted")
    if gguf_quantization_name(32) != "BF16":
        raise Error("GGUF BF16 file type mapping drifted")
    if gguf_quantization_name(36) != "TQ1_0":
        raise Error("GGUF TQ1_0 file type mapping drifted")
    if gguf_quantization_name(37) != "TQ2_0":
        raise Error("GGUF TQ2_0 file type mapping drifted")
    if gguf_quantization_name(38) != "MXFP4_MOE":
        raise Error("GGUF MXFP4_MOE file type mapping drifted")
    if gguf_quantization_name(39) != "NVFP4":
        raise Error("GGUF NVFP4 file type mapping drifted")
    if gguf_quantization_name(40) != "Q1_0":
        raise Error("GGUF Q1_0 file type mapping drifted")
    if gguf_quantization_name(4) != "unknown(4)":
        raise Error("GGUF removed file type 4 must stay unnamed")
    if gguf_quantization_name(1024) != "unknown(1024)":
        raise Error("GGUF GUESSED file type must stay unnamed")
    if not native_quantization_supported("Q5_K_S"):
        raise Error("native K-quant support policy drifted")
    if not native_k_quantization_supported("Q6_K") or native_k_quantization_supported("F16"):
        raise Error("native K-quant-only admission drifted")
    if (not qwen3_0_6b_quantization_verified("Q4_K_M")
            or not qwen3_0_6b_quantization_verified("Q5_K_M")
            or not qwen3_0_6b_quantization_verified("Q6_K")
            or qwen3_0_6b_quantization_verified("Q4_K_S")):
        raise Error("Qwen physical K-quant evidence policy drifted")

    var gemma_e2b = ModelArchitectureRegistry.classify(
        "gemma4", "2B", 35, 1536, 131072, 15, ""
    )
    if gemma_e2b.family != "Gemma 4" or gemma_e2b.model_variant != "E2B":
        raise Error("Gemma 4 E2B recognition drifted")
    if gemma_e2b.status != "READY" or gemma_e2b.compatibility != "VERIFIED":
        raise Error("Gemma 4 E2B readiness drifted")
    if gemma_e2b.recommended_context != 16384 or not gemma_e2b.cuda_support:
        raise Error("Gemma 4 E2B capability policy drifted")
    if gemma_e2b.tensor_validation != "not_run" or gemma_e2b.requested_context != 0:
        raise Error("Classification fabricated tensor/context inspection evidence")
    gemma_e2b.requested_context = 4096
    gemma_e2b.evaluated_context = 4096
    gemma_e2b.tensor_validation = "passed"
    gemma_e2b.estimated_vram_bytes = 123456
    var report = model_inspection_json(gemma_e2b)
    if ('"schema_version":1' not in report
            or '"scope":"gguf_metadata_and_native_layout"' not in report
            or '"execution_tested":false' not in report
            or '"requested_context":4096' not in report
            or '"evaluated_context":4096' not in report
            or '"tensor_validation":"passed"' not in report
            or '"estimated_vram_bytes":123456' not in report):
        raise Error("Versioned model inspection report omitted evidence boundaries")

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

    var qwen_0_6b = ModelArchitectureRegistry.classify(
        "qwen3", "0.6B", 28, 1024, 40960, 15, "<|im_start|>system"
    )
    if (qwen_0_6b.status != "READY" or qwen_0_6b.native_profile != "qwen3"
            or qwen_0_6b.compatibility != "VERIFIED"):
        raise Error("Qwen 3 0.6B native admission drifted")
    if qwen_0_6b.recommended_context != 8192 or not qwen_0_6b.cuda_support:
        raise Error("Qwen 3 0.6B practical defaults drifted")
    var qwen_q5 = ModelArchitectureRegistry.classify(
        "qwen3", "0.6B", 28, 1024, 40960, 17, "<|im_start|>system"
    )
    var qwen_q6 = ModelArchitectureRegistry.classify(
        "qwen3", "0.6B", 28, 1024, 40960, 18, "<|im_start|>system"
    )
    if qwen_q5.compatibility != "VERIFIED" or qwen_q6.compatibility != "VERIFIED":
        raise Error("Qwen Q5_K_M/Q6_K evidence classification drifted")

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
