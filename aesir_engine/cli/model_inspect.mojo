"""Read-only GGUF model inspection backed by the architecture registry."""
from loader.packed_gguf import PackedGGUF
from core.model_registry import ModelArchitectureRegistry, ModelCompatibility
from cli.model_reference import resolve_model_reference
from server.api import json_escape_string


def _inspect_positive_int(value: String) raises -> Int:
    if len(value.bytes()) == 0:
        raise Error("--context requires a positive integer")
    var result = 0
    for byte in value.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("--context requires a positive integer")
        var digit = Int(byte - 48)
        if result > (9223372036854775807 - digit) // 10:
            raise Error("--context value overflows native integer range")
        result = result * 10 + digit
    if result <= 0:
        raise Error("--context requires a positive integer")
    return result


def _json_bool(value: Bool) -> String:
    return "true" if value else "false"


def _json_field(name: String, value: String) -> String:
    return '"' + name + '":"' + json_escape_string(value) + '"'


def model_inspection_json(result: ModelCompatibility) -> String:
    return (
        '{"schema_version":1,"scope":"gguf_metadata_and_native_layout",'
        + '"execution_tested":false,'
        + _json_field("name", result.name) + ","
        + _json_field("architecture", result.architecture) + ","
        + _json_field("family", result.family) + ","
        + _json_field("variant", result.model_variant) + ","
        + _json_field("quantization", result.quantization) + ","
        + _json_field("tokenizer_family", result.tokenizer_family) + ","
        + _json_field("chat_template", result.chat_template) + ","
        + _json_field("attention", result.attention_type) + ","
        + _json_field("rope", result.rope_type) + ","
        + _json_field("activation", result.activation) + ","
        + _json_field("normalization", result.normalization) + ","
        + _json_field("density", result.density) + ","
        + _json_field("tensor_naming", result.tensor_naming) + ","
        + _json_field("supported_quantizations", result.supported_quantizations) + ","
        + '"metadata_context":' + String(result.metadata_context) + ","
        + '"recommended_context":' + String(result.recommended_context) + ","
        + '"requested_context":' + String(result.requested_context) + ","
        + '"evaluated_context":' + String(result.evaluated_context) + ","
        + _json_field("tensor_validation", result.tensor_validation) + ","
        + '"estimated_vram_bytes":' + String(result.estimated_vram_bytes) + ","
        + '"cuda_support":' + _json_bool(result.cuda_support) + ","
        + '"cpu_support":' + _json_bool(result.cpu_support) + ","
        + _json_field("capabilities", result.capability_flags) + ","
        + _json_field("compatibility", result.compatibility) + ","
        + _json_field("status", result.status) + ","
        + _json_field("native_profile", result.native_profile) + ","
        + _json_field("reason", result.reason)
        + "}"
    )


def print_model_inspection_text(result: ModelCompatibility):
    print("Inspection scope:        GGUF metadata and native tensor layout")
    print("Execution tested:        no")
    print("Model:                   " + result.name)
    print("Architecture:            " + result.architecture)
    print("Family / variant:        " + result.family + " / " + result.model_variant)
    print("Quantization:            " + result.quantization)
    print("Tokenizer family:        " + result.tokenizer_family)
    print("Chat template:           " + result.chat_template)
    print("Attention:               " + result.attention_type)
    print("RoPE:                    " + result.rope_type)
    print("Activation:              " + result.activation)
    print("Normalization:           " + result.normalization)
    print("Density:                 " + result.density)
    print("Tensor naming:           " + result.tensor_naming)
    print("Supported quantizations: " + result.supported_quantizations)
    print("Metadata context:        " + String(result.metadata_context))
    print("Recommended context:     " + String(result.recommended_context))
    print("Requested context:       " + String(result.requested_context))
    print("Evaluated context:       " + String(result.evaluated_context))
    print("Tensor validation:       " + result.tensor_validation)
    print("Estimated VRAM bytes:    " + String(result.estimated_vram_bytes))
    print("CUDA support:            " + ("yes" if result.cuda_support else "no"))
    print("CPU support:             " + ("yes" if result.cpu_support else "no"))
    print("Capabilities:            " + result.capability_flags)
    print("Compatibility:           " + result.compatibility)
    print("Status:                  " + result.status)
    print("Reason:                  " + result.reason)


def inspect_model_reference(reference: String, model_store: String) raises -> ModelCompatibility:
    var resolved = resolve_model_reference(reference, model_store)
    var model = PackedGGUF(resolved.path)
    return ModelArchitectureRegistry.inspect(model, 0)


def dispatch_model_inspect(args: List[String]) raises:
    """Parses and executes `aesir inspect <model>`."""
    var model_path = String("")
    var format = String("text")
    var context = 0
    var model_store = String(".aesir/models")
    var seen_format = False
    var seen_context = False
    var seen_model_store = False
    var index = 1
    while index < len(args):
        var token = args[index]
        if token == "--format":
            if seen_format or index + 1 >= len(args):
                raise Error("inspect requires one value for --format")
            seen_format = True
            format = args[index + 1]
            if format != "text" and format != "json":
                raise Error("inspect --format must be text or json")
            index += 2
            continue
        if token == "--context":
            if seen_context or index + 1 >= len(args):
                raise Error("inspect requires one value for --context")
            seen_context = True
            context = _inspect_positive_int(args[index + 1])
            index += 2
            continue
        if token == "--model-store":
            if seen_model_store or index + 1 >= len(args):
                raise Error("inspect requires one value for --model-store")
            seen_model_store = True
            model_store = args[index + 1]
            index += 2
            continue
        if token.startswith("-"):
            raise Error("unknown inspect option: " + token)
        if model_path != "":
            raise Error("inspect accepts exactly one model reference")
        model_path = token
        index += 1
    if model_path == "":
        raise Error("Usage: aesir inspect <model> [--format text|json] [--context N] [--model-store path]")

    var resolved = resolve_model_reference(model_path, model_store)
    var model = PackedGGUF(resolved.path)
    var result = ModelArchitectureRegistry.inspect(model, context)
    if format == "json":
        print(model_inspection_json(result))
    else:
        print_model_inspection_text(result)
