# Source-bound recipe inspector; no production arithmetic executor.
from std.sys import argv
from smidr.semantic_plan import read_dense_semantic_plan
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: primitive_recipes <source.gguf> <query> <past> <context_capacity>")
    var plan = read_dense_semantic_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]))
    var lowered = lower_primitive_recipes(plan)
    var text = String("{\"schema_version\":1,\"scope\":\"mathematical_primitive_recipes\",\"executable_program\":false,\"device_execution_verified\":false,\"source_fingerprint_verified\":false,\"lowered_storage_recomputed\":false")
    text += ",\"unresolved_gates\":[\"finite_precision_reduction_and_overflow\",\"special_values_and_transcendental_approximations\",\"quantization_weight_and_activation_layout\",\"lowered_storage_and_device_placement\",\"CCW_encoding_upload_and_hardware_result\"]"
    text += ",\"recipes\":["
    for i in range(len(lowered.recipes)):
        if i != 0:
            text += ","
        var recipe = lowered.recipes[i].copy()
        text += "{\"source_operation\":" + String(recipe.source_operation) + ",\"source_input\":" + String(recipe.source_input) + ",\"source_output\":" + String(recipe.source_output)
        text += ",\"kind\":" + _quote(recipe.kind) + ",\"weight_name\":" + _quote(recipe.weight_name) + ",\"divisor\":" + String(recipe.divisor) + ",\"epsilon_bits\":" + String(recipe.epsilon_bits)
        text += ",\"runtime_preconditions\":["
        for j in range(len(recipe.runtime_preconditions)):
            if j != 0:
                text += ","
            text += _quote(recipe.runtime_preconditions[j])
        text += "]"
        if recipe.weight_name.byte_length() != 0:
            text += ",\"weight\":{\"file_offset\":" + String(recipe.weight.file_offset) + ",\"columns\":" + String(recipe.weight.columns) + ",\"rows\":" + String(recipe.weight.rows)
            text += ",\"source_kind\":" + String(recipe.weight.source_kind) + ",\"byte_count\":" + String(recipe.weight.byte_count) + "}"
        text += ",\"result\":" + String(recipe.result) + ",\"values\":["
        for j in range(len(recipe.values)):
            if j != 0:
                text += ","
            var value = recipe.values[j].copy()
            text += "{\"shape\":" + _integers(value.shape) + ",\"elements\":" + String(value.elements) + ",\"domain\":" + _quote(value.domain)
            text += ",\"producer\":" + String(value.producer) + ",\"last_use\":" + String(value.last_use) + "}"
        text += "],\"operations\":["
        for j in range(len(recipe.operations)):
            if j != 0:
                text += ","
            var operation = recipe.operations[j].copy()
            text += "{\"kind\":" + _quote(operation.kind) + ",\"inputs\":" + _integers(operation.inputs) + ",\"output\":" + String(operation.output) + "}"
        text += "]}"
    text += "],\"remaining_source_operations\":["
    for i in range(len(lowered.remaining_source_operations)):
        if i != 0:
            text += ","
        var index = lowered.remaining_source_operations[i]
        text += "{\"id\":" + String(index) + ",\"kind\":" + _quote(plan.operations[index].kind) + "}"
    print(text + "]}")
